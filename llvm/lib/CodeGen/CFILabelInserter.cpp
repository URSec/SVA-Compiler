//===-- CFILabelInserter.cpp - Late-stage CFI Label Insertion -------------===//
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

#define DEBUG_TYPE "sva-cfi-label-insertion"

#include <iterator>

#include "llvm/CodeGen/CFILabelInserter.h"
#include "llvm/CodeGen/MachineInstr.h"
#include "llvm/CodeGen/MachineInstrBuilder.h"
#include "llvm/CodeGen/TargetOpcodes.h"
#include "llvm/PassSupport.h"

namespace llvm {
void CFILabelInserter::addLabel(MachineBasicBlock &MBB,
                                MachineBasicBlock::iterator I,
                                const DebugLoc &dl) {
  MachineInstrBuilder MIB
    = BuildMI(MBB, I, dl, TII->get(TargetOpcode::CFI_LABEL));

  // Give the target a chance to expand the label.
  TII->expandPostRAPseudo(*MIB.getInstr());
}

bool CFILabelInserter::needsLabel(const MachineFunction &MF) const {
  const Function& F = MF.getFunction();
  return !F.hasLocalLinkage() || F.hasAddressTaken();
}

bool CFILabelInserter::needsLabel(const MachineBasicBlock &MBB) const {
  // TODO: Whether or not we need to put labels on exception landing pads
  // depends on whether or not we trust the exception handling library.
  return MBB.isEHPad() || MBB.isEHFuncletEntry() ||
    MBB.isCleanupFuncletEntry() || MBB.hasAddressTaken();
}

void CFILabelInserter::getAnalysisUsage(AnalysisUsage &AU) const {
  AU.setPreservesCFG();

  MachineFunctionPass::getAnalysisUsage(AU);
}

bool CFILabelInserter::runOnMachineFunction(MachineFunction &MF) {
  TII = MF.getSubtarget().getInstrInfo();

  bool Changed = false;

  for (MachineBasicBlock &MBB : MF) {
    if (needsLabel(MBB) || (&MBB == &MF.front() && needsLabel(MF))) {
      // Use "unknown" as the debug location for function and block labels.
      DebugLoc dl{};
      addLabel(MBB, MBB.begin(), dl);
      Changed = true;
    }
    for (MachineInstr &MI : MBB) {
      if (MI.isCall() &&
          // A call that is also a return is a tail call. Tail calls don't
          // return to their caller and therefore don't need CFI labels.
          !MI.isReturn()) {
        addLabel(MBB,
                 std::next(MachineBasicBlock::iterator(MI)),
                 MI.getDebugLoc());
        Changed = true;
      }
    }
  }

  return Changed;
}

char CFILabelInserter::ID = 0;
}

using namespace llvm;

FunctionPass *llvm::createCFILabelInserter() {
  return new CFILabelInserter();
}

INITIALIZE_PASS(CFILabelInserter, DEBUG_TYPE, "CFI Label insertion pass", false, false)
