//===- SFI.h ----------------------------------------------------*- C++ -*-===//
//
// Copyright (c) 2003-2019 University of Illinois at Urbana-Champaign.
// Copyright (c) 2014-2019 The University of Rochester. All rights reserved.
// This file was developed by the LLVM research group and is distributed under
// the University of Illinois Open Source License. See LICENSE.TXT for details.
//
//===----------------------------------------------------------------------===//
//
// Apply SVA's SFI transformation.
//
//===----------------------------------------------------------------------===//

#ifndef LLVM_TRANSFORMS_INSTRUMENTATION_SFI_H
#define LLVM_TRANSFORMS_INSTRUMENTATION_SFI_H

#include "llvm/IR/InstVisitor.h"
#include "llvm/IR/PassManager.h"

namespace llvm {
class DataLayout;

/// SVA's software fault isolation (SFI) pass.
///
/// Instruments loads and stores to ensure that they do not access ghost memory
/// or SVA's internal memory.
class SFI : public PassInfoMixin<SFI>, public InstVisitor<SFI> {
  #if 0
  /// Mask to determine if we use the original value or the masked value.
  static const uintptr_t checkMask = 0xffffff0000000000UL;
  #else
  /// Mask to determine if we use the original value or the masked value.
  static const constexpr uintptr_t CheckMask = 0x0000000000fffffdUL;
  #endif

  /// Mask to set proper lower-order bits.
  static const constexpr uintptr_t SetMask   = 0x0000020000000000UL;

public:
  /// Create a new SFI pass instance with parameters initialized from
  /// command-line options to LLVM.
  explicit SFI();

  /// Create a new SFI pass instance with the specified configuration.
  ///
  /// @param LoadChecks   Whether or not to perform checks on loads.
  /// @param UseMPX       Whether or not to implement checks with Intel MPX.
  explicit SFI(bool LoadChecks, bool UseMPX)
    : LoadChecks(LoadChecks), UseMPX(UseMPX) { }

  /// Run the SFI pass on the specified function.
  ///
  /// @param F  The function on which the SFI pass will be run.
  /// @return   The analyses which were not invalidated by this pass.
  PreservedAnalyses run(Function &F, FunctionAnalysisManager &AM);

  /// Add declarations for SVA utility functions.
  ///
  /// @param M  The module that this pass will run on.
  /// @return   True if we changed the module, otherwise false.
  bool doInitialization(Module &M);

  // ---------------------------------------------------------------------------
  //                            Visitor methods
  // ---------------------------------------------------------------------------

  /// Add SFI instrumentation to load instructions if load instrumentation is
  /// enabled.
  ///
  /// @param LI The load instruction to instrument.
  void visitLoadInst(LoadInst &LI);

  /// Add SFI instrumentation to store instructions.
  ///
  /// @param SI The store instruction to instrument.
  void visitStoreInst(StoreInst &SI);

  /// Add SFI instrumentation to atomic compare-and-swap instructions.
  ///
  /// @param AI The atomic compare-and-swap instruction to instrument.
  void visitAtomicCmpXchgInst(AtomicCmpXchgInst &I);

  /// Add SFI instrumentation to atomic read-modify-write instructions.
  ///
  /// @param AI The atomic read-modify-write instruction to instrument.
  void visitAtomicRMWInst(AtomicRMWInst &I);

  /// Add SFI instrumentation to a `memcpy` or `memmove` intrinsic.
  ///
  /// @param MCI  The `memcpy` or `memmove` intrinsic to instrument.
  void visitAnyMemTransferInst(AnyMemTransferInst &MTI);

  /// Add SFI instrumentation to a `memset` intrinsic.
  ///
  /// @param MCI  The `memset` intrinsic to instrument.
  void visitAnyMemSetInst(AnyMemSetInst &MTI);

private:
  /// Determine if a memory access of the specified type is safe (and therefore
  /// does not need a run-time check).
  ///
  /// @param Ptr      The pointer value that is being checked.
  /// @param MemType  The type of the memory access.
  /// @return         True if the memory access is safe, false if the memory
  ///                 access needs a run-time check.
  bool isTriviallySafe(const Value &Ptr, Type &Type, const DataLayout &DL);

  /// Add code to bit-mask the specified pointer and insert it before the
  /// specified instruction.
  ///
  /// @param Pointer      The pointer to perform bit-masking on.
  /// @param Instruction  The `Instruction` before which the bit-masking should be
  ///                     inserted.
  /// @return             The `Value` which results from bit-masking `Pointer`.
  Value &addBitMasking(Value &Pointer, Instruction &I);

  /// Add SFI instrumentation to a `memcpy`, `memmove`, or `memset` operation.
  ///
  /// @param Dst  The destination pointer.
  /// @param Src  The source pointer, or null if the intrinsic doesn't read
  ///             memory (e.g. memset).
  /// @param Len  The length of the operation.
  /// @param I    The `memcpy`, `memmove`, or `memset` instruction.
  void instrumentMemoryIntrinsic(Value &Dst, Value *Src, Value &Len, Instruction &I);

  /// Whether or not to do checks on load instructions.
  bool LoadChecks;

  /// Whether or not to implement checks with Intel MPX.
  bool UseMPX;
};

/// Create an instance of the SFI pass for the legacy pass maneger with
/// parameters initialized from the command-line options to LLVM.
///
/// @return A new instance of the SFI pass.
FunctionPass *createSFIPass();

/// Create an instance of the SFI pass for the legacy pass maneger with the
/// specified configuration.
///
/// @param LoadChecks   Whether or not to perform checks on loads.
/// @param UseMPX       Whether or not to implement checks with Intel MPX.
/// @return             A new instance of the SFI pass.
FunctionPass *createSFIPass(bool LoadChecks, bool UseMPX);

/// Initialize and register the SFI pass.
///
/// @param PR The `PassRegistry` with which to initialize this pass.
void initializeLegacySFIPass(PassRegistry &PR);
} // end namespace llvm

#endif // LLVM_TRANSFORMS_INSTRUMENTATION_SFI_H
