;;;-----------------------------------------------------------------------------
;;; SVA SFI MPX Bounds Check Test
;;;-----------------------------------------------------------------------------
;;; This test checks that SVA's SFI pass properly uses MPX bounds checks.
;;;-----------------------------------------------------------------------------

; RUN: opt -sva-sfi --enable-mpx-sfi -S < %s | FileCheck %s

target datalayout = "e-m:e-i1:8:8-i8:8:8-i16:16:16-i32:32:32-i64:64:64-p:64:64:64-n8:16:32:64"
target triple = "x86_64-unknown-linux-gnu"

declare i32* @make_ptr() nounwind

define void @test_load() nounwind {
; CHECK-LABEL: @test_load

; CHECK-NEXT: %[[PTR:[[:alnum:]_.]+]] = call i32* @make_ptr()
; CHECK-NEXT: %[[INT_PTR:[[:alnum:]_.]+]] = ptrtoint i32* %[[PTR]] to i64
; CHECK-NEXT: %[[NORMALIZED:[[:alnum:]_.]+]] = sub i64 %[[INT_PTR]], -134140418588672
; CHECK-NEXT: %[[NORMALIZED_PTR:[[:alnum:]_.]+]] = inttoptr i64 %[[NORMALIZED]] to i8*
; CHECK-NEXT: call void @llvm.x86.bndcl(i8* %[[NORMALIZED_PTR]], i32 0)
; CHECK-NEXT: %{{[[:alnum:]_.]+}} = load i32, i32* %[[PTR]]
; CHECK-NEXT: ret void
    %1 = call i32* @make_ptr() nounwind
    %2 = load i32, i32* %1
    ret void
}

define void @test_store() nounwind {
; CHECK-LABEL: @test_store

; CHECK-NEXT: %[[PTR:[[:alnum:]_.]+]] = call i32* @make_ptr()
; CHECK-NEXT: %[[INT_PTR:[[:alnum:]_.]+]] = ptrtoint i32* %[[PTR]] to i64
; CHECK-NEXT: %[[NORMALIZED:[[:alnum:]_.]+]] = sub i64 %[[INT_PTR]], -134140418588672
; CHECK-NEXT: %[[NORMALIZED_PTR:[[:alnum:]_.]+]] = inttoptr i64 %[[NORMALIZED]] to i8*
; CHECK-NEXT: call void @llvm.x86.bndcl(i8* %[[NORMALIZED_PTR]], i32 0)
; CHECK-NEXT: store i32 0, i32* %[[PTR]]
; CHECK-NEXT: ret void
    %1 = call i32* @make_ptr() nounwind
    store i32 0, i32* %1
    ret void
}

define void @test_atomic_rmw() nounwind {
; CHECK-LABEL: @test_atomic_rmw

; CHECK-NEXT: %[[PTR:[[:alnum:]_.]+]] = call i32* @make_ptr()
; CHECK-NEXT: %[[INT_PTR:[[:alnum:]_.]+]] = ptrtoint i32* %[[PTR]] to i64
; CHECK-NEXT: %[[NORMALIZED:[[:alnum:]_.]+]] = sub i64 %[[INT_PTR]], -134140418588672
; CHECK-NEXT: %[[NORMALIZED_PTR:[[:alnum:]_.]+]] = inttoptr i64 %[[NORMALIZED]] to i8*
; CHECK-NEXT: call void @llvm.x86.bndcl(i8* %[[NORMALIZED_PTR]], i32 0)
; CHECK-NEXT: atomicrmw add i32* %[[PTR]], i32 0 seq_cst
; CHECK-NEXT: ret void
    %1 = call i32* @make_ptr() nounwind
    atomicrmw add i32* %1, i32 0 seq_cst
    ret void
}

define void @test_atomic_cmpxchg() nounwind {
; CHECK-LABEL: @test_atomic_cmpxchg

; CHECK-NEXT: %[[PTR:[[:alnum:]_.]+]] = call i32* @make_ptr()
; CHECK-NEXT: %[[INT_PTR:[[:alnum:]_.]+]] = ptrtoint i32* %[[PTR]] to i64
; CHECK-NEXT: %[[NORMALIZED:[[:alnum:]_.]+]] = sub i64 %[[INT_PTR]], -134140418588672
; CHECK-NEXT: %[[NORMALIZED_PTR:[[:alnum:]_.]+]] = inttoptr i64 %[[NORMALIZED]] to i8*
; CHECK-NEXT: call void @llvm.x86.bndcl(i8* %[[NORMALIZED_PTR]], i32 0)
; CHECK-NEXT: cmpxchg i32* %[[PTR]], i32 0, i32 1 seq_cst seq_cst
; CHECK-NEXT: ret void
    %1 = call i32* @make_ptr() nounwind
    cmpxchg i32* %1, i32 0, i32 1 seq_cst seq_cst
    ret void
}
