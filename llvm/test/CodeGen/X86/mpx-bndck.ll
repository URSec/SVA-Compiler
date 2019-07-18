;;;-----------------------------------------------------------------------------
;;; MPX Intrinsics Codegen Test
;;;-----------------------------------------------------------------------------
;;; This test checks that the code generator produces the correct instructions
;;; for MPX intrinsics.
;;;-----------------------------------------------------------------------------

; RUN: llc < %s -mtriple=x86_64-- -mattr=+mpx | FileCheck %s

declare void @llvm.x86.bndcl(i8* nocapture, i32 immarg) nounwind
declare void @llvm.x86.bndcu(i8* nocapture, i32 immarg) nounwind
declare void @llvm.x86.bndcn(i8* nocapture, i32 immarg) nounwind

define void @test_bndcl() nounwind uwtable {
; CHECK-LABEL: test_bndcl

; CHECK: bndcl %{{r[[:alnum:]]+}}, %bnd0
  call void @llvm.x86.bndcl(i8* null, i32 0)
; CHECK-NEXT: bndcl %{{r[[:alnum:]]+}}, %bnd1
  call void @llvm.x86.bndcl(i8* null, i32 1)
; CHECK-NEXT: bndcl %{{r[[:alnum:]]+}}, %bnd2
  call void @llvm.x86.bndcl(i8* null, i32 2)
; CHECK-NEXT: bndcl %{{r[[:alnum:]]+}}, %bnd3
  call void @llvm.x86.bndcl(i8* null, i32 3)
  ret void
}

define void @test_bndcu() nounwind uwtable {
; CHECK-LABEL: test_bndcu

; CHECK: bndcu %{{r[[:alnum:]]+}}, %bnd1
  call void @llvm.x86.bndcu(i8* null, i32 1)
; CHECK-NEXT: bndcu %{{r[[:alnum:]]+}}, %bnd0
  call void @llvm.x86.bndcu(i8* null, i32 0)
; CHECK-NEXT: bndcu %{{r[[:alnum:]]+}}, %bnd3
  call void @llvm.x86.bndcu(i8* null, i32 3)
; CHECK-NEXT: bndcu %{{r[[:alnum:]]+}}, %bnd2
  call void @llvm.x86.bndcu(i8* null, i32 2)
  ret void
}

define void @test_bndcn() nounwind uwtable {
; CHECK-LABEL: test_bndcn

; CHECK: bndcn %{{r[[:alnum:]]+}}, %bnd3
  call void @llvm.x86.bndcn(i8* null, i32 3)
; CHECK-NEXT: bndcn %{{r[[:alnum:]]+}}, %bnd1
  call void @llvm.x86.bndcn(i8* null, i32 1)
; CHECK-NEXT: bndcn %{{r[[:alnum:]]+}}, %bnd2
  call void @llvm.x86.bndcn(i8* null, i32 2)
; CHECK-NEXT: bndcn %{{r[[:alnum:]]+}}, %bnd0
  call void @llvm.x86.bndcn(i8* null, i32 0)
  ret void
}
