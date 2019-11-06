;;;-----------------------------------------------------------------------------
;;; SVA CFI MPX Bounds Check Test
;;;-----------------------------------------------------------------------------
;;; This test checks that SVA's CFI pass properly uses MPX bounds checks.
;;;-----------------------------------------------------------------------------

; RUN: opt -sva-cfi --enable-mpx-cfi -S < %s | FileCheck %s

target datalayout = "e-m:e-i1:8:8-i8:8:8-i16:16:16-i32:32:32-i64:64:64-p:64:64:64-n8:16:32:64"
target triple = "x86_64-unknown-linux-gnu"

declare void()* @make_fn_ptr() nounwind

declare i8* @make_ptr() nounwind

define void @test_call() nounwind noreturn {
; CHECK-LABEL: @test_call

; CHECK: %[[INT_PTR:[[:alnum:]_.]+]] = ptrtoint void ()* %[[PTR:[[:alnum:]_.]+]] to i64
; CHECK: %[[ALIGNED:[[:alnum:]_.]+]] = and i64 %[[INT_PTR]], -32
; CHECK: %[[TYPE_ERASED_PTR:[[:alnum:]_.]+]] = inttoptr i64 %[[ALIGNED]] to i8*
; CHECK-NEXT: call void @llvm.x86.bndcl(i8* %[[TYPE_ERASED_PTR]], i32 1)
; CHECK: %[[ALIGNED_PTR:[[:alnum:]_.]+]] = inttoptr i64 %[[ALIGNED]] to void ()*
; CHECK: %[[HAS_LABEL:[[:alnum:]_.]+]] = icmp eq i32 -98693133, %{{[[:alnum:]_.]+}}
; CHECK: br i1 %[[HAS_LABEL]], label %{{[[:alnum:]_.]+}}, label %cfi_check_fail
; CHECK: call void %[[ALIGNED_PTR]]
; CHECK-NEXT: unreachable
    %1 = call void()* @make_fn_ptr() nounwind
    call void %1() nounwind noreturn
    unreachable

; CHECK-LABEL: cfi_check_fail:
; CHECK-NEXT: call void @abort()
; CHECK-NEXT: unreachable
}

define void @test_indirect_branch() nounwind noreturn {
; CHECK-LABEL: @test_indirect_branch

; CHECK: %[[INT_PTR:[[:alnum:]_.]+]] = ptrtoint i8* %[[PTR:[[:alnum:]_.]+]] to i64
; CHECK: %[[ALIGNED:[[:alnum:]_.]+]] = and i64 %[[INT_PTR]], -32
; CHECK: %[[TYPE_ERASED_PTR:[[:alnum:]_.]+]] = inttoptr i64 %[[ALIGNED]] to i8*
; CHECK-NEXT: call void @llvm.x86.bndcl(i8* %[[TYPE_ERASED_PTR]], i32 1)
; CHECK: %[[ALIGNED_PTR:[[:alnum:]_.]+]] = inttoptr i64 %[[ALIGNED]] to i8*
; CHECK: %[[HAS_LABEL:[[:alnum:]_.]+]] = icmp eq i32 -98693133, %{{[[:alnum:]_.]+}}
; CHECK: br i1 %[[HAS_LABEL]], label %{{[[:alnum:]_.]+}}, label %cfi_check_fail
; CHECK: indirectbr i8* %[[ALIGNED_PTR]]
    %1 = call i8* @make_ptr() nounwind
    indirectbr i8* %1, [label %d1, label %d2]

d1:
    unreachable

d2:
    unreachable

; CHECK-LABEL: cfi_check_fail:
; CHECK-NEXT: call void @abort()
; CHECK-NEXT: unreachable
}

define void @test_return_void() nounwind {
; CHECK-LABEL: @test_return_void

; CHECK: %[[INT_PTR:[[:alnum:]_.]+]] = ptrtoint i8* %[[PTR:[[:alnum:]_.]+]] to i64
; CHECK: %[[ALIGNED:[[:alnum:]_.]+]] = and i64 %[[INT_PTR]], -32
; CHECK: %[[TYPE_ERASED_PTR:[[:alnum:]_.]+]] = inttoptr i64 %[[ALIGNED]] to i8*
; CHECK-NEXT: call void @llvm.x86.bndcl(i8* %[[TYPE_ERASED_PTR]], i32 1)
; CHECK: %[[ALIGNED_PTR:[[:alnum:]_.]+]] = inttoptr i64 %[[ALIGNED]] to i8*
; CHECK: %[[HAS_LABEL:[[:alnum:]_.]+]] = icmp eq i32 -98693133, %{{[[:alnum:]_.]+}}
; CHECK: br i1 %[[HAS_LABEL]], label %{{[[:alnum:]_.]+}}, label %cfi_check_fail
; CHECK: call void @llvm.setreturnaddress(i8* %[[ALIGNED_PTR]])
; CHECK: ret void
    ret void

; CHECK-LABEL: cfi_check_fail:
; CHECK-NEXT: call void @abort()
; CHECK-NEXT: unreachable
}

define i32 @test_return_value() nounwind {
; CHECK-LABEL: @test_return_value

; CHECK: %[[INT_PTR:[[:alnum:]_.]+]] = ptrtoint i8* %[[PTR:[[:alnum:]_.]+]] to i64
; CHECK: %[[ALIGNED:[[:alnum:]_.]+]] = and i64 %[[INT_PTR]], -32
; CHECK: %[[TYPE_ERASED_PTR:[[:alnum:]_.]+]] = inttoptr i64 %[[ALIGNED]] to i8*
; CHECK-NEXT: call void @llvm.x86.bndcl(i8* %[[TYPE_ERASED_PTR]], i32 1)
; CHECK: %[[ALIGNED_PTR:[[:alnum:]_.]+]] = inttoptr i64 %[[ALIGNED]] to i8*
; CHECK: %[[HAS_LABEL:[[:alnum:]_.]+]] = icmp eq i32 -98693133, %{{[[:alnum:]_.]+}}
; CHECK: br i1 %[[HAS_LABEL]], label %{{[[:alnum:]_.]+}}, label %cfi_check_fail
; CHECK: call void @llvm.setreturnaddress(i8* %[[ALIGNED_PTR]])
; CHECK: ret i32 0
    ret i32 0

; CHECK-LABEL: cfi_check_fail:
; CHECK-NEXT: call void @abort()
; CHECK-NEXT: unreachable
}
