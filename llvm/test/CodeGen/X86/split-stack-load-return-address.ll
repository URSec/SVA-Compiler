;;;-----------------------------------------------------------------------------
;;; X86 Split Stack Return Address Reference Codegen Test
;;;-----------------------------------------------------------------------------
;;; This test checks that the code generator generates references to the return
;;; address using the *normal* (control) stack pointer.
;;;-----------------------------------------------------------------------------

; RUN: llc < %s -mtriple=x86_64-- --frame-pointer=all --split-stack | FileCheck --enable-var-scope --implicit-check-not '(%r15)' %s
; RUN: llc < %s -mtriple=x86_64-- --frame-pointer=none --split-stack | FileCheck --enable-var-scope --implicit-check-not '(%r15)' %s

declare i8* @llvm.returnaddress(i32) nounwind

; CHECK-LABEL: test
define i8* @test() nounwind uwtable {
  ; CHECK: movq {{.*}}(%rsp)
  %retaddr = call i8* @llvm.returnaddress(i32 0)
  ret i8* %retaddr
}
