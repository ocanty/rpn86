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
    extern read
    extern strtol
    extern exit

; Util - Begin
    section .data
str_fmt_str:
    db "%s", 10, 0

str_fmt_char:
    db "%c", 10, 0

str_fmt_uint:
    db "%u", 10, 0

str_fmt_int:
    db "%i", 10, 0

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

; Util - End

; RPN Stack Implementation - Begin

    section .data
rpn_stack_max_elements: equ  1024

rpn_stack_sz:           equ  8192 ; Total stack size in bytes

    section .bss
rpn_stack:      
    resb rpn_stack_sz

rpn_stack_n:    
    dq 0             ; Stack ptr
                    
    section .data
str_rpn_stack_overflow:
    db "RPN stack overflow: sp - %i", 10, 0

str_rpn_stack_underflow:
    db "RPN stack underflow: sp - %i", 10, 0

pushed:
    db "pushed %i", 10, 0

popped:
    db "popped %i", 10, 0

    section .text
rpn_stack_push:
    ; Pushes a value onto the RPN stack
    ; [in] rdi  - value
    ; [mangles] rdi, rax    
    ; Get stack ptr, if it's at its max size -> error
    ; mov rdi, pushed
    ; call print

    ; push rdi
    ; lea rdi, [pushed]
    ; mov rsi, rax
    ; call print
    ; pop rdi

    mov rax, [rpn_stack_n]          ; Get stack ptr
    cmp rax, rpn_stack_sz           ; Compare to stack size
    jge rpn_stack_push.fail         ; stack overflow if equal or greater
    jmp rpn_stack_push.good         ; normally its good

    .fail:
        mov rdi, str_rpn_stack_overflow
        mov rsi, rpn_stack_sz
        call print
        jmp die
        ret

    .good:
        lea rbx, [rpn_stack+rax]
        mov [rbx], rdi              ; store value at stack ptr
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
        jmp die
        ret
    
    .good:  
        sub rax, 8                  ; decrement stack ptr
        mov [rpn_stack_n], rax      ; store stack ptr

        lea rbx, [rpn_stack+rax]    ; read val on stack
        mov rax, [rbx]  

        ; push rax 
        ; lea rdi, [popped]
        ; mov rsi, rax
        ; call print
        ; pop rax
        ret

    section .data
str_test:
    db "testn.", 10, 0
str_invalid_expr:
    db "Invalid expression.", 10, 0
str_evaluating:
    db "Evaluating: %s", 10, 0
str_got_result: 
    db "Result is %i!", 10, 0
str_got_space:
    db "Got space", 10, 0

    section .text
rpn_evaluate:
    ; Evaluate an RPN expression
    ; Will exit program on error
    ; [in] rdi - string addr
    ; [out] rax - value
    .str_ptr: equ 0                 ; offset for string pointer
    enter 16, 0                     ; stack space for string pointer

    mov [rsp + .str_ptr], rdi       ; load string pointer into offset ptr

    jmp .process_token

    .increment_str_ptr_and_process_token:
        mov rbx, [rsp + .str_ptr]
        inc rbx 
        mov [rsp + .str_ptr], rbx
        jmp .process_token

    .process_token:
        mov rbx, [rsp + .str_ptr] 
        xor rax, rax
        mov al, byte [rbx]
        
        cmp al, 0
        je .calculate_result

        cmp al, ' '
        je .got_space

        cmp al, 10      ; newline can be used as a delimiter, too
        je .got_space   ; just use space handler

        cmp al, '+'                 ; check for operands
        je .got_plus
        cmp al, '-'          
        je .got_minus 
        cmp al, '*'          
        je .got_multiply
        cmp al, '/'            
        je .got_divide

        jmp .check_number           ; not operands, check for numbers

        .got_plus:
            ; operand 2
            call rpn_stack_pop
            push rax

            ; operand 1
            call rpn_stack_pop
            pop rbx
            
            add rax, rbx
            mov rdi, rax
            call rpn_stack_push

            jmp .increment_str_ptr_and_process_token

        .got_minus:
            ; operand 2
            call rpn_stack_pop
            push rax

            ; operand 1
            call rpn_stack_pop
            pop rbx
            
            sub rax, rbx
            mov rdi, rax
            call rpn_stack_push

            jmp .increment_str_ptr_and_process_token

        .got_multiply:
            ; operand 2
            call rpn_stack_pop
            push rax

            ; operand 1
            call rpn_stack_pop
            pop rbx
            xor rdx, rdx            ; clear dividend
            mul rbx
            mov rdi, rax
            call rpn_stack_push

            jmp .increment_str_ptr_and_process_token


        .got_divide:
            ; operand 2
            call rpn_stack_pop
            push rax

            ; operand 1
            call rpn_stack_pop
            pop rbx
            xor rdx, rdx            ; clear dividend
            div rbx
            mov rdi, rax
            call rpn_stack_push

            jmp .increment_str_ptr_and_process_token

        .check_number:              ; check if digit is greater/equal to 0
            cmp al, '0'
            jge .maybe_number
            jmp .got_invalid
; 
        .maybe_number:              ; check if digit less than/equal to 9
            cmp al, '9'
            jle .got_number
            jmp .got_invalid

        .got_number:                 ; extract number and push to RPN stack
            ; long int strtol (const char* str, char** endptr, int base);
            mov rdi, [rsp + .str_ptr]
            lea rsi, [rsp + .str_ptr]   
            mov rdx, 10
            ; add rsp, 16            ; 16-bit stack alignment, not needed here
            call strtol 
            ; sub rsp, 16

            mov rdi, rax
            call rpn_stack_push

            jmp .process_token
        
        .got_invalid:
            mov rdi, str_invalid_expr
            call print
            jmp die

        .got_space:
            mov rdi, [rsp + .str_ptr]
            inc rdi 
            mov [rsp + .str_ptr], rdi 
            jmp .process_token

    .calculate_result:
        call rpn_stack_pop
        lea rdi, [str_got_result]
        mov rsi, rax
        call print

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

    section .text
main:
    enter 0, 0

    mov rdi, str_ask_for_expr
    call print

    lea rsi, [str_expr]             ; put the string they supply into a stack var
    mov rdx, 1024
    mov rdi, 0
    xor rax, rax                    ; not using floats
    ; add rsp, 16                    ; 16-bit alignment for C ABI
    call read
     ;sub rsp, 16

    lea rdi, [str_expr]
    call rpn_evaluate

    leave
    ret
; Entrypoint - End
