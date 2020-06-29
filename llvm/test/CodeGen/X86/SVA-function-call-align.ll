;;;-----------------------------------------------------------------------------
;;; SVA Function Alignment Test
;;;-----------------------------------------------------------------------------
;;; This test checks that the code generator produces the correct alignment
;;; directives for functions when in SVA mode.
;;;-----------------------------------------------------------------------------

; RUN: llc < %s -mtriple=x86_64-- -sva | FileCheck %s

; CHECK: .bundle_align_mode 5

declare void @nop() nounwind

define void @test() nounwind uwtable {
; CHECK: .bundle_lock align_to_end
; CHECK-NEXT: callq nop
; CHECK-NEXT: .bundle_unlock
  call void @nop()
  ret void
}
