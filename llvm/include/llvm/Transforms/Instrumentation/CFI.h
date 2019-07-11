//===- CFI.cpp - Label-based Control Flow Integrity -------------*- C++ -*-===//
//
// Copyright (c) 2003-2019 University of Illinois at Urbana-Champaign.
// Copyright (c) 2014-2019 The University of Rochester. All rights reserved.
// This file was developed by the LLVM research group and is distributed under
// the University of Illinois Open Source License. See LICENSE.TXT for details.
//
//===----------------------------------------------------------------------===//
//
// Apply SVA's CFI transformation.
//
//===----------------------------------------------------------------------===//

#ifndef LLVM_TRANSFORMS_INSTRUMENTATION_CFI_H
#define LLVM_TRANSFORMS_INSTRUMENTATION_CFI_H

#include <utility>

#include "llvm/ADT/Optional.h"
#include "llvm/IR/DataLayout.h"
#include "llvm/IR/Function.h"
#include "llvm/IR/InstrTypes.h"
#include "llvm/IR/Instruction.h"
#include "llvm/IR/Instructions.h"
#include "llvm/IR/InstVisitor.h"
#include "llvm/IR/LLVMContext.h"
#include "llvm/IR/Module.h"
#include "llvm/IR/PassManager.h"
#include "llvm/IR/Value.h"
#include "llvm/Pass.h"
#include "llvm/PassRegistry.h"

namespace llvm {
class DataLayout;

/// SVA's Control Flow Integrity (CFI) pass.
///
/// Instruments indirect jumps and calls to ensure that they only go to valid
/// targets.
class CFI : public PassInfoMixin<CFI> {
public:
  // FIXME: These are target-specific and should be queried from the target.

  /// Location of secure memory.
  static const constexpr uintptr_t StartGhostMemory = 0xfffffd0000000000UL;

  /// Mask for the kernel address space.
  static const constexpr uintptr_t KernelAddrSpaceMask = 0xffffffff80000000UL;

  /// Beginnig of SVA memory.
  static const constexpr uintptr_t SVALowAddr = 0xffffffff819ef000UL;

  /// End of SVA memory.
  static const constexpr uintptr_t SVAHighAddr = 0xffffffff89b96060UL;

  /// CFI label value.
  ///
  /// Encoding of `mov %ecx, %ecx; mov %edx, %edx`.
  static const constexpr uint32_t CFILabel = 0xd289c989U;

  /// CFI label size.
  static const constexpr size_t CFILabelSize = 4;

  /// Create a new CFI pass instance with parameters initialized from
  /// command-line options to LLVM.
  explicit CFI();

  /// Create a new CFI pass instance with the specified configuration.
  ///
  /// @param SVAMemChecks Whether or not to do extra checks to protect SVA's
  ///                     private memory.
  /// @param UseMPX       Whether or not to implement checks with Intel MPX.
  /// @param UseCET       Whether or not to implement checks with Intel CET.
  explicit CFI(bool SVAMemChecks, bool UseMPX, bool UseCET)
    : SVAMemChecks(SVAMemChecks), UseMPX(UseMPX), UseCET(UseCET) { }

  /// Run the CFI pass on the specified `Function`.
  ///
  /// @param F  The `Function` on which the CFI pass will be run.
  /// @return   The analyses which were not invalidated by this pass.
  PreservedAnalyses run(Function &F, FunctionAnalysisManager &AM);

  /// Run the CFI pass on the specified `Function`.
  ///
  /// @param F  The `Function` on which the CFI pass will be run.
  void runOnFunction(Function &F);

  /// Add declarations for SVA utility functions.
  ///
  /// @param M  The module that this pass will run on.
  /// @return   True if we changed the module, otherwise false.
  bool doInitialization(Module &M);

  // ---------------------------------------------------------------------------
  //                            Visitor methods
  // ---------------------------------------------------------------------------

  /// Add CFI instrumentation to certain `Instruction`s.
  ///
  /// @param CI The `Instruction` to instrument.
  /// @return   The next `BasicBlock` and `Instruction` that should be visited,
  ///           or `None` to continue from the current `Instruction`.
  llvm::Optional<std::pair<BasicBlock*, BasicBlock::iterator>>
  visit(Instruction &I);

  /// Add CFI instrumentation to certain function calls.
  ///
  /// @param CI The call to instrument.
  /// @return   The next `BasicBlock` and `Instruction` that should be visited,
  ///           or `None` to continue from the current `Instruction`.
  llvm::Optional<std::pair<BasicBlock*, BasicBlock::iterator>>
  visitCallBase(CallBase &CI);

  /// Add CFI instrumentation to an indirect branch.
  ///
  /// @param BI The branch to instrument.
  /// @return   The next `BasicBlock` and `Instruction` that should be visited,
  ///           or `None` to continue from the current `Instruction`.
  llvm::Optional<std::pair<BasicBlock*, BasicBlock::iterator>>
  visitIndirectBrInst(IndirectBrInst &BI);

  /// Add CFI instrumentation to a return.
  ///
  /// @param RI The return to instrument.
  /// @return   The next `BasicBlock` and `Instruction` that should be visited,
  ///           or `None` to continue from the current `Instruction`.
  llvm::Optional<std::pair<BasicBlock*, BasicBlock::iterator>>
  visitReturnInst(ReturnInst &RI);

private:
  /// Determine if an indirect call is safe (and therefore does not need a
  /// run-time check).
  ///
  /// @param CI       The call instruction that is being checked.
  /// @return         True if the indirect call is safe, false if it needs a
  ///                 run-time check.
  bool isTriviallySafe(const CallBase &CI) const;

  /// Determine if an indirect branch is safe (and therefore does not need a
  /// run-time check).
  ///
  /// @param BI       The call instruction that is being checked.
  /// @return         True if the indirect branch is safe, false if it needs a
  ///                 run-time check.
  bool isTriviallySafe(const IndirectBrInst &CI) const;

  /// Get the platform-specific type as which it is suitable to load and store
  /// the return address.
  ///
  /// Note that this always returns an integer type: the return address is
  /// treated as an integer (as it may not be a valid pointer).
  ///
  /// @param Ctx  The `LLVMContext` used to get the type.
  /// @param DL   The `DataLayout` for the current module.
  /// @return     An integer type as which the return address can be loaded and
  ///             stored.
  IntegerType *getReturnAddrTy(LLVMContext &Ctx, const DataLayout& DL);

  /// Bitcast the `abort` function to the given type.
  ///
  /// @param Ty The pointer type to which to cast `abort`.
  /// @return   A pointer to `abort`, casted to `Ty`.
  Value *castAbortTo(Type *Ty);

  /// Returns the error basic block for this `Function`, creating it if it
  /// doesn't exist.
  ///
  /// The error basic block is the basic block to which control should be
  /// transfered in the event of a CFI check failure.
  ///
  /// @param F  The `Function` whose error basic block needs to be retrieved.
  /// @return   An error basic block in `F`.
  BasicBlock *getOrCreateErrorBasicBlock(Function& F);

  /// Add code to bit-mask the specified pointer and insert it before the
  /// specified instruction.
  ///
  /// @param Callee The pointer to perform bit-masking on.
  /// @param I      The `Instruction` before which the bit-masking should be
  ///               inserted. Generally, this should be the indirect branch,
  ///               but is not required to be.
  /// @return       The `Value` which results from bit-masking `Callee`.
  Value *addBitMasking(Value &Callee, Instruction &I);

  /// Add code to check for the presence of a CFI label in an indirect
  /// jump/call target.
  ///
  /// @param Callee The indirect jump/call target to check.
  /// @param I      The `Instruction` before which the check should be inserted.
  ///               Generally, this should be the indirect jump/call, but is not
  ///               required to be.
  /// @return       A value which should become the new target of the indirect
  ///               jump/call.
  std::pair<BasicBlock*, BasicBlock::iterator>
  addLabelCheck(Value &Callee, Instruction &I);

  /// The `abort` function.
  Function *Abort = nullptr;

  /// The basic block that we jump to on a CFI check failure.
  BasicBlock *ErrorBB = nullptr;

  /// Whether or not to perform checks to protect SVA's private memory.
  bool SVAMemChecks;

  /// Whether or not to implement checks with Intel MPX.
  bool UseMPX;

  /// Whether or not to implement checks with Intel CET.
  bool UseCET;
};


/// Create an instance of the CFI pass for the legacy pass maneger with
/// parameters initialized from the command-line options to LLVM.
///
/// @return A new instance of the CFI pass.
FunctionPass *createCFIPass();

/// Create an instance of the CFI pass for the legacy pass maneger with the
/// specified configuration.
///
/// @param SVAMemChecks Whether or not to do extra checks to protect SVA's
///                     private memory.
/// @param UseMPX       Whether or not to implement checks with Intel MPX.
/// @param UseCET       Whether or not to implement checks with Intel CET.
/// @return             A new instance of the CFI pass.
FunctionPass *createCFIPass(bool SVAMemChecks, bool UseMPX, bool UseCET);

/// Initialize and register the CFI pass.
///
/// @param PR The `PassRegistry` with which to initialize this pass.
void initializeLegacyCFIPass(PassRegistry &PR);
} // end namespace llvm

#endif // LLVM_TRANSFORMS_INSTRUMENTATION_CFI_H
