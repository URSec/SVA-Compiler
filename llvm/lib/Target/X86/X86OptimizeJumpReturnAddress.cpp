#include "X86InstrInfo.h"
#include "X86MachineFunctionInfo.h"
#include "X86RegisterInfo.h"
#include "X86Subtarget.h"
#include <llvm/ADT/Optional.h>
#include <llvm/ADT/SmallVector.h>
#include <llvm/PassSupport.h>
#include <llvm/CodeGen/MachineBasicBlock.h>
#include <llvm/CodeGen/MachineFunction.h>
#include <llvm/CodeGen/MachineFunctionPass.h>
#include <llvm/CodeGen/MachineInstr.h>
#include <llvm/CodeGen/MachineInstrBuilder.h>
#include <llvm/CodeGen/MachineOperand.h>
#include <llvm/CodeGen/MachineRegisterInfo.h>

#include <algorithm>
#include <iterator>

using namespace llvm;

#define DEBUG_TYPE "x86-optimize-jmpret"

namespace {

/// Pass to optimize uses of the return address for jump returns.
///
/// This pass looks at uses of the return address (loads and stores with a frame
/// index operand corresponding to the return address) and elides them wherever
/// possible.
///
/// Currently, this pass only looks at basic blocks which terminate with a jump
/// return and does not attempt to perform escape analysis or alias analysis,
/// instead assuming that any load or store may alias the return address and that
/// any call may load from or store to it. This overly-conservative
/// approximation is sufficient for this pass's intetded use cases.
class X86OptimizeJumpReturnAddress : public MachineFunctionPass {
public:
  static char ID;

  X86OptimizeJumpReturnAddress();

  bool runOnMachineFunction(MachineFunction &MF) override;

private:
  void takeAddressFromStore(MachineBasicBlock &MBB, MachineInstr &MI);

  const X86Subtarget *Subtarget;
  const X86InstrInfo *TII;
  MachineRegisterInfo *MRI;
  int RetAddrFI;
};

char X86OptimizeJumpReturnAddress::ID;

X86OptimizeJumpReturnAddress::X86OptimizeJumpReturnAddress()
    : MachineFunctionPass(ID) { }

/// Eliminate spills of the return address immediately preceeding a return.
///
/// This only handles loads from and stores to the return address's frame index
/// that occur after the last load or store to any other location and after the
/// last call.
///
/// @param  MBB The epilog `MachineBasicBlock`.
/// @param  Ret The return instruction
void X86OptimizeJumpReturnAddress::takeAddressFromStore(MachineBasicBlock &MBB,
                                                        MachineInstr &Ret) {
  SmallVector<MachineInstr*, 4> RetAddrUses;

  for (auto& MI : make_range(MBB.rbegin(), MBB.rend())) {
    switch (MI.getOpcode()) {
    // Loads
    case X86::MOV32rm:
    case X86::MOV64rm: {
      MachineOperand MO = MI.getOperand(1);
      if (MO.isFI() && MO.getIndex() == RetAddrFI) {
        RetAddrUses.push_back(&MI);
        continue;
      }
      break;
    }
    // Stores
    case X86::MOV32mr:
    case X86::MOV64mr: {
      MachineOperand MO = MI.getOperand(0);
      if (MO.isFI() && MO.getIndex() == RetAddrFI) {
        RetAddrUses.push_back(&MI);
        continue;
      }
      break;
    }
    }

    if (MI.isCall() || MI.mayLoadOrStore()) {
      // Assume that the return address is aliased and that its address has
      // escaped.
      break;
    }
  }

  // At this point, we know by construction that the `MachineInstr`s in
  // `RetAddrUses` are the only loads of or stores to the return address.
  // Therefore, we can replace all loads with the value previously stored.
  // Additionally, we may eliminate all stores if this basic block has no
  // terminators other than the return, as those stores must be dead since the
  // return address will be dealocated when the function returns.
  llvm::Optional<Register> LastStore = llvm::None;
  bool HasOneTerminator = std::next(MBB.rbegin()) != MBB.rend() &&
                          !std::next(MBB.rbegin())->isTerminator();
  for (auto MI : make_range(RetAddrUses.rbegin(), RetAddrUses.rend())) {
    switch (MI->getOpcode()) {
    // Stores
    case X86::MOV32mr:
    case X86::MOV64mr: {
      MachineOperand RegOp = MI->getOperand(5);
      LastStore = RegOp.getReg();
      RegOp.setIsKill(false);
      if (HasOneTerminator) {
        MI->eraseFromParent();
      }
      break;
    }
    // Loads
    case X86::MOV32rm:
    case X86::MOV64rm: {
      if (LastStore) {
        // Replace the load with a copy from the value previously stored
        Register Reg = MI->getOperand(0).getReg();
        BuildMI(MBB, MI, MI->getDebugLoc(), TII->get(TargetOpcode::COPY), Reg)
            .addReg(*LastStore);
        MI->eraseFromParent();
      }
      break;
    }
    default:
      llvm_unreachable("Opcode magically changed");
    }
  }
}

bool X86OptimizeJumpReturnAddress::runOnMachineFunction(MachineFunction &MF) {
  Subtarget = &MF.getSubtarget<X86Subtarget>();
  TII = Subtarget->getInstrInfo();
  MRI = &MF.getRegInfo();
  RetAddrFI = MF.getInfo<X86MachineFunctionInfo>()->getRAIndex();

  if (RetAddrFI == 0) {
    return false;
  }

  for (auto& MBB : MF) {
    if (!MBB.empty()) {
      auto& MI = MBB.back();
      switch (MI.getOpcode()) {
      case X86::JMPRETL:
      case X86::JMPRETQ:
      case X86::JMPRETIL:
      case X86::JMPRETIQ:
        takeAddressFromStore(MBB, MI);
      }
    }
  }

  return true;
}

}

namespace llvm {

FunctionPass *createX86OptimizeJumpReturnAddressPass() {
  return new X86OptimizeJumpReturnAddress();
}

}

INITIALIZE_PASS(X86OptimizeJumpReturnAddress, DEBUG_TYPE,
                "Optimize uses of the return address for jump returns",
                false, false)
