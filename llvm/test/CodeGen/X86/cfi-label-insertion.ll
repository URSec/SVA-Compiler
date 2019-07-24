;;;-----------------------------------------------------------------------------
;;; CFI Label Insertion Test
;;;-----------------------------------------------------------------------------
;;; This test checks that the CFI label insertion pass inserts CFI labels at the
;;; correct locations.
;;;-----------------------------------------------------------------------------

; RUN: llc < %s -mtriple=x86_64-- -sva | FileCheck %s

declare void @not_defined_here() nounwind

define void @test_extern_fn() nounwind uwtable {
; CHECK-LABEL: test_extern_fn:
; CHECK: endbr64

  ret void
}

define private void @test_called_indirectly_private_fn() nounwind uwtable {
; CHECK-LABEL: test_called_indirectly_private_fn:
; CHECK: endbr64
  ret void
}

define internal void @test_called_indirectly_internal_fn() nounwind uwtable {
; CHECK-LABEL: test_called_indirectly_internal_fn:
; CHECK: endbr64
  ret void
}

; Prevent infering unnamed_addr on preceeding functions
define void()* @dummy(i8) nounwind uwtable {
  %2 = trunc i8 %0 to i1
  %3 = select i1 %2, void()* @test_called_indirectly_private_fn, void()* @test_called_indirectly_internal_fn
  ret void()* %3
}

define void @test_call() nounwind uwtable {
; CHECK-LABEL: test_call:

; CHECK: callq not_defined_here
; CHECK-NEXT: endbr64
  call void @not_defined_here()
  ret void
}

define i32 @test_indirectbr(i8) nounwind uwtable {
; CHECK-LABEL: test_indirectbr:

  %2 = trunc i8 %0 to i1
  %3 = select i1 %2, i8* blockaddress(@test_indirectbr, %case1), i8* blockaddress(@test_indirectbr, %case2)
  indirectbr i8* %3, [label %case1, label %case2]

case1:
; CHECK-LABEL: case1
; CHECK-NEXT: endbr64

  ret i32 17

case2:
; CHECK-LABEL: case2
; CHECK-NEXT: endbr64
  ret i32 42
}

define internal void @test_no_cfi_label_internal() unnamed_addr nounwind uwtable {
; CHECK-LABEL: test_no_cfi_label_internal:
; CHECK-NOT: endbr64

  ret void
}

define private void @test_no_cfi_label_private() unnamed_addr nounwind uwtable {
; CHECK-LABEL: test_no_cfi_label_private:
; CHECK-NOT: endbr64

  ret void
}
