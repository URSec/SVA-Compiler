;;;-----------------------------------------------------------------------------
;;; SVA SFI MPX Bounds Check Test
;;;-----------------------------------------------------------------------------
;;; This test checks that SVA's SFI pass properly uses MPX bounds checks.
;;;-----------------------------------------------------------------------------

; RUN: opt -sva-sfi --enable-sfi-loadchecks --enable-mpx-sfi -S < %s | FileCheck %s

target datalayout = "e-m:e-i1:8:8-i8:8:8-i16:16:16-i32:32:32-i64:64:64-p:64:64:64-n8:16:32:64"
target triple = "x86_64-unknown-linux-gnu"

define void @test_load() nounwind {
; CHECK-LABEL: @test_load

; CHECK-NEXT: %[[PTR:[[:alnum:]_.]+]] = ptrtoint i32* undef to i64
; CHECK-NEXT: %[[NORMALIZED:[[:alnum:]_.]+]] = sub i64 %[[PTR]], -3298534883328
; CHECK-NEXT: %[[NORMALIZED_PTR:[[:alnum:]_.]+]] = inttoptr i64 %[[NORMALIZED]] to i8*
; CHECK-NEXT: call void @llvm.x86.bndcl(i8* %[[NORMALIZED_PTR]], i32 0)
; CHECK-NEXT: %{{[[:alnum:]_.]+}} = load i32, i32* undef
; CHECK-NEXT: ret void
    %1 = load i32, i32* undef
    ret void
}

define void @test_store() nounwind {
; CHECK-LABEL: @test_store

; CHECK-NEXT: %[[PTR:[[:alnum:]_.]+]] = ptrtoint i32* undef to i64
; CHECK-NEXT: %[[NORMALIZED:[[:alnum:]_.]+]] = sub i64 %[[PTR]], -3298534883328
; CHECK-NEXT: %[[NORMALIZED_PTR:[[:alnum:]_.]+]] = inttoptr i64 %[[NORMALIZED]] to i8*
; CHECK-NEXT: call void @llvm.x86.bndcl(i8* %[[NORMALIZED_PTR]], i32 0)
; CHECK-NEXT: store i32 0, i32* undef
; CHECK-NEXT: ret void
    store i32 0, i32* undef
    ret void
}

define void @test_atomic_rmw() nounwind {
; CHECK-LABEL: @test_atomic_rmw

; CHECK-NEXT: %[[PTR:[[:alnum:]_.]+]] = ptrtoint i32* undef to i64
; CHECK-NEXT: %[[NORMALIZED:[[:alnum:]_.]+]] = sub i64 %[[PTR]], -3298534883328
; CHECK-NEXT: %[[NORMALIZED_PTR:[[:alnum:]_.]+]] = inttoptr i64 %[[NORMALIZED]] to i8*
; CHECK-NEXT: call void @llvm.x86.bndcl(i8* %[[NORMALIZED_PTR]], i32 0)
; CHECK-NEXT: atomicrmw add i32* undef, i32 0 seq_cst
; CHECK-NEXT: ret void
    atomicrmw add i32* undef, i32 0 seq_cst
    ret void
}

define void @test_atomic_cmpxchg() nounwind {
; CHECK-LABEL: @test_atomic_cmpxchg

; CHECK-NEXT: %[[PTR:[[:alnum:]_.]+]] = ptrtoint i32* undef to i64
; CHECK-NEXT: %[[NORMALIZED:[[:alnum:]_.]+]] = sub i64 %[[PTR]], -3298534883328
; CHECK-NEXT: %[[NORMALIZED_PTR:[[:alnum:]_.]+]] = inttoptr i64 %[[NORMALIZED]] to i8*
; CHECK-NEXT: call void @llvm.x86.bndcl(i8* %[[NORMALIZED_PTR]], i32 0)
; CHECK-NEXT: cmpxchg i32* undef, i32 0, i32 1 seq_cst seq_cst
; CHECK-NEXT: ret void
    cmpxchg i32* undef, i32 0, i32 1 seq_cst seq_cst
    ret void
}
