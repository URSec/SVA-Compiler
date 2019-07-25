;;;-----------------------------------------------------------------------------
;;; SVA CFI Return Test
;;;-----------------------------------------------------------------------------
;;; This test checks that SVA's CFI pass properly instruments returns.
;;;-----------------------------------------------------------------------------

; RUN: opt -sva-cfi -S < %s | FileCheck %s

target datalayout = "e-m:e-i1:8:8-i8:8:8-i16:16:16-i32:32:32-i64:64:64-p:64:64:64-n8:16:32:64"
target triple = "x86_64-unknown-linux-gnu"

define void @test_return_void() nounwind {
; CHECK-LABEL: @test_return_void

; CHECK: %[[ALIGNED:[[:alnum:]_.]+]] = and i64 %{{[[:alnum:]_.]+}}, -32
; CHECK: %[[INT_MASKED:[[:alnum:]_.]+]] = or i64 %[[ALIGNED]], -2147483648
; CHECK: %[[MASKED:[[:alnum:]_.]+]] = inttoptr i64 %[[INT_MASKED]] to i8*
; CHECK: %[[HAS_LABEL:[[:alnum:]_.]+]] = icmp eq i32 -98693133, %{{[[:alnum:]_.]+}}
; CHECK: br i1 %[[HAS_LABEL]], label %{{[[:alnum:]_.]+}}, label %cfi_check_fail
; CHECK: %[[TYPED_MASKED:[[:alnum:]_.]+]] = ptrtoint i8* %[[MASKED]] to i64
; CHECK: store i64 %[[TYPED_MASKED]], i64* %{{[[:alnum:]_.]+}}
; CHECK: ret void
    ret void

; CHECK-LABEL: cfi_check_fail:
; CHECK-NEXT: call void @abort()
; CHECK-NEXT: unreachable
}

define i32 @test_return_value() nounwind {
; CHECK-LABEL: @test_return_value

; CHECK: %[[ALIGNED:[[:alnum:]_.]+]] = and i64 %{{[[:alnum:]_.]+}}, -32
; CHECK: %[[INT_MASKED:[[:alnum:]_.]+]] = or i64 %[[ALIGNED]], -2147483648
; CHECK: %[[MASKED:[[:alnum:]_.]+]] = inttoptr i64 %[[INT_MASKED]] to i8*
; CHECK: %[[HAS_LABEL:[[:alnum:]_.]+]] = icmp eq i32 -98693133, %{{[[:alnum:]_.]+}}
; CHECK: br i1 %[[HAS_LABEL]], label %{{[[:alnum:]_.]+}}, label %cfi_check_fail
; CHECK: %[[TYPED_MASKED:[[:alnum:]_.]+]] = ptrtoint i8* %[[MASKED]] to i64
; CHECK: store i64 %[[TYPED_MASKED]], i64* %{{[[:alnum:]_.]+}}
; CHECK: ret i32 0
    ret i32 0

; CHECK-LABEL: cfi_check_fail:
; CHECK-NEXT: call void @abort()
; CHECK-NEXT: unreachable
}
