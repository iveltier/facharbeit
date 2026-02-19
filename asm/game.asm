STDIN   equ 0
STDOUT  equ 1

SYS_READ    equ 0
SYS_WRITE   equ 1
SYS_NANOSLEEP equ 35
SYS_EXIT    equ 60
SYS_IOCTL   equ 16

TCGETS      equ 0x5401
TCSETS      equ 0x5402

section .data
    clear_seq       db 27, "[2J", 27, "[H", 0
    hide_cursor     db 27, "[?25l", 0
    show_cursor     db 27, "[?25h", 0
    
    gamedelay       dq 0,  50000000
    width           dd 60
    height          dd 15
    ground_y        dd 3              
    
    star_str        db "*", 0
    space_str       db " ", 0         
    newline         db 10, 0
    player_char     db "0", 0
    
    player_x        dd 5, 6, 5, 6
    player_y        dd 4, 4, 5, 5


section .bss
    termios         resb 60
    old_termios     resb 60
    isRunning       resb 1
    key_buffer      resb 16

    ; score resd 0

    isJumping resb 1
    jumpStartY resd 4
    jumpPhase resd 1
    stepCounter resd 1

section .text
    global _start

%macro sleep 1
    push rax
    push rdi
    push rsi
    mov rax, SYS_NANOSLEEP
    mov rdi, %1
    xor rsi, rsi
    syscall
    pop rsi
    pop rdi
    pop rax
%endmacro

_start:
    call _save_terminal
    call _set_raw_mode
    mov rax, hide_cursor
    call _print
    mov byte [isRunning], 1

.mainLoop:
    cmp byte [isRunning], 0
    je .game_over
    
    call _handleInput
    call _updateJump
    call _drawCanvas
    sleep gamedelay
    jmp .mainLoop

.game_over:
    call _clearScreen
    mov rax, show_cursor
    call _print
    call _restore_terminal
    jmp _exit


_handleInput:
    push rax
    push rdi
    push rsi
    push rdx
    
    mov rax, SYS_READ
    mov rdi, STDIN
    mov rsi, key_buffer
    mov rdx, 1
    syscall
    
    cmp rax, 1
    jl .no_input
    
    movzx rax, byte [key_buffer]
    cmp al, 'q'
    je .quit_key
    cmp al, 'Q'
    je .quit_key
    
    cmp al, ' '
    je .jump_key
    
    jmp .no_input

.quit_key:
    mov byte [isRunning], 0
    jmp .no_input

.jump_key:
    call _jump
    jmp .no_input

.no_input:
    pop rdx
    pop rsi
    pop rdi
    pop rax
    ret

_jump:
    push rax
    
    cmp byte [isJumping], 1
    je .jump_done
    
    mov byte [isJumping], 1

    mov dword [jumpPhase], 0      
    mov dword [stepCounter], 0   

    mov eax, dword [player_y + 0]
    mov dword [jumpStartY + 0], eax
    mov eax, dword [player_y + 4]
    mov dword [jumpStartY + 4], eax
    mov eax, dword [player_y + 8]
    mov dword [jumpStartY + 8], eax
    mov eax, dword [player_y + 12]
    mov dword [jumpStartY + 12], eax
    

.jump_done:
    pop rax
    ret

_updateJump:
    push rax

    cmp byte [isJumping], 0
    je .update_done

    mov eax, dword [jumpPhase]
    cmp eax, 0
    je .phase_up
    cmp eax, 1
    je .phase_hold
    jmp .phase_down

.phase_up:
    mov eax, dword [player_y + 0]
    add eax, 1
    mov dword [player_y + 0], eax

    mov eax, dword [player_y + 4]
    add eax, 1
    mov dword [player_y + 4], eax

    mov eax, dword [player_y + 8]
    add eax, 1
    mov dword [player_y + 8], eax

    mov eax, dword [player_y + 12]
    add eax, 1
    mov dword [player_y + 12], eax

    mov eax, dword [stepCounter]
    inc eax
    mov dword [stepCounter], eax

    cmp eax, 4
    jl .update_done

    mov dword [jumpPhase], 1
    mov dword [stepCounter], 0
    jmp .update_done

.phase_hold:
    mov eax, dword [stepCounter]
    inc eax
    mov dword [stepCounter], eax

    cmp eax, 2
    jl .update_done

    mov dword [jumpPhase], 2
    mov dword [stepCounter], 0
    jmp .update_done

.phase_down:
    mov eax, dword [player_y + 0]
    cmp eax, dword [jumpStartY + 0]
    je .landed

    mov eax, dword [player_y + 0]
    dec eax
    mov dword [player_y + 0], eax

    mov eax, dword [player_y + 4]
    dec eax
    mov dword [player_y + 4], eax

    mov eax, dword [player_y + 8]
    dec eax
    mov dword [player_y + 8], eax

    mov eax, dword [player_y + 12]
    dec eax
    mov dword [player_y + 12], eax

    jmp .update_done

.landed:
    mov byte [isJumping], 0
    mov dword [jumpPhase], 0
    mov dword [stepCounter], 0

.update_done:
    pop rax
    ret

_save_terminal:
    push rax
    push rdi
    push rsi
    push rdx
    mov rax, SYS_IOCTL
    mov rdi, STDIN
    mov rsi, TCGETS
    mov rdx, old_termios
    syscall
    pop rdx
    pop rsi
    pop rdi
    pop rax
    ret

_set_raw_mode:
    push rax
    push rdi
    push rsi
    push rdx
    
    mov rax, SYS_IOCTL
    mov rdi, STDIN
    mov rsi, TCGETS
    mov rdx, termios
    syscall
    
    mov eax, dword [termios + 12]
    and eax, ~2
    and eax, ~8
    and eax, ~1
    mov dword [termios + 12], eax
    
    mov byte [termios + 22], 0
    mov byte [termios + 23], 0
    
    mov rax, SYS_IOCTL
    mov rdi, STDIN
    mov rsi, TCSETS
    mov rdx, termios
    syscall
    
    pop rdx
    pop rsi
    pop rdi
    pop rax
    ret

_restore_terminal:
    push rax
    push rdi
    push rsi
    push rdx
    mov rax, SYS_IOCTL
    mov rdi, STDIN
    mov rsi, TCSETS
    mov rdx, old_termios
    syscall
    pop rdx
    pop rsi
    pop rdi
    pop rax
    ret

_clearScreen:
    push rax
    mov rax, clear_seq
    call _print
    pop rax
    ret

_screenToGame:
    push rbx
    push rcx
    
    mov r12, rbx
    
    mov r13d, dword [height]
    dec r13d                
    sub r13d, ecx          
    
    pop rcx
    pop rbx
    ret

_isPlayerHere:
    push rbx
    push rcx
    push rdx
    push rsi
    push r12
    push r13
    push r14
    
    call _screenToGame      
    
    xor r14, r14            
    
.check_loop:
    cmp r14, 4
    jge .not_player       
    
    mov eax, dword [player_x + r14*4]   
    cmp r12d, eax
    jne .next_char
    
    mov eax, dword [player_y + r14*4] 
    cmp r13d, eax
    jne .next_char
    
    mov rax, 1
    jmp .done

.next_char:
    inc r14
    jmp .check_loop

.not_player:
    xor rax, rax

.done:
    pop r14
    pop r13
    pop r12
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    ret

_isGroundHere:
    push rbx
    push rcx
    push rdx
    push rsi
    push r12
    push r13
    
    call _screenToGame      
    
    cmp r13d, dword [ground_y]
    jle .is_ground
    
    xor rax, rax
    jmp .done

.is_ground:
    mov rax, 1

.done:
    pop r13
    pop r12
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    ret

_drawCanvas:
    push rcx
    push rbx
    push rax
    
    xor rcx, rcx            

    call _clearScreen

.height_loop:
    cmp ecx, dword [height]
    jge .draw_done          
    
    xor rbx, rbx            

.width_loop:
    cmp ebx, dword [width]
    jge .width_done           
    
    push rbx
    push rcx
    
    call _isPlayerHere
    cmp rax, 1
    je .draw_player
    
    call _isGroundHere
    cmp rax, 1
    je .draw_ground
    
    mov rax, space_str
    call _print
    jmp .next_width

.draw_player:
    mov rax, player_char
    call _print
    jmp .next_width

.draw_ground:
    mov rax, star_str
    call _print

.next_width:
    pop rcx
    pop rbx
    
    inc rbx                 
    jmp .width_loop

.width_done:
    push rcx
    mov rax, newline
    call _print
    pop rcx
    
    inc rcx                 
    jmp .height_loop

.draw_done:
    pop rax
    pop rbx
    pop rcx
    ret

_print: 
    push rax
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi
    
    mov rbx, rax
    xor rcx, rcx
    
.count_loop:
    mov al, [rbx + rcx]
    cmp al, 0
    je .print_it
    inc rcx
    jmp .count_loop
    
.print_it:
    mov rax, SYS_WRITE
    mov rdi, STDOUT
    mov rsi, rbx
    mov rdx, rcx
    syscall
    
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

_exit: 
    mov rax, SYS_EXIT
    xor rdi, rdi
    syscall
