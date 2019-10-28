;;;-----------------------------------------------------------------------------
;;; X86 return-with-jump Codegen Test
;;;-----------------------------------------------------------------------------
;;; This test checks that the code generator can correctly generate instruction
;;; sequences to return using an indirect jump.
;;;-----------------------------------------------------------------------------

; RUN: llc < %s -mtriple=x86_64-- -jump-return | FileCheck --check-prefixes=CHECK,CHECK64 --implicit-check-not retq %s
; RUN: llc < %s -mtriple=x86_64---gnux32 -jump-return | FileCheck --check-prefixes=CHECK,CHECKX32 --implicit-check-not retq %s
; RUN: llc < %s -mtriple=i386-- -jump-return | FileCheck --check-prefixes=CHECK,CHECK32 --implicit-check-not retl %s

; Also test fast isel
; RUN: llc < %s -mtriple=x86_64-- -fast-isel -jump-return | FileCheck --check-prefixes=CHECK,CHECK64 --implicit-check-not retq %s
; RUN: llc < %s -mtriple=x86_64--gnux32 -fast-isel -jump-return | FileCheck --check-prefixes=CHECK,CHECKX32 --implicit-check-not retq %s
; RUN: llc < %s -mtriple=i386-- -fast-isel -jump-return | FileCheck --check-prefixes=CHECK,CHECK32 --implicit-check-not retl %s

define void @test_void() nounwind uwtable {
; CHECK-LABEL: test_void

; CHECK64: popq %[[REG:[[:alnum:]]+]]
; CHECK64-NEXT: jmpq *%[[REG]]

; CHECKX32: popq %[[REG:[[:alnum:]]+]]
; CHECKX32-NEXT: jmpq *%[[REG]]

; CHECK32: popl %[[REG:[[:alnum:]]+]]
; CHECK32-NEXT: jmpl *%[[REG]]

; CHECK-NEXT: func_end

  ret void
}

define i32 @test_int() nounwind uwtable {
; CHECK-LABEL: test_int

; CHECK64: popq %[[REG:[[:alnum:]]+]]
; CHECK64: jmpq *%[[REG]]

; CHECKX32: popq %[[REG:[[:alnum:]]+]]
; CHECKX32: jmpq *%[[REG]]

; CHECK32: popl %[[REG:[[:alnum:]]+]]
; CHECK32: jmpl *%[[REG]]

; CHECK-NEXT: func_end

  ret i32 0
}

define double @test_float() nounwind uwtable {
; CHECK-LABEL: test_float

; CHECK64: popq %[[REG:[[:alnum:]]+]]
; CHECK64: jmpq *%[[REG]]

; CHECKX32: popq %[[REG:[[:alnum:]]+]]
; CHECKX32: jmpq *%[[REG]]

;; Use of the floating point stack is considered to have "unmodeled side
;; effects", which breaks the pop optimization. It's too much of a pain to fix
;; for an architecture we don't really care about anyway.
; CHECK32: movl (%esp), %[[REG:[[:alnum:]]+]]
; CHECK32: popl %{{[[:alnum:]]+}}
; CHECK32: jmpl *%[[REG]]

; CHECK-NEXT: func_end

  ret double 0.0
}

;;
;; The stdcall calling convention expects the callee to pop arguments off the
;; stack on 32-bit x86. Make sure jump returns handle this correctly.
;;
define x86_stdcallcc i32 @test_stdcall(i32, i32) nounwind uwtable {
; CHECK-LABEL: test_stdcall

  %3 = add i32 %0, %1

; CHECK64: popq %[[REG:[[:alnum:]]+]]
; CHECK64: jmpq *%[[REG]]

; CHECKX32: popq %[[REG:[[:alnum:]]+]]
; CHECKX32: jmpq *%[[REG]]

; CHECK32: popl %[[REG:[[:alnum:]]+]]
; CHECK32: addl $8, %esp
; CHECK32: jmpl *%[[REG]]

; CHECK-NEXT: func_end

  ret i32 %3
}
