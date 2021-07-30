;;;-----------------------------------------------------------------------------
;;; X86 Split Stack In Memory Argument Codegen Test
;;;-----------------------------------------------------------------------------
;;; This test checks that the code generator generates references to in memory
;;; arguments using the data stack pointer.
;;;-----------------------------------------------------------------------------

; RUN: llc < %s -mtriple=x86_64-- --frame-pointer=all --split-stack | FileCheck --enable-var-scope --implicit-check-not '(%rsp)' %s
; RUN: llc < %s -mtriple=x86_64-- --frame-pointer=none --split-stack | FileCheck --enable-var-scope --implicit-check-not '(%rsp)' %s

%large = type { [64 x i64] }

; CHECK-LABEL: callee_large
define i64 @callee_large(%large* byval(%large)) nounwind uwtable noredzone noinline {
  ; CHECK: movq (%r15), %rax
  %arr = getelementptr inbounds %large, %large* %0, i64 0, i32 0, i64 0
  %tmp = load i64, i64* %arr
  ret i64 %tmp
}

; CHECK-LABEL: caller_large
define void @caller_large() nounwind uwtable noredzone {
  ; CHECK: subq {{.*}}, %r15
  ; CHECK-NOT: push
  ; CHECK-NOT: movq %rsp, %rdi
  %arg = alloca %large
  call i64 @callee_large(%large* %arg)
  ret void
}

%small = type { [8 x i64] }

; CHECK-LABEL: callee_small
define i64 @callee_small(%small* byval(%small)) nounwind uwtable noredzone noinline {
  ; CHECK: movq (%r15), %rax
  %arr = getelementptr inbounds %small, %small* %0, i64 0, i32 0, i64 0
  %tmp = load i64, i64* %arr
  ret i64 %tmp
}

; CHECK-LABEL: caller_small
define void @caller_small() nounwind uwtable noredzone {
  ; CHECK: subq {{.*}}, %r15
  ; CHECK-NOT: push
  ; CHECK-NOT: movq %rsp, %rdi
  %arg = alloca %small
  call i64 @callee_small(%small* %arg)
  ret void
}
