//===-- CFILabelInserter.h - Late-stage CFI Label Insertion -----*- C++ -*-===//
//
// Copyright 2019 The University of Rochester. All Rights Reserved.
// This file is distributed under the Apache License v2.0 with LLVM Exceptions.
// See LICENSE.TXT for details.
//
//===----------------------------------------------------------------------===//
//
// Machine function pass to insert CFI labels on indirect jump/call targets.
//
//===----------------------------------------------------------------------===//

#ifndef LLVM_CODEGEN_CFILABELINSERTER_H
#define LLVM_CODEGEN_CFILABELINSERTER_H

#include "llvm/CodeGen/MachineBasicBlock.h"
#include "llvm/CodeGen/MachineFunction.h"
#include "llvm/CodeGen/MachineFunctionPass.h"
#include "llvm/CodeGen/TargetInstrInfo.h"
#include "llvm/Pass.h"
#include "llvm/PassRegistry.h"

namespace llvm {

/// CFI label insertion pass.
class CFILabelInserter : public MachineFunctionPass {
public:
  /// This pass's unique ID.
  static char ID;

  /// Construct a new instance of this pass.
  CFILabelInserter(): MachineFunctionPass(ID) {}

  /// Insert CFI labels on the function's entry block and any blocks which are
  /// indirect jump targets.
  ///
  /// @param MF The machine function on which to run this pass.
  /// @return   True if the machine function was modified, otherwise false.
  virtual bool runOnMachineFunction(MachineFunction &MF) override;

  /// Get this pass's dependencies and the set of analyses it preserves.
  ///
  /// @param AU The object to populate with this pass's dependencies and
  ///           preserved analyses.
  virtual void getAnalysisUsage(AnalysisUsage &AU) const override;

private:
  /// Determine if a machine basic block needs a CFI label.
  ///
  /// @param MBB  The machine basic block to check.
  /// @return     True if `MBB` needs a CFI label, otherwise false.
  bool needsLabel(const MachineBasicBlock &MBB) const;

  /// Add a CFI label at the point immediately preceeding the iterator.
  ///
  /// @param MBB  The machine basic block to which the CFI label will be added.
  /// @param I    The point at which to insert the CFI label.
  /// @param dl   A debug location to attach to the CFI label.
  void addLabel(MachineBasicBlock &MBB,
                MachineBasicBlock::iterator I,
                const DebugLoc &dl);

  /// The Instruction Info for the current target.
  const TargetInstrInfo *TII = nullptr;
};

/// Create an instance of the CFI label insertion pass.
///
/// @return A new instance of the CFI label insertion pass.
FunctionPass *createCFILabelInserter();

/// Initialize and register the CFI label insertion pass.
///
/// @param PR The pass registry with which to register the pass.
void initializeCFILabelInserterPass(PassRegistry &PR);
}

#endif /* LLVM_CODEGEN_CFILABELINSERTER_H */
