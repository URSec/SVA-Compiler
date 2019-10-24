;;;-----------------------------------------------------------------------------
;;; SVA CFI Indirect Call Test
;;;-----------------------------------------------------------------------------
;;; This test checks that SVA's CFI pass properly instruments indirect calls.
;;;-----------------------------------------------------------------------------

; RUN: opt -sva-cfi -S < %s | FileCheck %s

target datalayout = "e-m:e-i1:8:8-i8:8:8-i16:16:16-i32:32:32-i64:64:64-p:64:64:64-n8:16:32:64"
target triple = "x86_64-unknown-linux-gnu"

declare void()* @make_ptr() nounwind

define void @test_call() nounwind noreturn {
; CHECK-LABEL: @test_call

; CHECK: %[[FN_PTR:[[:alnum:]_.]+]] = call void ()* @make_ptr()
; CHECK: %[[INT_PTR:[[:alnum:]_.]+]] = ptrtoint void ()* %[[FN_PTR]] to i64
; CHECK: %[[ALIGNED:[[:alnum:]_.]+]] = and i64 %[[INT_PTR]], -32
; CHECK: %[[INT_MASKED:[[:alnum:]_.]+]] = or i64 %[[ALIGNED]], -140737488355328
; CHECK: %[[MASKED:[[:alnum:]_.]+]] = inttoptr i64 %[[INT_MASKED]] to void ()*
; CHECK: %[[HAS_LABEL:[[:alnum:]_.]+]] = icmp eq i32 -98693133, %{{[[:alnum:]_.]+}}
; CHECK: br i1 %[[HAS_LABEL]], label %{{[[:alnum:]_.]+}}, label %cfi_check_fail
; CHECK: call void %[[MASKED]]()
; CHECK-NEXT: unreachable
    %1 = call void()* @make_ptr() nounwind
    call void() %1() nounwind noreturn
    unreachable

; CHECK-LABEL: cfi_check_fail:
; CHECK-NEXT: call void @abort()
; CHECK-NEXT: unreachable
}
