;;;-----------------------------------------------------------------------------
;;; SVA CFI No Indirect Control Flow Transfers Test
;;;-----------------------------------------------------------------------------
;;; This test checks that SVA's CFI pass does not insert a dead error block when
;;; a function has no indirect control flow transfers.
;;;-----------------------------------------------------------------------------

; RUN: opt -sva-cfi -S < %s | FileCheck %s

target datalayout = "e-m:e-i1:8:8-i8:8:8-i16:16:16-i32:32:32-i64:64:64-p:64:64:64-n8:16:32:64"
target triple = "x86_64-unknown-linux-gnu"

define void @test_no_indirect() nounwind noreturn {
; CHECK-LABEL: @test_no_indirect

    unreachable

; CHECK-NOT: cfi_check_fail
}
