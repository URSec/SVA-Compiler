;;;-----------------------------------------------------------------------------
;;; SVA SFI Memory Transfer Instruction Test
;;;-----------------------------------------------------------------------------
;;; This test checks that SVA's SFI pass properly instruments memory transfer
;;; intrinsics such as `memcpy`, `memmove`, and `memset`.
;;;-----------------------------------------------------------------------------

; RUN: opt -sva-sfi --enable-sfi-loadchecks -S < %s | FileCheck %s

target datalayout = "e-m:e-i1:8:8-i8:8:8-i16:16:16-i32:32:32-i64:32:64-p:64:64:64-n8:16:32:64"
target triple = "x86_64-unknown-linux-gnu"

declare void @llvm.memcpy.p0i8.p0i8.i64(i8* nocapture writeonly noalias, i8* nocapture readonly noalias, i64, i1 immarg) nounwind argmemonly
declare void @llvm.memcpy.element.unordered.atomic.p0i8.p0i8.i64(i8* nocapture writeonly noalias, i8* nocapture readonly noalias, i64, i32 immarg) nounwind argmemonly
declare void @llvm.memmove.p0i8.p0i8.i64(i8* nocapture, i8* nocapture readonly, i64, i1 immarg) nounwind argmemonly
declare void @llvm.memmove.element.unordered.atomic.p0i8.p0i8.i64(i8* nocapture, i8* nocapture readonly, i64, i32 immarg) nounwind argmemonly
declare void @llvm.memset.p0i8.i64(i8* nocapture writeonly, i8, i64, i1 immarg) nounwind argmemonly
declare void @llvm.memset.element.unordered.atomic.p0i8.i64(i8* nocapture writeonly, i8, i64, i32 immarg) nounwind argmemonly

define void @test_memcpy() nounwind {
; CHECK-LABEL: @test_memcpy

; CHECK: %[[DST:[[:alnum:]_.]+]] = ptrtoint i8* undef to i64
; CHECK: %[[SRC:[[:alnum:]_.]+]] = ptrtoint i8* undef to i64
; CHECK: call void @sva_check_buffer(i64 %[[DST]], i64 0)
; CHECK: call void @sva_check_buffer(i64 %[[SRC]], i64 0)
; CHECK: call void @llvm.memcpy.p0i8.p0i8.i64(i8* undef, i8* undef, i64 0, i1 false)
; CHECK: ret void
    call void @llvm.memcpy.p0i8.p0i8.i64(i8* undef, i8* undef, i64 0, i1 false)
    ret void
}

define void @test_atomic_memcpy() nounwind {
; CHECK-LABEL: @test_atomic_memcpy

; CHECK: %[[DST:[[:alnum:]_.]+]] = ptrtoint i8* undef to i64
; CHECK: %[[SRC:[[:alnum:]_.]+]] = ptrtoint i8* undef to i64
; CHECK: call void @sva_check_buffer(i64 %[[DST]], i64 0)
; CHECK: call void @sva_check_buffer(i64 %[[SRC]], i64 0)
; CHECK: call void @llvm.memcpy.element.unordered.atomic.p0i8.p0i8.i64(i8* align 4 undef, i8* align 4 undef, i64 0, i32 4)
; CHECK: ret void
    call void @llvm.memcpy.element.unordered.atomic.p0i8.p0i8.i64(i8* align 4 undef, i8* align 4 undef, i64 0, i32 4)
    ret void
}

define void @test_memmove() nounwind {
; CHECK-LABEL: @test_memmove

; CHECK: %[[DST:[[:alnum:]_.]+]] = ptrtoint i8* undef to i64
; CHECK: %[[SRC:[[:alnum:]_.]+]] = ptrtoint i8* undef to i64
; CHECK: call void @sva_check_buffer(i64 %[[DST]], i64 0)
; CHECK: call void @sva_check_buffer(i64 %[[SRC]], i64 0)
; CHECK: call void @llvm.memmove.p0i8.p0i8.i64(i8* undef, i8* undef, i64 0, i1 false)
; CHECK: ret void
    call void @llvm.memmove.p0i8.p0i8.i64(i8* undef, i8* undef, i64 0, i1 false)
    ret void
}

define void @test_atomic_memmove() nounwind {
; CHECK-LABEL: @test_atomic_memmove

; CHECK: %[[DST:[[:alnum:]_.]+]] = ptrtoint i8* undef to i64
; CHECK: %[[SRC:[[:alnum:]_.]+]] = ptrtoint i8* undef to i64
; CHECK: call void @sva_check_buffer(i64 %[[DST]], i64 0)
; CHECK: call void @sva_check_buffer(i64 %[[SRC]], i64 0)
; CHECK: call void @llvm.memmove.element.unordered.atomic.p0i8.p0i8.i64(i8* align 4 undef, i8* align 4 undef, i64 0, i32 4)
; CHECK: ret void
    call void @llvm.memmove.element.unordered.atomic.p0i8.p0i8.i64(i8* align 4 undef, i8* align 4 undef, i64 0, i32 4)
    ret void
}

define void @test_memset() nounwind {
; CHECK-LABEL: @test_memset

; CHECK: %[[DST:[[:alnum:]_.]+]] = ptrtoint i8* undef to i64
; CHECK: call void @sva_check_buffer(i64 %[[DST]], i64 0)
; CHECK: call void @llvm.memset.p0i8.i64(i8* undef, i8 0, i64 0, i1 false)
; CHECK: ret void
    call void @llvm.memset.p0i8.i64(i8* undef, i8 0, i64 0, i1 false)
    ret void
}

define void @test_atomic_memset() nounwind {
; CHECK-LABEL: @test_atomic_memset

; CHECK: %[[DST:[[:alnum:]_.]+]] = ptrtoint i8* undef to i64
; CHECK: call void @sva_check_buffer(i64 %[[DST]], i64 0)
; CHECK: call void @llvm.memset.element.unordered.atomic.p0i8.i64(i8* align 4 undef, i8 0, i64 0, i32 4)
; CHECK: ret void
    call void @llvm.memset.element.unordered.atomic.p0i8.i64(i8* align 4 undef, i8 0, i64 0, i32 4)
    ret void
}
