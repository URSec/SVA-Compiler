//===-- X86MachineFunctionInfo.cpp - X86 machine function info ------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "X86MachineFunctionInfo.h"
#include "X86RegisterInfo.h"
#include "X86Subtarget.h"
#include "llvm/CodeGen/MachineRegisterInfo.h"
#include "llvm/CodeGen/TargetRegisterInfo.h"
#include "llvm/CodeGen/TargetSubtargetInfo.h"

using namespace llvm;

void X86MachineFunctionInfo::anchor() { }

void X86MachineFunctionInfo::setRestoreBasePointer(const MachineFunction *MF) {
  if (!RestoreBasePointerOffset) {
    const X86RegisterInfo *RegInfo = static_cast<const X86RegisterInfo *>(
      MF->getSubtarget().getRegisterInfo());
    unsigned SlotSize = RegInfo->getSlotSize();
    for (const MCPhysReg *CSR = MF->getRegInfo().getCalleeSavedRegs();
         unsigned Reg = *CSR; ++CSR) {
      if (X86::GR64RegClass.contains(Reg) || X86::GR32RegClass.contains(Reg))
        RestoreBasePointerOffset -= SlotSize;
    }
  }
}

int X86MachineFunctionInfo::initRAIndex(MachineFunction *MF) {
  const X86RegisterInfo *TRI =
    MF->getSubtarget<X86Subtarget>().getRegisterInfo();

  if (ReturnAddrIndex == 0) {
    // Set up a frame object for the return address.
    unsigned int SlotSize = TRI->getSlotSize();
    ReturnAddrIndex = MF->getFrameInfo()
                        .CreateFixedObject(SlotSize, -(int64_t)SlotSize, false);
  }

  return ReturnAddrIndex;
}
