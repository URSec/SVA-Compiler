;;;-----------------------------------------------------------------------------
;;; SVA CFI MPX Bounds Check Test
;;;-----------------------------------------------------------------------------
;;; This test checks that SVA's CFI pass properly uses MPX bounds checks.
;;;-----------------------------------------------------------------------------

; RUN: opt -sva-cfi --enable-mpx-cfi -S < %s | FileCheck %s

target datalayout = "e-m:e-i1:8:8-i8:8:8-i16:16:16-i32:32:32-i64:64:64-p:64:64:64-n8:16:32:64"
target triple = "x86_64-unknown-linux-gnu"

define void @test_call() nounwind noreturn {
; CHECK-LABEL: @test_call

; CHECK: %[[TYPE_ERASED_PTR:[[:alnum:]_.]+]] = bitcast void ()* %[[PTR:[[:alnum:]_.]+]] to i8*
; CHECK-NEXT: call void @llvm.x86.bndcl(i8* %[[TYPE_ERASED_PTR]], i32 1)
; CHECK: %[[HAS_LABEL:[[:alnum:]_.]+]] = icmp eq i32 -762721911, %{{[[:alnum:]_.]+}}
; CHECK: br i1 %[[HAS_LABEL]], label %{{[[:alnum:]_.]+}}, label %cfi_check_fail
; CHECK: call void %[[PTR]]
; CHECK-NEXT: unreachable
    %1 = inttoptr i64 0 to void()*
    call void %1() nounwind noreturn
    unreachable

; CHECK-LABEL: cfi_check_fail:
; CHECK-NEXT: call void @abort()
; CHECK-NEXT: unreachable
}

define void @test_indirect_branch() nounwind noreturn {
; CHECK-LABEL: @test_indirect_branch

; CHECK: %[[TYPE_ERASED_PTR:[[:alnum:]_.]+]] = bitcast i8* %[[PTR:[[:alnum:]_.]+]] to i8*
; CHECK-NEXT: call void @llvm.x86.bndcl(i8* %[[TYPE_ERASED_PTR]], i32 1)
; CHECK: %[[HAS_LABEL:[[:alnum:]_.]+]] = icmp eq i32 -762721911, %{{[[:alnum:]_.]+}}
; CHECK: br i1 %[[HAS_LABEL]], label %{{[[:alnum:]_.]+}}, label %cfi_check_fail
; CHECK: indirectbr i8* %[[PTR]]
    %1 = inttoptr i64 0 to i8*
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

; CHECK: %[[TYPE_ERASED_PTR:[[:alnum:]_.]+]] = bitcast i8* %[[PTR:[[:alnum:]_.]+]] to i8*
; CHECK-NEXT: call void @llvm.x86.bndcl(i8* %[[TYPE_ERASED_PTR]], i32 1)
; CHECK: %[[HAS_LABEL:[[:alnum:]_.]+]] = icmp eq i32 -762721911, %{{[[:alnum:]_.]+}}
; CHECK: br i1 %[[HAS_LABEL]], label %{{[[:alnum:]_.]+}}, label %cfi_check_fail
; CHECK: %[[RET_ADDR:[[:alnum:]_.]+]] = ptrtoint i8* %[[PTR]] to i64
; CHECK: store i64 %[[RET_ADDR]], i64* %{{[[:alnum:]_.]+}}
; CHECK: ret void
    ret void

; CHECK-LABEL: cfi_check_fail:
; CHECK-NEXT: call void @abort()
; CHECK-NEXT: unreachable
}

define i32 @test_return_value() nounwind {
; CHECK-LABEL: @test_return_value

; CHECK: %[[TYPE_ERASED_PTR:[[:alnum:]_.]+]] = bitcast i8* %[[PTR:[[:alnum:]_.]+]] to i8*
; CHECK-NEXT: call void @llvm.x86.bndcl(i8* %[[TYPE_ERASED_PTR]], i32 1)
; CHECK: %[[HAS_LABEL:[[:alnum:]_.]+]] = icmp eq i32 -762721911, %{{[[:alnum:]_.]+}}
; CHECK: br i1 %[[HAS_LABEL]], label %{{[[:alnum:]_.]+}}, label %cfi_check_fail
; CHECK: %[[RET_ADDR:[[:alnum:]_.]+]] = ptrtoint i8* %[[PTR]] to i64
; CHECK: store i64 %[[RET_ADDR]], i64* %{{[[:alnum:]_.]+}}
; CHECK: ret i32 0
    ret i32 0

; CHECK-LABEL: cfi_check_fail:
; CHECK-NEXT: call void @abort()
; CHECK-NEXT: unreachable
}
