;;;-----------------------------------------------------------------------------
;;; SVA SFI Load Test
;;;-----------------------------------------------------------------------------
;;; This test checks that SVA's SFI pass properly instruments loads.
;;;-----------------------------------------------------------------------------

; RUN: opt -sva-sfi --enable-sfi-loadchecks -S < %s | FileCheck %s

target datalayout = "e-m:e-i1:8:8-i8:8:8-i16:16:16-i32:32:32-i64:64:64-p:64:64:64-n8:16:32:64"
target triple = "x86_64-unknown-linux-gnu"

declare i8* @make_ptr() nounwind

define void @test_load() nounwind {
; CHECK-LABEL: @test_load

; CHECK-NEXT: %[[PTR:[[:alnum:]_.]+]] = call i8* @make_ptr()
; CHECK-NEXT: %[[INT_PTR:[[:alnum:]_.]+]] = ptrtoint i8* %[[PTR]] to i64
; CHECK-NEXT: %[[SHIFTED:[[:alnum:]_.]+]] = lshr i64 %[[INT_PTR]], 40
; CHECK-NEXT: %[[IN_GHOST_MEM:[[:alnum:]_.]+]] = icmp eq i64 %[[SHIFTED]], 16777094
; CHECK-NEXT: %[[MASK:[[:alnum:]_.]+]] = select i1 %[[IN_GHOST_MEM]], i64 8796093022208, i64 0
; CHECK-NEXT: %[[INT_MASKED:[[:alnum:]_.]+]] = or i64 %[[INT_PTR]], %[[MASK]]
; CHECK-NEXT: %[[MASKED:[[:alnum:]_.]+]] = inttoptr i64 %[[INT_MASKED]] to i8*
; CHECK-NEXT: %{{[[:alnum:]_.]+}} = load i8, i8* %[[MASKED]]
; CHECK-NEXT: ret void
    %1 = call i8* @make_ptr() nounwind
    %2 = load i8, i8* %1
    ret void
}

define void @test_atomic_load() nounwind {
; CHECK-LABEL: @test_atomic_load

; CHECK-NEXT: %[[PTR:[[:alnum:]_.]+]] = call i8* @make_ptr()
; CHECK-NEXT: %[[INT_PTR:[[:alnum:]_.]+]] = ptrtoint i8* %[[PTR]] to i64
; CHECK-NEXT: %[[SHIFTED:[[:alnum:]_.]+]] = lshr i64 %[[INT_PTR]], 40
; CHECK-NEXT: %[[IN_GHOST_MEM:[[:alnum:]_.]+]] = icmp eq i64 %[[SHIFTED]], 16777094
; CHECK-NEXT: %[[MASK:[[:alnum:]_.]+]] = select i1 %[[IN_GHOST_MEM]], i64 8796093022208, i64 0
; CHECK-NEXT: %[[INT_MASKED:[[:alnum:]_.]+]] = or i64 %[[INT_PTR]], %[[MASK]]
; CHECK-NEXT: %[[MASKED:[[:alnum:]_.]+]] = inttoptr i64 %[[INT_MASKED]] to i8*
; CHECK-NEXT: %{{[[:alnum:]_.]+}} = load atomic i8, i8* %[[MASKED]] seq_cst, align 8
; CHECK-NEXT: ret void
    %1 = call i8* @make_ptr() nounwind
    %2 = load atomic i8, i8* %1 seq_cst, align 8
    ret void
}

define void @test_volatile_load() nounwind {
; CHECK-LABEL: @test_volatile_load

; CHECK-NEXT: %[[PTR:[[:alnum:]_.]+]] = call i8* @make_ptr()
; CHECK-NEXT: %[[INT_PTR:[[:alnum:]_.]+]] = ptrtoint i8* %[[PTR]] to i64
; CHECK-NEXT: %[[SHIFTED:[[:alnum:]_.]+]] = lshr i64 %[[INT_PTR]], 40
; CHECK-NEXT: %[[IN_GHOST_MEM:[[:alnum:]_.]+]] = icmp eq i64 %[[SHIFTED]], 16777094
; CHECK-NEXT: %[[MASK:[[:alnum:]_.]+]] = select i1 %[[IN_GHOST_MEM]], i64 8796093022208, i64 0
; CHECK-NEXT: %[[INT_MASKED:[[:alnum:]_.]+]] = or i64 %[[INT_PTR]], %[[MASK]]
; CHECK-NEXT: %[[MASKED:[[:alnum:]_.]+]] = inttoptr i64 %[[INT_MASKED]] to i8*
; CHECK-NEXT: %{{[[:alnum:]_.]+}} = load volatile i8, i8* %[[MASKED]]
; CHECK-NEXT: ret void
    %1 = call i8* @make_ptr() nounwind
    %2 = load volatile i8, i8* %1
    ret void
}
