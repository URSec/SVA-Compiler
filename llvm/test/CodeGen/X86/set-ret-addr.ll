;;;-----------------------------------------------------------------------------
;;; X86 Set Return Address Intrinsic Codegen Test
;;;-----------------------------------------------------------------------------
;;; This test checks that the code generator correctly handles the
;;; `llvm.setreturnaddress` intrinsic.
;;;-----------------------------------------------------------------------------

; RUN: llc < %s -mtriple=x86_64-- | FileCheck --check-prefixes=CHECK,CHECK64 %s
; RUN: llc < %s -mtriple=x86_64---gnux32 | FileCheck --check-prefixes=CHECK,CHECKX32 %s
; RUN: llc < %s -mtriple=i386-- | FileCheck --check-prefixes=CHECK,CHECK32 %s

; Also test fast isel
; RUN: llc < %s -mtriple=x86_64-- -fast-isel | FileCheck --check-prefixes=CHECK,CHECK64 %s
; RUN: llc < %s -mtriple=x86_64--gnux32 -fast-isel | FileCheck --check-prefixes=CHECK,CHECKX32 %s
; RUN: llc < %s -mtriple=i386-- -fast-isel | FileCheck --check-prefixes=CHECK,CHECK32 %s

declare void @llvm.setreturnaddress(i8*) nounwind

define void @test() nounwind uwtable {
; CHECK-LABEL: test

; CHECK64: movq $0, {{\d*}}(%rsp)
; CHECK64-NEXT: retq

; CHECKX32: movl $0, {{\d*}}(%esp)
; CHECKX32-NEXT: retq

; CHECK32: movl $0, {{\d*}}(%esp)
; CHECK32-NEXT: retl

; CHECK-NEXT: func_end

  call void @llvm.setreturnaddress(i8* null)
  ret void
}
