;;;-----------------------------------------------------------------------------
;;; SVA SFI Atomic Operations Test
;;;-----------------------------------------------------------------------------
;;; This test checks that SVA's SFI pass properly instruments atomic operations.
;;;-----------------------------------------------------------------------------

; RUN: opt -sva-sfi -S < %s | FileCheck %s

target datalayout = "e-m:e-i1:8:8-i8:8:8-i16:16:16-i32:32:32-i64:64:64-p:64:64:64-n8:16:32:64"
target triple = "x86_64-unknown-linux-gnu"

define void @test_atomic_rmw() nounwind {
; CHECK-LABEL: @test_atomic_rmw

; CHECK-NEXT: %[[PTR:[[:alnum:]_.]+]] = ptrtoint i8* undef to i64
; CHECK-NEXT: %[[SHIFTED:[[:alnum:]_.]+]] = lshr i64 %[[PTR]], 40
; CHECK-NEXT: %[[IN_GHOST_MEM:[[:alnum:]_.]+]] = icmp eq i64 %[[SHIFTED]], 16777213
; CHECK-NEXT: %[[MASK:[[:alnum:]_.]+]] = select i1 %[[IN_GHOST_MEM]], i64 2199023255552, i64 0
; CHECK-NEXT: %[[INT_MASKED:[[:alnum:]_.]+]] = or i64 %[[PTR]], %[[MASK]]
; CHECK-NEXT: %[[MASKED:[[:alnum:]_.]+]] = inttoptr i64 %[[INT_MASKED]] to i8*
; CHECK-NEXT: atomicrmw add i8* %[[MASKED]], i8 0 seq_cst
; CHECK-NEXT: ret void
    atomicrmw add i8* undef, i8 0 seq_cst
    ret void
}

define void @test_atomic_cmpxchg() nounwind {
; CHECK-LABEL: @test_atomic_cmpxchg

; CHECK-NEXT: %[[PTR:[[:alnum:]_.]+]] = ptrtoint i8* undef to i64
; CHECK-NEXT: %[[SHIFTED:[[:alnum:]_.]+]] = lshr i64 %[[PTR]], 40
; CHECK-NEXT: %[[IN_GHOST_MEM:[[:alnum:]_.]+]] = icmp eq i64 %[[SHIFTED]], 16777213
; CHECK-NEXT: %[[MASK:[[:alnum:]_.]+]] = select i1 %[[IN_GHOST_MEM]], i64 2199023255552, i64 0
; CHECK-NEXT: %[[INT_MASKED:[[:alnum:]_.]+]] = or i64 %[[PTR]], %[[MASK]]
; CHECK-NEXT: %[[MASKED:[[:alnum:]_.]+]] = inttoptr i64 %[[INT_MASKED]] to i8*
; CHECK-NEXT: cmpxchg i8* %[[MASKED]], i8 0, i8 1 seq_cst seq_cst
; CHECK-NEXT: ret void
    cmpxchg i8* undef, i8 0, i8 1 seq_cst seq_cst
    ret void
}
