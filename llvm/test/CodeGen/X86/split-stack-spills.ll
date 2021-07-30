;;;-----------------------------------------------------------------------------
;;; X86 Split Stack Register Spill Codegen Test
;;;-----------------------------------------------------------------------------
;;; This test checks that the code generator generates register spills using the
;;; data stack pointer.
;;;-----------------------------------------------------------------------------

; RUN: llc < %s -mtriple=x86_64-- --frame-pointer=none --split-stack | FileCheck --enable-var-scope %s

declare i32 @ex(i32, i32) nounwind;

; CHECK-LABEL: test
define void @test() nounwind uwtable noredzone {
  ; CHECK: movl %{{[[:alnum:]]+}}, [[OFFSET:([[:digit:]]+|0x[[:xdigit:]]+)?]](%r15) # 4-byte Spill
  ; CHECK: movl [[OFFSET]](%r15), %{{[[:alnum:]]+}} # 4-byte Reload

  %val.0 = call i32 @ex(i32 0, i32 0)
  %val.1 = call i32 @ex(i32 0, i32 0)
  %val.2 = call i32 @ex(i32 0, i32 0)
  %val.3 = call i32 @ex(i32 0, i32 0)
  %val.4 = call i32 @ex(i32 0, i32 0)
  %val.5 = call i32 @ex(i32 0, i32 0)
  %val.6 = call i32 @ex(i32 0, i32 0)
  %val.7 = call i32 @ex(i32 %val.0, i32 %val.1)
  %val.8 = call i32 @ex(i32 %val.2, i32 %val.3)
  %val.9 = call i32 @ex(i32 %val.4, i32 %val.5)

  ret void
}
