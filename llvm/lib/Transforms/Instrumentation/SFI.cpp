//===- SFI.cpp - Instrument loads/stores for Software Fault Isolation -----===//
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
// This pass instruments loads and stores to prevent them from accessing
// protected regions of the virtual address space.
//
//===----------------------------------------------------------------------===//

#define DEBUG_TYPE "sva-sfi"

#include "llvm/ADT/Statistic.h"
#include "llvm/IR/BasicBlock.h"
#include "llvm/IR/CallSite.h"
#include "llvm/IR/Constant.h"
#include "llvm/IR/DataLayout.h"
#include "llvm/IR/Function.h"
#include "llvm/IR/InlineAsm.h"
#include "llvm/IR/Instruction.h"
#include "llvm/IR/Instructions.h"
#include "llvm/IR/IntrinsicInst.h"
#include "llvm/IR/LegacyPassManager.h"
#include "llvm/IR/Module.h"
#include "llvm/IR/Value.h"
#include "llvm/Pass.h"
#include "llvm/Support/CommandLine.h"
#include "llvm/Transforms/Instrumentation/SFI.h"

// Pass Statistics
namespace {
STATISTIC(LSChecks, "Load/Store Instrumentation Added");
}

/// Command line option for enabling checks on loads.
static llvm::cl::opt<bool>
DoLoadChecks("enable-sfi-loadchecks",
             llvm::cl::desc("Add SFI checks to loads"),
             llvm::cl::init(false));

/// Command line option for enabling SVA Memory checks.
static llvm::cl::opt<bool>
DoSVAChecks("enable-sfi-svachecks",
            llvm::cl::desc("Add special SFI checks for SVA Memory"),
            llvm::cl::init(false));

/// Command line option for enabling use of MPX for SFI.
static llvm::cl::opt<bool>
OptUseMPX("enable-mpx-sfi",
            llvm::cl::desc("Use Intel MPX extensions for SFI"),
            llvm::cl::init(false));

namespace llvm {

SFI::SFI(): SFI(DoLoadChecks, DoSVAChecks, OptUseMPX) { }

// FIXME:
//  Performing this check here really breaks the separation of concerns design
//  that we try to follow; this should really be implemented as a separate
//  optimization pass.  That said, it is quicker to implement it here.
//
bool SFI::isTriviallySafe(const Value &Ptr, Type &MemType, const DataLayout &DL) {
  // Attempt to see if this is a stack or global allocation.  If so, get the
  // allocated type.
  Type *AllocatedType = nullptr;

#if 0
  if (AllocaInst *AI = dyn_cast<AllocaInst>(Ptr->stripPointerCasts())) {
    if (!(AI->isArrayAllocation())) {
      AllocatedType = AI->getAllocatedType();
    }
  }
#endif

  if (const GlobalVariable *GV = dyn_cast<GlobalVariable>(Ptr.stripPointerCasts())) {
    AllocatedType = GV->getType()->getElementType();
  }

  // If this is not a stack or global object, it is unsafe (it might be
  // deallocated, for example).
  if (!AllocatedType)
    return false;

  // If the types are the same, then the access is safe.
  if (AllocatedType == &MemType)
    return true;

  // Otherwise, see if the allocated type is larger than the accessed type.
  uint64_t AllocTypeSize = DL.getTypeAllocSize(AllocatedType);
  uint64_t MemTypeSize   = DL.getTypeStoreSize(&MemType);
  return (AllocTypeSize >= MemTypeSize);
}

bool SFI::doInitialization(Module &M) {
#if 0
  M.getOrInsertFunction("sva_checkptr",
                        Type::getVoidTy(M.getContext()),
                        Type::getInt64Ty(M.getContext()),
                        0);
#endif

  // Add a function for checking memcpy().
  M.getOrInsertFunction("sva_check_buffer",
                        Type::getVoidTy(M.getContext()),
                        Type::getInt64Ty(M.getContext()),
                        Type::getInt64Ty(M.getContext()));

  // FIXME: We always return true here, but should be returning whether or not
  // the module actually changed.
  return true;
}

Value &SFI::addBitMasking(Value &Pointer, Instruction &I) {
  /// Object which provides size of data types on target machine.
  const DataLayout &DL = I.getModule()->getDataLayout();

  /// Integer type that is the size of a pointer on the target machine.
  Type *IntPtrTy = DL.getIntPtrType(I.getContext());

  if (UseMPX) {
    /// A reference to the context to the LLVM module which this code is
    /// transforming.
    LLVMContext &Context = I.getContext();

    // Create a pointer value that is the pointer minus the start of the
    // secure memory.
    Constant *adjSize = ConstantInt::get(IntPtrTy,
                                         StartGhostMemory,
                                         false);
    Value *IntPtr = new PtrToIntInst(&Pointer,
                                     IntPtrTy,
                                     Pointer.getName(),
                                     &I);
    Value *AdjustPtr = BinaryOperator::Create(Instruction::Sub,
                                              IntPtr,
                                              adjSize,
                                              "adjSize",
                                              &I);
    AdjustPtr = new IntToPtrInst(AdjustPtr,
                                 Pointer.getType(),
                                 Pointer.getName(),
                                 &I);

    // Create a function type for the inline assembly instruction.
    FunctionType *CheckType;
    CheckType = FunctionType::get(Type::getVoidTy(Context),
                                  Pointer.getType(),
                                  false);

    // Create an inline assembly "value" that will perform the bounds check.
    Value *LowerBoundsCheck = InlineAsm::get(CheckType,
                                             "bndcl $0, %bnd0\n",
                                             "r,~{dirflag},~{fpsr},~{flags}",
                                             true);

    // Create the lower bounds check.  Do this before calculating the address
    // for the upper bounds check; this might reduce register pressure.
    CallInst::Create(LowerBoundsCheck, AdjustPtr, "", &I);
    return Pointer;
  } else {
    // Create the integer values used for bit-masking.
    Value *CheckMask = ConstantInt::get(IntPtrTy, SFI::CheckMask);
    Value *SetMask   = ConstantInt::get(IntPtrTy, SFI::SetMask);
    Value *Zero      = ConstantInt::get(IntPtrTy, 0u);
    Value *ShiftBits = ConstantInt::get(IntPtrTy, 40u);
    Value *svaLow    = ConstantInt::get(IntPtrTy, StartSVAMemory);
    Value *svaHigh   = ConstantInt::get(IntPtrTy, EndSVAMemory);

    // Convert the pointer into an integer and then shift the higher order bits
    // into the lower-half of the integer.  Bit-masking operations can use
    // constant operands, reducing register pressure, if the operands are 32-bits
    // or smaller.
    Value *CastedPointer = new PtrToIntInst(&Pointer, IntPtrTy, "ptr", &I);
    Value *PtrHighBits = BinaryOperator::Create(Instruction::LShr,
                                                CastedPointer,
                                                ShiftBits,
                                                "highbits",
                                                &I);

    // Compare the masked pointer to the mask.  If they're the same, we need to
    // set that bit.
    Value *Cmp = new ICmpInst(&I,
                              CmpInst::ICMP_EQ,
                              PtrHighBits,
                              CheckMask,
                              "cmp");

    // Create the select instruction that, at run-time, will determine if we use
    // the bit-masked pointer or the original pointer value.
    Value *MaskValue = SelectInst::Create(Cmp, SetMask, Zero, "ptr", &I);

    // Create instructions that create a version of the pointer with the proper
    // bit set.
    Value *Masked = BinaryOperator::Create(Instruction::Or,
                                           CastedPointer,
                                           MaskValue,
                                           "setMask",
                                           &I);

    // Insert a special check to protect SVA memory.  Note that this is a hack
    // that is used because the SVA memory isn't positioned after Ghost Memory
    // like it should be as described in the Virtual Ghost and KCoFI papers.
    Value *Final = Masked;
    if (SVAMemChecks) {
      // Compare against the first and last SVA addresses.
      Value *svaLCmp = new ICmpInst(&I,
                                    CmpInst::ICMP_ULE,
                                    svaLow,
                                    Masked,
                                    "svacmp");
      Value *svaHCmp = new ICmpInst(&I,
                                    CmpInst::ICMP_ULE,
                                    Masked,
                                    svaHigh,
                                    "svacmp");
      Value *InSVA = BinaryOperator::Create(Instruction::And,
                                            svaLCmp,
                                            svaHCmp,
                                            "inSVA",
                                            &I);

      // Select the correct value based on whether the pointer is in SVA memory.
      Final = SelectInst::Create(InSVA, Zero, Masked, "fptr", &I);
    }

    return *(new IntToPtrInst(Final, Pointer.getType(), "masked", &I));
  }
}

void SFI::instrumentMemcpy(Value &Dst, Value &Src, Value &Len, Instruction &I) {
  return;
  // Cast the pointers to integers.  Only cast the source pointer if we're
  // adding SFI checks to loads.
  const DataLayout &DL = I.getModule()->getDataLayout();
  Type *IntPtrTy = DL.getIntPtrType(I.getContext());
  Value *DstInt = new PtrToIntInst(&Dst, IntPtrTy, "dst", &I);
  Value *SrcInt = nullptr;
  if (LoadChecks) {
    SrcInt = new PtrToIntInst(&Src, IntPtrTy, "src", &I);
  }

  // Setup the function arguments.
  Value *Args[2];
  Args[0] = DstInt;
  Args[1] = &Len;

  // Get the function.
  Module *M = I.getModule();
  Function *CheckF = M->getFunction("sva_check_buffer");
  assert(CheckF && "sva_check_buffer not found!\n");

  // Create a call to the checking function.
  CallInst::Create(CheckF, Args, "", &I);

  // Create another call to check the source if SFI checks on loads have been
  // enabled.
  if (LoadChecks) {
    Value *SrcArgs[2];
    SrcArgs[0] = SrcInt;
    SrcArgs[1] = &Len;
    CallInst::Create(CheckF, SrcArgs, "", &I);
  }
}

void SFI::visitMemCpyInst(MemCpyInst &MCI) {
  // Get the arguments to the `memcpy`.
  Value &Dst = *MCI.getDest();
  Value &Src = *MCI.getSource();
  Value &Len = *MCI.getLength();

  instrumentMemcpy(Dst, Src, Len, MCI);
}

void SFI::visitCallBase(CallBase &CI) {
  assert(!isa<MemCpyInst>(&CI) &&
    "MemCpyInst should have been dispatched to its own visitor");

  // Check if this function call is a non-intrinsic call to `memcpy`. This may
  // occur, for example, due to `-fno-builtin`.
  if (Function *F = CI.getCalledFunction()) {
    if (F->hasName() && F->getName().equals("memcpy")) {
      CallSite CS(&CI);
      instrumentMemcpy(*CS.getArgument(0),
                       *CS.getArgument(1),
                       *CS.getArgument(2),
                       CI);
    }
  }
}

void SFI::visitLoadInst(LoadInst &LI) {
  // Add a check to the load if the option for instrumenting loads is enabled.
  if (LoadChecks) {
    Value &Pointer = *LI.getPointerOperand();

    // Don't instrument trivially safe memory accesses.
    if (!isTriviallySafe(Pointer, *LI.getType(), LI.getModule()->getDataLayout())) {
      // Add the bit masking for the pointer.
      Value &newPtr = addBitMasking(Pointer, LI);

      // Update the operand of the store so that it uses the bit-masked pointer.
      LI.setOperand(0, &newPtr);

      // Update the statistics.
      ++LSChecks;
    }
  }
}

void SFI::visitStoreInst(StoreInst &SI) {
  Value &Pointer = *SI.getPointerOperand();

  // Don't instrument trivially safe memory accesses.
  if (!isTriviallySafe(Pointer, *SI.getValueOperand()->getType(), SI.getModule()->getDataLayout())) {
    // Add the bit masking for the pointer.
    Value &newPtr = addBitMasking(Pointer, SI);

    // Update the operand of the store so that it uses the bit-masked pointer.
    SI.setOperand(1, &newPtr);

    // Update the statistics.
    ++LSChecks;
  }
}

void SFI::visitAtomicCmpXchgInst(AtomicCmpXchgInst &AI) {
  Value &Pointer = *AI.getPointerOperand();

  // Don't instrument trivially safe memory accesses.
  if (!isTriviallySafe(Pointer, *AI.getNewValOperand()->getType(), AI.getModule()->getDataLayout())) {
    // Add the bit masking for the pointer.
    Value &newPtr = addBitMasking(Pointer, AI);

    // Update the operand of the store so that it uses the bit-masked pointer.
    AI.setOperand(0, &newPtr);

    // Update the statistics.
    ++LSChecks;
  }
}

void SFI::visitAtomicRMWInst(AtomicRMWInst &AI) {
  Value &Pointer = *AI.getPointerOperand();

  // Don't instrument trivially safe memory accesses.
  if (!isTriviallySafe(Pointer, *AI.getValOperand()->getType(), AI.getModule()->getDataLayout())) {
    // Add the bit masking for the pointer.
    Value &newPtr = addBitMasking(Pointer, AI);

    // Update the operand of the store so that it uses the bit-masked pointer.
    AI.setOperand(0, &newPtr);

    // Update the statistics.
    ++LSChecks;
  }
}

PreservedAnalyses SFI::run(Function &F, FunctionAnalysisManager &AM) {
  //
  // Skip pmap_bootstrap() in sys/amd64/amd64/pmap.c.
  //
  // pmap_bootstrap() is called when paging is not enabled, and it will
  // set up the initial page table and enable paging. We don't want to
  // do SFI checks on physical addresses.
  //
  if (F.getName().equals("pmap_bootstrap")) {
    const std::string & moduleId = F.getParent()->getModuleIdentifier();
    if (moduleId.rfind("sys/amd64/amd64/pmap.c") != std::string::npos) {
      return PreservedAnalyses::all();
    }
  }

  // This should only be done once per module, but it's idempotent and the new
  // pass manager doesn't have a convienient way to run things once per module.
  doInitialization(*F.getParent());

  // Visit all of the instructions in the function.
  visit(F);

  return PreservedAnalyses::allInSet<CFGAnalyses>();
}
}

namespace llvm {
/// Legacy SFI pass wrapper
class LegacySFI : public FunctionPass {
public:
  static char ID;

  LegacySFI() : FunctionPass(ID), SFIPass() { }

  LegacySFI(bool LoadChecks, bool SVAMemChecks, bool UseMPX)
    : FunctionPass(ID), SFIPass(LoadChecks, SVAMemChecks, UseMPX) { }

  virtual bool doInitialization(Module &M) override {
    return SFIPass.doInitialization(M);
  }

  virtual bool runOnFunction(Function &F) override {
    //
    // Skip pmap_bootstrap() in sys/amd64/amd64/pmap.c.
    //
    // pmap_bootstrap() is called when paging is not enabled, and it will
    // set up the initial page table and enable paging. We don't want to
    // do SFI checks on physical addresses.
    //
    if (F.getName().equals("pmap_bootstrap")) {
      const std::string & moduleId = F.getParent()->getModuleIdentifier();
      if (moduleId.rfind("sys/amd64/amd64/pmap.c") != std::string::npos) {
        return false;
      }
    }

    SFIPass.visit(F);
    return true;
  }

  virtual StringRef getPassName() const override {
    return "SVA SFI Instrumentation";
  }

  virtual void getAnalysisUsage(AnalysisUsage &AU) const override {
    // Preserve the CFG
    AU.setPreservesCFG();
  }

private:
  SFI SFIPass;
};

char LegacySFI::ID = 0;
}

using namespace llvm;

static RegisterPass<LegacySFI>
  X("sva-sfi", "Insert SFI load/store instrumentation");

FunctionPass *llvm::createSFIPass() {
  return new LegacySFI();
}

FunctionPass *llvm::createSFIPass(bool LoadChecks,
                                  bool SVAMemChecks,
                                  bool UseMPX) {
  return new LegacySFI(LoadChecks, SVAMemChecks, UseMPX);
}

INITIALIZE_PASS_BEGIN(LegacySFI, DEBUG_TYPE, "SVA SFI instrumentation", false, false)
INITIALIZE_PASS_END(LegacySFI, DEBUG_TYPE, "SVA SFI instrumentation", false, false)
