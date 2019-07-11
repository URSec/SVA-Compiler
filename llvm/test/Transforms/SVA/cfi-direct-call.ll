;;;-----------------------------------------------------------------------------
;;; SVA CFI Direct Call Test
;;;-----------------------------------------------------------------------------
;;; This test checks that SVA's CFI pass does not insert instrumentation for a
;;; direct call.
;;;-----------------------------------------------------------------------------

; RUN: opt -sva-cfi -S < %s | FileCheck %s

target datalayout = "e-m:e-i1:8:8-i8:8:8-i16:16:16-i32:32:32-i64:64:64-p:64:64:64-n8:16:32:64"
target triple = "x86_64-unknown-linux-gnu"

declare void @exit(i32) nounwind noreturn

define void @test_direct_call() nounwind noreturn {
; CHECK-LABEL: @test_direct_call

; CHECK-NOT: inttoptr
; CHECK-NOT: ptrtoint
; CHECK-NOT: load
; CHECK-NOT: br
; CHECK: call void @exit(i32 0)
; CHECK-NEXT: unreachable
    call void @exit(i32 0) nounwind noreturn
    unreachable
}
