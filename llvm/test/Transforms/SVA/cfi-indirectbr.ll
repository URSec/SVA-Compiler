;;;-----------------------------------------------------------------------------
;;; SVA CFI Indirect Branch Instrumentation Test
;;;-----------------------------------------------------------------------------
;;; This test checks that SVA's CFI pass properly instruments indirect branches.
;;;-----------------------------------------------------------------------------

; RUN: opt -sva-cfi -S < %s | FileCheck %s

target datalayout = "e-m:e-i1:8:8-i8:8:8-i16:16:16-i32:32:32-i64:64:64-p:64:64:64-n8:16:32:64"
target triple = "x86_64-unknown-linux-gnu"

declare i8* @make_ptr() nounwind

define void @test_indirect_branch() nounwind noreturn {
; CHECK-LABEL: @test_indirect_branch

; CHECK: %[[LABEL_PTR:[[:alnum:]_.]+]] = call i8* @make_ptr()
; CHECK: %[[INT_PTR:[[:alnum:]_.]+]] = ptrtoint i8* %[[LABEL_PTR]] to i64
; CHECK: %[[INT_MASKED:[[:alnum:]_.]+]] = or i64 %[[INT_PTR]], -2147483648
; CHECK: %[[MASKED:[[:alnum:]_.]+]] = inttoptr i64 %[[INT_MASKED]] to i8*
; CHECK: %[[HAS_LABEL:[[:alnum:]_.]+]] = icmp eq i32 -98693133, %{{[[:alnum:]_.]+}}
; CHECK: br i1 %[[HAS_LABEL]], label %{{[[:alnum:]_.]+}}, label %cfi_check_fail
; CHECK: indirectbr i8* %[[MASKED]]
    %1 = call i8* @make_ptr()
    indirectbr i8* %1, [label %d1, label %d2]

d1:
    unreachable

d2:
    unreachable

; CHECK-LABEL: cfi_check_fail:
; CHECK-NEXT: call void @abort()
; CHECK-NEXT: unreachable
}
