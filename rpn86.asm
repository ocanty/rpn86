; The MIT License

; Copyright (c) ocanty <git@ocanty.com>

; Permission is hereby granted, free of charge, to any person obtaining a copy
; of this software and associated documentation files (the "Software"), to deal
; in the Software without restriction, including without limitation the rights
; to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
; copies of the Software, and to permit persons to whom the Software is
; furnished to do so, subject to the following conditions:

; The above copyright notice and this permission notice shall be included in
; all copies or substantial portions of the Software.

; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
; IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
; FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
; AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
; LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
; OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
; THE SOFTWARE.

; Build with: 
; yasm -f elf64 rpn86.asm -o rpn86.o
; gcc -m64 rpn86.o -o rpn86 -fno-pie -fno-plt -no-pie;
; ./rpn86

    BITS 64
    global main
    extern printf
    extern scanf
    extern exit

; Util - Begin
    section .data
str_fmt_str:
    db "%s", 0

str_fmt_uint:
    db "%u", 0

str_fmt_int:
    db "%i", 0

    section .text
die:
    ; Kill the program with return value -1
    mov rdi, -1
    call exit
    ret                             ; Not like this is needed

print:
    ; Use printf (with ABI stack setup)
    xor rax, rax                    ; not using floats / xmm registers
    sub rsp, 8                      ; Stack on C API calls needs to be 16bit aligned
    call printf
    add rsp, 8
    ret

print_die:
    call print
    call die
    ret

; Util - End

; RPN Stack Implementation - Begin

rpn_stack_max_elements: equ  1024

rpn_stack_sz:           equ  rpn_stack_max_elements*8  ; Total stack size in bytes

    section .bss

rpn_stack:      
    resb rpn_stack_sz

rpn_stack_n:    
    resq 0             ; Stack ptr
                    
    section .data
str_rpn_stack_overflow:
    db "RPN stack overflow: sp - %u", 10, 0

str_rpn_stack_underflow:
    db "RPN stack overflow: sp - %u", 10, 0


    section .text
rpn_stack_push:
    ; Pushes a value onto the RPN stack
    ; [in] rdi  - value
    ; [mangles] rdi, rax    
    ; Get stack ptr, if it's at its max size -> error

    mov rax, [rpn_stack_n]          ; Get num of stack elements 
    cmp rax, rpn_stack_sz           ; Compare to stack size
    jge rpn_stack_push.fail         ; stack overflow if equal or greater
    jmp rpn_stack_push.good         ; normally its good

    .fail:
        mov rdi, str_rpn_stack_overflow
        mov rsi, rax
        call print
        ret

    .good:
        mov [rpn_stack+rax], rdi    ; store value at stack ptr
        add rax, 8                  ; increment stack ptr
        mov [rpn_stack_n], rax      ; store and return
        ret

 rpn_stack_pop:
    ; Removes a value on the RPN stack
    ; [out] rax - value
    ; [mangles] rdi, rax, rbx    
    ; Get stack ptr, if it's at its lowest size -> error
    mov rax, [rpn_stack_n]
    cmp rax, 0
    jle rpn_stack_pop.fail
    jmp rpn_stack_pop.good

    .fail:
        mov rdi, str_rpn_stack_underflow
        mov rsi, rax
        call print
        ret
    
    .good:  
        mov rbx, [rpn_stack+rax]    ; read val on stack
        sub rax, 8                  ; decrement stack ptr
        mov [rpn_stack_n], rax      ; store stack ptr
        xchg rax, rbx               ; set return = rax
        ret

rpn_evaluate:
    ; Evaluate an RPN expression
    ; Will exit program on error
    ; [in] rdi - string
    ; [out] rax - value
    .str_ptr: equ 0                 ; offset for string pointer
    enter 8, 0                      ; stack space for string pointer
    
    mov qword[rsp+.str_ptr], rdi    ; load string pointer into offset ptr
    jmp .process_token

    .process_token:
        lea rax, [rsp + .str_ptr]   ; calculate address of str ptr
        mov al, [rax]               ; read the character at it

        ; our plan is to find a token, then advance the string pointer
        ; but first we gotta check if we've hit anything unusual

        cmp al, 0x00
        je .calculate_result

        cmp al,
        

    .calculate_result:


    leave
    ret



; RPN Stack Implementation - End

; Entrypoint - Begin

    section .data
str_ask_for_expr:   
    db "Enter a Reverse Polish notation expression: ", 10, 0

    section .bss
str_expr:
    resb 1024

str_expr_overflow_cookie:
    resq 0

    section .text
main:
    enter 1024, 0                    ; stack space for expression string

    mov rdi, str_ask_for_expr
    call print

    ; We need to generate a secret/cookie that 
    ; is placed after the expr string
    ; to make sure scanf doesn't overflow our buffer
    rdrand rax
    mov [str_expr_overflow_cookie], rax

    mov rdi, str_fmt_str
    lea rsi, [str_expr]             ; put the string they supply into a stack var
    xor rax, rax                    ; not using floats
    add rsp, 16                     ; 16-bit alignment for C ABI
    call scanf
    sub rsp, 16

    pop rax                         ; cookie now in rax
    mov rbx, [str_expr_overflow_cookie]
    cmp rax, rbx
    jne die                         ; die if they aren't the same -> an overflow occured

    lea rdi, [str_expr]
    call rpn_evaluate
    
    leave
    ret
; Entrypoint - End

