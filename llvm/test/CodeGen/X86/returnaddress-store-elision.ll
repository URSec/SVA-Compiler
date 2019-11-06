;;;-----------------------------------------------------------------------------
;;; X86 Return Address Store Elision Codegen Test
;;;-----------------------------------------------------------------------------
;;; This test checks that the code generator can correctly pass the argument of
;;; the @llvm.setreturnaddress intrinsic to a jump return without spilling and
;;; reloading it.
;;;-----------------------------------------------------------------------------

; RUN: llc < %s -mtriple=x86_64-- -jump-return | FileCheck %s

; Also test fast isel
; RUN: llc < %s -mtriple=x86_64-- -fast-isel -jump-return | FileCheck %s

declare i8* @llvm.returnaddress(i32)
declare void @llvm.setreturnaddress(i8*)

define void @test_void() nounwind uwtable {
; CHECK-LABEL: test_void

; CHECK:      popq %[[REG:[[:alnum:]]+]]
; CHECK:      andq $-32, %[[REG]]
; CHECK-NOT:  movq {{.*}}, (%rsp)
; CHECK-NOT:  movq (%rsp), {{.*}}
; CHECK:      jmpq *%[[REG]]

  %retaddr = call i8* @llvm.returnaddress(i32 0)
  %retaddr.int = ptrtoint i8* %retaddr to i64
  %retaddr.masked = and i64 %retaddr.int, -32
  %retaddr.masked.ptr = inttoptr i64 %retaddr.masked to i8*
  call void @llvm.setreturnaddress(i8* %retaddr.masked.ptr)
  ret void
}
; CHECK-NEXT: func_end

define i32 @test_int() nounwind uwtable {
; CHECK-LABEL: test_int

; CHECK:      popq %[[REG:[[:alnum:]]+]]
; CHECK:      andq $-32, %[[REG]]
; CHECK-NOT:  movq {{.*}}, (%rsp)
; CHECK-NOT:  movq (%rsp), {{.*}}
; CHECK:      jmpq *%[[REG]]

  %retaddr = call i8* @llvm.returnaddress(i32 0)
  %retaddr.int = ptrtoint i8* %retaddr to i64
  %retaddr.masked = and i64 %retaddr.int, -32
  %retaddr.masked.ptr = inttoptr i64 %retaddr.masked to i8*
  call void @llvm.setreturnaddress(i8* %retaddr.masked.ptr)
  ret i32 0
}
; CHECK-NEXT: func_end
