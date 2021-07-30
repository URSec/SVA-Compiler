;;;-----------------------------------------------------------------------------
;;; X86 Split Stack Prologue and Epilogue Codegen Test
;;;-----------------------------------------------------------------------------
;;; This test checks that the code generator generates the correct prologue and
;;; epilogue sequences for the split stack.
;;;-----------------------------------------------------------------------------

; RUN: llc < %s -mtriple=x86_64-- --frame-pointer=none --split-stack | FileCheck --enable-var-scope %s

; CHECK-LABEL: test_nofp
define void @test_nofp() nounwind uwtable noredzone {
  ; CHECK-NOT: movq %rsp, %rbp
  ; CHECK-NOT: movq %r15, %rbp
  ; CHECK-NOT: subq {{.*}}, %rsp
  ; CHECK: subq [[SIZE:\$(0x[[:xdigit:]]+|[[:digit:]]+)]], %r15
  ; CHECK-NOT: subq {{.*}}, %rsp

  %local = alloca i32
  store volatile i32 0, i32* %local

  ; CHECK: addq [[SIZE]], %r15
  ; CHECK-NOT: movq %rbp, %rsp
  ; CHECK-NOT: movq %rbp, %r15
  ; CHECK: ret
  ret void
}

; CHECK-LABEL: test_fp
define void @test_fp() alignstack(32) nounwind uwtable noredzone {
  ; CHECK-NOT: movq %rsp, %rbp
  ; CHECK: movq %r15, %rbp
  ; CHECK-NOT: movq %rsp, %rbp
  ; CHECK: subq {{\$(0x[[:xdigit:]]+|[[:digit:]]+)}}, %r15

  %local = alloca i32
  store volatile i32 0, i32* %local

  ; CHECK-NOT: addq {{.*}}, %r15
  ; CHECK-NOT: movq %rbp, %rsp
  ; CHECK: movq %rbp, %r15
  ; CHECK-NOT: movq %rbp, %rsp
  ; CHECK: ret
  ret void
}
