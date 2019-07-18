//===- CFI.cpp - Label-based Control Flow Integrity -----------------------===//
//
//                     The LLVM Compiler Infrastructure
//
// Copyright (c) 2003-2019 University of Illinois at Urbana-Champaign.
// Copyright (c) 2014-2019 The University of Rochester. All rights reserved.
// This file was developed by the LLVM research group and is distributed under
// the University of Illinois Open Source License. See LICENSE.TXT for details.
//
//===----------------------------------------------------------------------===//
//
// This pass instruments indirect calls to ensure that they can only go to a
// valid target.
//
//===----------------------------------------------------------------------===//

#define DEBUG_TYPE "sva-cfi"

#include <iterator>
#include <tuple>
#include <vector>

#include "llvm/ADT/Statistic.h"
#include "llvm/IR/BasicBlock.h"
#include "llvm/IR/CallSite.h"
#include "llvm/IR/Constant.h"
#include "llvm/IR/DataLayout.h"
#include "llvm/IR/InlineAsm.h"
#include "llvm/IR/IntrinsicInst.h"
#include "llvm/IR/Intrinsics.h"
#include "llvm/IR/IntrinsicsX86.h"
#include "llvm/IR/LegacyPassManager.h"
#include "llvm/Support/CommandLine.h"
#include "llvm/Support/Format.h"
#include "llvm/Transforms/Instrumentation/CFI.h"
#include "llvm/Transforms/Utils/BasicBlockUtils.h"

// Pass Statistics
namespace {
STATISTIC(CJChecks, "Call/Jump Instrumentation Added");
}

/// Command line option for enabling SVA Memory checks.
static llvm::cl::opt<bool>
DoSVAChecks("enable-cfi-svachecks",
            llvm::cl::desc("Add special CFI checks for SVA Memory"),
            llvm::cl::init(false));

/// Command line option for enabling use of MPX for CFI.
static llvm::cl::opt<bool>
OptUseMPX("enable-mpx-cfi",
            llvm::cl::desc("Use Intel MPX extensions for CFI"),
            llvm::cl::init(false));

namespace llvm {

CFI::CFI() : CFI(DoSVAChecks, OptUseMPX, false) { }

// FIXME:
//  Performing this check here really breaks the separation of concerns design
//  that we try to follow; this should really be implemented as a separate
//  optimization pass.  That said, it is quicker to implement it here.
//
bool CFI::isTriviallySafe(const CallBase &CI) const {
  // TODO
  return false;
}

bool CFI::isTriviallySafe(const IndirectBrInst &BI) const {
  // TODO
  return false;
}

Value *CFI::castAbortTo(Type *Ty) {
  return ConstantExpr::getBitCast(Abort, Ty);
}

IntegerType *CFI::getReturnAddrTy(LLVMContext &Ctx, const DataLayout &DL) {
  // TODO: Make this correct for all architectures
  return DL.getIntPtrType(Ctx);
}

Value *CFI::addBitMasking(Value &Callee, Instruction &I) {
  /// Object which provides size of data types on target machine.
  const DataLayout &DL = I.getModule()->getDataLayout();

  /// Integer type that is the size of a pointer on the target machine.
  Type *IntPtrTy = DL.getIntPtrType(I.getContext());

  if (UseMPX) {
    /// A reference to the context to the LLVM module which this code is
    /// transforming.
    LLVMContext &Ctx = I.getContext();

    Value *CastedCallee = new BitCastInst(&Callee,
                                          Type::getInt8PtrTy(Ctx),
                                          Callee.getName(),
                                          &I);
    Function *BoundsCheckLowerIntrin
      = Intrinsic::getDeclaration(I.getModule(), Intrinsic::x86_bndcl);
    Value *BoundsReg = ConstantInt::get(Type::getInt32Ty(Ctx), 1);
    CallInst::Create(BoundsCheckLowerIntrin,
                     {CastedCallee, BoundsReg},
                     "",
                     &I);
    return &Callee;
  } else {
    // Create the integer values used for bit-masking.
    Value *Mask = ConstantInt::get(IntPtrTy, KernelAddrSpaceMask);
    Value *svaLow = ConstantInt::get(IntPtrTy, SVALowAddr);
    Value *svaHigh = ConstantInt::get(IntPtrTy, SVAHighAddr);

    // Convert the pointer into an integer and then shift the higher order bits
    // into the lower-half of the integer.  Bit-masking operations can use
    // constant operands, reducing register pressure, if the operands are 32-bits
    // or smaller.
    Value *CastedPointer = new PtrToIntInst(&Callee, IntPtrTy, "ptr", &I);

    // Create instructions that create a version of the pointer with the proper
    // bit set.
    Value *MaskedPointer = BinaryOperator::Create(Instruction::Or,
                                                  CastedPointer,
                                                  Mask,
                                                  "setMask",
                                                  &I);

    Value *Final = new IntToPtrInst(MaskedPointer,
                                    Callee.getType(),
                                    "masked",
                                    &I);

    // Insert a special check to protect SVA memory.  Note that this is a hack
    // that is used because the SVA memory isn't positioned after Ghost Memory
    // like it should be as described in the Virtual Ghost and KCoFI papers.
    if (SVAMemChecks) {
      // Compare against the first and last SVA addresses.
      Value *svaLCmp = new ICmpInst(&I,
                                    CmpInst::ICMP_ULE,
                                    svaLow,
                                    MaskedPointer,
                                    "svacmp");
      Value *svaHCmp = new ICmpInst(&I,
                                    CmpInst::ICMP_ULE,
                                    MaskedPointer,
                                    svaHigh,
                                    "svacmp");
      Value *InSVA = BinaryOperator::Create(Instruction::And,
                                            svaLCmp,
                                            svaHCmp,
                                            "inSVA",
                                            &I);

      // Call `abort` instead if the target is in SVA memory.
      Value *CastedAbort = castAbortTo(Callee.getType());
      Final = SelectInst::Create(InSVA, CastedAbort, Final, "fptr", &I);
    }

    return Final;
  }
}

std::pair<BasicBlock*, BasicBlock::iterator>
CFI::addLabelCheck(Value &Callee, Instruction &I) {
  if (UseCET) {
    report_fatal_error("Using CET for CFI is not currently implemented");
  } else {
    const Module &M = *I.getModule();
    const DataLayout &DL = M.getDataLayout();
    LLVMContext &Ctx = M.getContext();

    Type *LabelTy = DL.getSmallestLegalIntType(Ctx, CFILabelSize * 8);
    if (!LabelTy) {
      report_fatal_error("Colud not get type for CFI label");
    }
    Type *LabelPtrTy
      = LabelTy->getPointerTo(Callee.getType()->getPointerAddressSpace());

    Value *Label = ConstantInt::get(LabelTy, CFILabel);
    Value *Casted = new BitCastInst(&Callee,
                                    LabelPtrTy,
                                    "callee_data_ptr",
                                    &I);
    // This load will be instrumented by the SFI pass.
    Value *TargetLabel = new LoadInst(LabelTy, Casted, "target_label", &I);
    Value *IsValid = new ICmpInst(&I,
                                  CmpInst::ICMP_EQ,
                                  Label,
                                  TargetLabel,
                                  "label_cmp");

    BasicBlock *CurrentBB = I.getParent();
    BasicBlock *NewBB
      = CurrentBB->splitBasicBlock(&I, CurrentBB->getName() + ".cfi_ok");
    BasicBlock::iterator NextInst = std::next(I.getIterator());

    BasicBlock *ErrorBB = getOrCreateErrorBasicBlock(*I.getFunction());
    BranchInst *Branch = BranchInst::Create(NewBB, ErrorBB, IsValid);
    ReplaceInstWithInst(CurrentBB->getTerminator(), Branch);

    ++CJChecks;

    return std::make_pair(NewBB, NextInst);
  }
}

llvm::Optional<std::pair<BasicBlock*, BasicBlock::iterator>>
CFI::visitIndirectBrInst(IndirectBrInst &BI) {
  if (!isTriviallySafe(BI)) {
    Value *Target = BI.getAddress();
    assert(Target && "Indirect branch has no target");
    Value *MaskedTarget = addBitMasking(*Target, BI);
    auto Next = addLabelCheck(*MaskedTarget, BI);
    BI.setAddress(MaskedTarget);
    return Next;
  } else {
    return None;
  }
}

llvm::Optional<std::pair<BasicBlock*, BasicBlock::iterator>>
CFI::visitCallBase(CallBase &CI) {
  if (CI.isIndirectCall() && !isTriviallySafe(CI)) {
    Value *Callee = CI.getCalledOperand();
    assert(Callee && "Call instruction has no callee");
    Value *MaskedCallee = addBitMasking(*Callee, CI);
    auto Next = addLabelCheck(*MaskedCallee, CI);
    CI.setCalledOperand(MaskedCallee);
    return Next;
  } else {
    return None;
  }
}

llvm::Optional<std::pair<BasicBlock*, BasicBlock::iterator>>
CFI::visitReturnInst(ReturnInst &RI) {
  LLVMContext& Ctx = RI.getContext();
  const DataLayout& DL = RI.getModule()->getDataLayout();

  Type *RetAddrTy = getReturnAddrTy(Ctx, DL);
  Function *AddrOfRetAddrIntrin
    = Intrinsic::getDeclaration(RI.getModule(),
                                Intrinsic::addressofreturnaddress,
                                {RetAddrTy->getPointerTo()});
  Value *AddrOfRetAddr = CallInst::Create(AddrOfRetAddrIntrin,
                                          "retaddraddr",
                                          &RI);
  Value *RetAddr = new LoadInst(AddrOfRetAddr, "retaddr", &RI);
  // FIXME: addBitMasking and addLabelCheck expect a pointer, so we cast the
  // return address to a pointer. They should be changet to take integers.
  Value *RetAddrAsPtr = new IntToPtrInst(RetAddr,
                                         Type::getInt8PtrTy(Ctx),
                                         "retaddrasptr",
                                         &RI);
  Value *MaskedReturn = addBitMasking(*RetAddrAsPtr, RI);
  auto Next = addLabelCheck(*MaskedReturn, RI);

  // See FIXME above
  Value *CastedMaskedReturn = new PtrToIntInst(MaskedReturn,
                                               RetAddrTy,
                                               "checkedretaddr",
                                               &RI);

  new StoreInst(CastedMaskedReturn, AddrOfRetAddr, &RI);

  return Next;
}

llvm::Optional<std::pair<BasicBlock*, BasicBlock::iterator>>
CFI::visit(Instruction &I) {
  if (CallBase* CI = dyn_cast<CallBase>(&I)) {
    return visitCallBase(*CI);
  } else if (IndirectBrInst* BI = dyn_cast<IndirectBrInst>(&I)) {
    return visitIndirectBrInst(*BI);
  } else if (ReturnInst* RI = dyn_cast<ReturnInst>(&I)) {
    return visitReturnInst(*RI);
  } else {
    return None;
  }
}

BasicBlock *CFI::getOrCreateErrorBasicBlock(Function& F) {
  if (ErrorBB == nullptr) {
    ErrorBB = BasicBlock::Create(F.getContext(), "cfi_check_fail", &F);
    CallInst::Create(Abort, "", ErrorBB);
    new UnreachableInst(F.getContext(), ErrorBB);
  } else {
    assert(ErrorBB->getParent() == &F && "Error basic block is stale");
  }

  return ErrorBB;
}

void CFI::runOnFunction(Function &F) {
  ErrorBB = nullptr;

  // Because we may be inserting basic blocks, we cannot simply iterate over
  // each basic block in the function. Instead, we create a work list with all
  // of the function's basic blocks. Each time we create a basic block, we add
  // it to the work list. To further complicate things, when we split a block,
  // the first instruction in the new block is one we already visited.
  // Therefore, the work list also contains an iterator into the basic block to
  // indicate where in that block we should begin visiting.
  std::vector<std::pair<BasicBlock*, BasicBlock::iterator>> Worklist;

  for (BasicBlock &BB : F) {
    Worklist.push_back(std::make_pair(&BB, BB.begin()));
  }

  while (!Worklist.empty()) {
    BasicBlock *BB;
    BasicBlock::iterator Start;
    std::tie(BB, Start) = Worklist.back();
    Worklist.pop_back();
    for (Instruction &I : make_range(Start, BB->end())) {
      if (auto NewBlock = visit(I)) {
        Worklist.push_back(*NewBlock);
        break; // We invalidated the iterator, so we have to exit the loop here.
      }
    }
  }
}

bool CFI::doInitialization(Module &M) {
  // Make sure we can call `abort`.
  auto F = M.getOrInsertFunction("abort", Type::getVoidTy(M.getContext()));
  Abort = cast<Function>(F.getCallee());

  // FIXME: We always return true here, but should be returning whether or not
  // the module actually changed.
  return true;
}

PreservedAnalyses CFI::run(Function &F, FunctionAnalysisManager &AM) {
  // This should only be done once per module, but it's idempotent and the new
  // pass manager doesn't have a convienient way to run things once per module.
  doInitialization(*F.getParent());

  // Visit all of the instructions in the function.
  runOnFunction(F);

  return PreservedAnalyses::none();
}
}

namespace llvm {
/// Legacy CFI pass wrapper
class LegacyCFI : public FunctionPass {
public:
  static char ID;

  LegacyCFI() : FunctionPass(ID), CFIPass() { }

  LegacyCFI(bool SVAMemChecks, bool UseMPX, bool UseCET)
    : FunctionPass(ID), CFIPass(SVAMemChecks, UseMPX, UseCET) { }

  virtual bool runOnFunction(Function &F) override {
    // `abort` seems to get deleted from the module if we add it any earlier.
    CFIPass.doInitialization(*F.getParent());

    CFIPass.runOnFunction(F);
    return true;
  }

  virtual StringRef getPassName() const override {
    return "SVA CFI Instrumentation";
  }

  virtual void getAnalysisUsage(AnalysisUsage &AU) const override {
    // NOOP: No preserved analyses, no required analyses
  }

private:
  CFI CFIPass;
};

char LegacyCFI::ID = 0;
}

using namespace llvm;

FunctionPass *llvm::createCFIPass() {
  return new LegacyCFI();
}

FunctionPass *llvm::createCFIPass(bool SVAMemChecks, bool UseMPX, bool UseCET) {
  return new LegacyCFI(SVAMemChecks, UseMPX, UseCET);
}

INITIALIZE_PASS_BEGIN(LegacyCFI, DEBUG_TYPE, "SVA CFI instrumentation", false, false)
INITIALIZE_PASS_END(LegacyCFI, DEBUG_TYPE, "SVA CFI instrumentation", false, false)
