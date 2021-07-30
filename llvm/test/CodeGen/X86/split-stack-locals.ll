;;;-----------------------------------------------------------------------------
;;; X86 Split Stack Local Variable Reference Codegen Test
;;;-----------------------------------------------------------------------------
;;; This test checks that the code generator generates references to local
;;; variables using the data stack pointer.
;;;-----------------------------------------------------------------------------

; RUN: llc < %s -mtriple=x86_64-- --frame-pointer=none --split-stack | FileCheck --enable-var-scope %s

; CHECK-LABEL: test
define void @test() nounwind uwtable noredzone {
  %local = alloca i32

  ;; NB: Offset must be non-negative
  ; CHECK: movl $0, {{([[:digit:]]+|0x[[:xdigit:]]+)?}}(%r15)
  store volatile i32 0, i32* %local

  ret void
}
