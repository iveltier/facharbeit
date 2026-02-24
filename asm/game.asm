STDIN   equ 0
STDOUT  equ 1

SYS_READ    equ 0
SYS_WRITE   equ 1
SYS_NANOSLEEP equ 35
SYS_EXIT    equ 60
SYS_IOCTL   equ 16

TCGETS      equ 0x5401
TCSETS      equ 0x5402

NUM_OBSTACLES   equ 4           
MIN_DISTANCE    equ 20

section .data
    clear       db 27, "[2J", 27, "[H", 0
    hideCursor     db 27, "[?25l", 0
    showCursor     db 27, "[?25h", 0
    
    gamedelay       dq 0,  50000000
    enddelay dq 0, 900000000
    width           dd 60
    height          dd 15
    ground_y        dd 3              
    
    star_str        db "*", 0
    space_str       db " ", 0         
    newline         db 10, 0
    player_char     db "0", 0
    
    player_x        dd 4,4, 5, 5
    player_y        dd 4, 5, 4, 5

    obstacleChars db "#", "+", "@", "%", "$",0
    
    instruction db "PRESS 'SPACE' TO JUMP",0
    scoreMsg db "SCORE: ",0
    gameOverMsg db "****** GAME OVER *****", 0
    endMsg db "*** Thanks for Playing! ***",0 
    highscoreMsg db "Developer-Highscore: 60",0
    brokeHighscoreMsg db "You just broke the developer-highscore!",0


section .bss
    termios         resb 60
    old_termios     resb 60
    isRunning       resb 1
    key_buffer      resb 16

    isJumping resb 1
    jumpStartY resd 4
    jumpPhase resd 1
    stepCounter resd 1


    obstacle_x resb 32
    obstacle_y resb 32
    obstacle_end resb 32   ; letztes segment eines obstacles
    obstacleCount resb 1   ; anazhl aktiveer obstacles-segmente
    obstacleNum   resb 1   ; Anzahl aktiver obstacles gesamt
    obstacleChar resb 8
    obstacleCharBuf resb 2
    obstacleId resb 32
    currentObstacleId resb 1
    
    score resd 1
    scoreBuf resb 12   

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

    mov dword [score], 0        
    call saveTerminal
    call setRawMode

    mov rax, hideCursor
    call print

    call initObstacles
    mov byte [isRunning], 1

.mainLoop:
    cmp byte [isRunning], 0
    je .gameOver
    
    call handleInput
    call updateJump
    call updateObstacle
    call checkCollision
    call drawCanvas

   ; je größer score umso schneller
   push rax
   push rdx
   mov eax, dword [score]
   mov edx, 500000
   mul edx                     
   mov edx, 50000000
   sub edx, eax
   cmp edx, 5000000            
   jge .setDelay
   ; max 5ms / frame
   mov edx, 5000000

.setDelay:
    mov dword [gamedelay + 8], edx   
    pop rdx
    pop rax

    sleep gamedelay
    jmp .mainLoop

.gameOver:
    call clearScreen
    mov rax, showCursor
    call print
    call restoreTerminal

    mov rax, gameOverMsg
    call print

    mov rax, newline
    call print
    mov rax, newline
    call print
    
    mov rax, scoreMsg
    call print
    call printScore

    mov rax, newline
    call print

    mov rax, highscoreMsg
    call print

    mov rax, newline
    call print

    mov rbx, [score]
    cmp rbx, 60
    jg .brokeHighscore
    
    .end:
    mov rax, newline
    call print
    mov rax, newline
    call print

    sleep enddelay

    mov rax, endMsg
    call print

    mov rax, newline
    call print

    jmp exit

    .brokeHighscore:
        mov rax, brokeHighscoreMsg
        call print
        jmp .end

saveTerminal:
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

setRawMode:
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


initObstacles:
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi

    mov byte [obstacleCount], 0
    mov byte [obstacleNum], 0

.initLoop:
    movzx eax, byte [obstacleNum]
    cmp eax, NUM_OBSTACLES
    jge .done

    call generateObstacle
    jmp .initLoop

.done:
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    ret

handleInput:
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
    jl .noInput
    
    movzx rax, byte [key_buffer]
    cmp al, 'q'
    je .quitKey
    cmp al, 'Q'
    je .quitKey
    
    cmp al, ' '
    je .jumpKey
    
    jmp .noInput

.quitKey:
    mov byte [isRunning], 0
    jmp .noInput

.jumpKey:
    call jump
    jmp .noInput

.noInput:
    pop rdx
    pop rsi
    pop rdi
    pop rax
    ret

jump:
    push rax
    
    cmp byte [isJumping], 1
    je .done
    
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
    
.done:
    pop rax
    ret

updateJump:
    push rax

    cmp byte [isJumping], 0
    je .done

    mov eax, dword [jumpPhase]
    cmp eax, 0
    je .phaseUp
    cmp eax, 1
    je .phaseHold
    jmp .phaseDown

.phaseUp:
    mov eax, dword [player_y + 0]
    inc eax
    mov dword [player_y + 0], eax

    mov eax, dword [player_y + 4]
    inc eax
    mov dword [player_y + 4], eax

    mov eax, dword [player_y + 8]
    inc eax
    mov dword [player_y + 8], eax

    mov eax, dword [player_y + 12]
    inc eax
    mov dword [player_y + 12], eax

    mov eax, dword [stepCounter]
    inc eax
    mov dword [stepCounter], eax

    cmp eax, 4
    jl .done

    mov dword [jumpPhase], 1
    mov dword [stepCounter], 0
    jmp .done

.phaseHold:
    mov eax, dword [stepCounter]
    inc eax
    mov dword [stepCounter], eax

    cmp eax, 2
    jl .done

    mov dword [jumpPhase], 2
    mov dword [stepCounter], 0
    jmp .done

.phaseDown:
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

    jmp .done

.landed:
    mov byte [isJumping], 0
    mov dword [jumpPhase], 0
    mov dword [stepCounter], 0

.done:
    pop rax
    ret

updateObstacle:
    push rax
    push rbx
    push rcx
    push rsi
    push rdi
    push r8
    push r9

    movzx rcx, byte [obstacleCount]
    xor rbx, rbx        
    xor rdi, rdi        
    xor r8, r8         

.checkLoop:
    cmp rbx, rcx
    jge .finish

    movsx eax, byte [obstacle_x + rbx]

    cmp eax, 0
    jl .deleteSegment

    dec eax
    mov [obstacle_x   + rdi], al
    mov al, [obstacle_y   + rbx]
    mov [obstacle_y   + rdi], al
    mov al, [obstacle_end + rbx]
    mov [obstacle_end + rdi], al
    mov al, [obstacleId  + rbx]   
    mov [obstacleId  + rdi], al  
    inc rdi
    inc rbx
    jmp .checkLoop

.deleteSegment:
    movzx eax, byte [obstacle_end + rbx]
    inc rbx
    cmp eax, 1
    je .last ; wenn es das letzte segment eines obstacles war => neues generieren
    jmp .checkLoop    

.last:

    inc r8   
    jmp .checkLoop

.finish:
    mov [obstacleCount], dil

    ; obstacleNum updaten
    movzx eax, byte [obstacleNum]
    sub eax, r8d
    mov [obstacleNum], al

.generateNew:
    cmp r8, 0
    jle .done
    call generateObstacle
    dec r8

    mov eax, dword [score]
    inc eax
    mov dword [score], eax
    jmp .generateNew

.done:
    pop r9
    pop r8
    pop rdi
    pop rsi
    pop rcx
    pop rbx
    pop rax
    ret

generateObstacle:
    push rax
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi
    push r8
    push r10

    movzx rdi, byte [obstacleCount]

    ; zufälligen char bestimmen
    call getRandom
    xor edx, edx
    mov ecx, 5
    div ecx             
    mov r9b, dl         

    ; Breite 1-3
    call getRandom
    xor edx, edx
    mov ecx, 3
    div ecx             ; edx = 0,1,2
    mov ebx, edx
    inc ebx             ; width = 1..3

    ; Höhe 1-2
    call getRandom
    and eax, 1
    inc eax
    mov edx, eax        ; height = 1 oder 2

    ; Start-X bestimmen
    movzx eax, byte [obstacleNum]
    cmp eax, 0
    je .firstObstacle

    xor ecx, ecx
    xor rsi, rsi
    movzx r8, byte [obstacleCount]

.findMaxX:
    cmp rsi, r8
    jge .foundMax
    movzx eax, byte [obstacle_x + rsi]
    cmp eax, ecx
    jle .nextSearch
    mov ecx, eax

.nextSearch:
    inc rsi
    jmp .findMaxX

.foundMax:
    add ecx, MIN_DISTANCE

    call getRandom
    and eax, 15
    add ecx, eax

    ; ab 127 = negativ => maxmial x = 120
    ; gab sonst bug mit score++
    cmp ecx, 120
    jle .write
    mov ecx, 120
    jmp .write

.firstObstacle:
    mov ecx, 60

.write:
.writeLoop:
    cmp ebx, 0
    je .writeDone

    mov byte [obstacle_x + rdi], cl
    mov byte [obstacle_y + rdi], 4
    mov byte [obstacle_end + rdi], 0
    mov byte [obstacleId  + rdi], r9b  
    inc rdi

    cmp edx, 2
    jne .nextCol
    mov byte [obstacle_x + rdi], cl
    mov byte [obstacle_y + rdi], 5
    mov byte [obstacle_end + rdi], 0
    mov byte [obstacleId  + rdi], r9b
    inc rdi

.nextCol:
    inc ecx
    dec ebx
    jmp .writeLoop

.writeDone:
    mov r10, rdi
    dec r10
    mov byte [obstacle_end + r10], 1
    mov [obstacleCount], dil
    movzx eax, byte [obstacleNum]
    inc eax
    mov [obstacleNum], al

    pop r10
    pop r8
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

; eax = random num (0-255)
getRandom:
    push rdx
    rdtsc                   
    xor eax, edx        
    pop rdx
    ret

checkCollision:
    push rbx
    push rcx
    push rdx
    push rsi
    push r12
    push r13
    push r14

    movsx r12d, byte [player_x]     
    movsx r13d, byte [player_y]    

    xor r14, r14                    

.checkLoop:
    movzx ecx, byte [obstacleCount]
    cmp r14d, ecx
    jge .noCollision                

    movsx eax, byte [obstacle_x + r14]
    cmp r12d, eax                  
    jne .next

    movsx eax, byte [obstacle_y + r14]
    cmp r13d, eax                  
    jne .next

    mov byte [isRunning], 0

    pop r14
    pop r13
    pop r12
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    ret

.next:
    inc r14
    jmp .checkLoop

.noCollision:
    pop r14
    pop r13
    pop r12
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    ret

clearScreen:
    push rax
    mov rax, clear
    call print
    pop rax
    ret

drawCanvas:
    push rcx
    push rbx
    push rax
    
    xor rcx, rcx            

    call clearScreen
    mov rax, instruction
    call print

    mov rax, newline
    call print

    mov rax, scoreMsg
    call print
    call printScore

.heightLoop:
    cmp ecx, dword [height]
    jge .drawDone          
    
    xor rbx, rbx            

.widthLoop:
    cmp ebx, dword [width]
    jge .widthDone           
    
    push rbx
    push rcx

    mov rbx, rbx
    mov rcx, rcx
    
    call isPlayer
    cmp rax, 1
    je .drawPlayer

    call isObstacle
    cmp rax, 1
    je .drawObstacle
    
    call isGround
    cmp rax, 1
    je .drawGround
    
    mov rax, space_str
    call print
    jmp .nextWidth

.drawPlayer:
    mov rax, player_char
    call print
    jmp .nextWidth

.drawObstacle:
    movzx eax, byte [currentObstacleId]
    movzx ecx, byte [obstacleChars + eax]
    mov byte [obstacleCharBuf], cl
    mov byte [obstacleCharBuf + 1], 0
    lea rax, [obstacleCharBuf]
    call print
    jmp .nextWidth

.drawGround:
    mov rax, star_str
    call print

.nextWidth:
    pop rcx
    pop rbx
    
    inc rbx                 
    jmp .widthLoop

.widthDone:
    push rcx
    mov rax, newline
    call print
    pop rcx
    
    inc rcx                 
    jmp .heightLoop

.drawDone:
    pop rax
    pop rbx
    pop rcx
    ret

; macht das die unter linie y = 0 ist

screenToGame:
    push rbx
    push rcx
    
    mov r12, rbx
    
    mov r13d, dword [height]
    dec r13d                
    sub r13d, ecx          
    
    pop rcx
    pop rbx
    ret

isPlayer:
    push rbx
    push rcx
    push rdx
    push rsi
    push r12
    push r13
    push r14
    
    call screenToGame      
    
    xor r14, r14            
    
.checkLoop:
    cmp r14, 4
    jge .notPlayer       
    
    mov eax, dword [player_x + r14*4]   
    cmp r12d, eax
    jne .nextChar
    
    mov eax, dword [player_y + r14*4] 
    cmp r13d, eax
    jne .nextChar
    
    mov rax, 1
    pop r14
    pop r13
    pop r12
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    ret

.nextChar:
    inc r14
    jmp .checkLoop

.notPlayer:
    xor rax, rax
    pop r14
    pop r13
    pop r12
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    ret

isObstacle:
    push rbx
    push rcx
    push rdx
    push rsi
    push r12
    push r13
    push r14

    ; rbx = screen-x, rcx = screen-y
    call screenToGame      
    ; r12 = game-x, r13 = game-y

    xor r14, r14

.checkLoop:
    movzx rcx, byte [obstacleCount]
    cmp r14, rcx
    jge .notObstacle

    movsx eax, byte [obstacle_x + r14]
    cmp r12d, eax
    jne .next

    movsx eax, byte [obstacle_y + r14]
    cmp r13d, eax
    jne .next

    mov al,[obstacleId + r14]
    mov [currentObstacleId], al
    mov rax, 1
    pop r14
    pop r13
    pop r12
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    ret

.next:
    inc r14
    jmp .checkLoop

.notObstacle:
    xor rax, rax
    pop r14
    pop r13
    pop r12
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    ret

isGround:
    push rbx
    push rcx
    push rdx
    push rsi
    push r12
    push r13
    
    call screenToGame      
    
    cmp r13d, dword [ground_y]
    jle .isGround
    
    xor rax, rax
    pop r13
    pop r12
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    ret

.isGround:
    mov rax, 1
    pop r13
    pop r12
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    ret

print: 
    push rax
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi
    
    mov rbx, rax
    xor rcx, rcx
    
.countLoop:
    mov al, [rbx + rcx]
    cmp al, 0
    je .print
    inc rcx
    jmp .countLoop
    
.print:
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

printScore:
    push rax
    push rbx
    push rcx
    push rdx
    push rdi
    push rsi

    mov eax, dword [score]
    lea rdi, [scoreBuf + 11]
    mov byte [rdi], 0 
    dec rdi

    cmp eax, 0
    jne .convert
    mov byte [rdi], '0'
    dec rdi
    jmp .print

.convert:
    cmp eax, 0
    je .print
    xor edx, edx
    mov ecx, 10
    div ecx
    add dl, '0'
    mov [rdi], dl
    dec rdi
    jmp .convert

.print:
    inc rdi
    mov rax, rdi
    call print

    pop rsi
    pop rdi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

restoreTerminal:
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

exit: 
    mov rax, SYS_EXIT
    xor rdi, rdi
    syscall
