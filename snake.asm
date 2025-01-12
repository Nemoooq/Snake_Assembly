; Program Snake.asm
; On clock interrupt the snake moves in the direction of the arrow keys
; Executing in real mode (DosBox); or in a virtual machine
; Quitting after pressing the 'x' key
; asembly (MASM 4.0): masm snake.asm;
; consolidation (LINK 3.60): link snake.obj;
.386
program SEGMENT use16
ASSUME cs:program

    direction db 3            ;Variable storing the direction of the snake (0 - UP, 1 - DOWN, 2 - LEFT, 3 - RIGHT)
    counter dw (160*10)+80    ;Variable storing the current position on the screen (value next to it is a starting position)
    wektor8 dd ?              ;Variable storing the address of the original clock interrupt handler
    collision db 0            ;Variable storing the information about the collision
    timeMS dd 0               ;Variable storing the time in milliseconds
    timeS dw 0                ;Variable storing the time in seconds (Program measure when 1000 ms in time variable has passed)
    isFruitSpawned db 0       ;Variable storing the information about the fruit spawn
    snakeLength dw 1          ;Variable storing the length of the snake
    pointsPosition dw 80      ;Variable storing the position of the points counter
    numberOfPositions dw 4000 ;Remember to change this value if you change the size of the stackArea table
    stackArea DW 4000 dup(0)  ;Table storing the snake's positions (4000 because there is 4000 bytes of screen memory)
    tickCounter dw 3          ; TickCounter helps menaging speed of the snake 

; Displaying the number of points stored in AX(!!!!) register (each one second +1 point, each fruit eaten +100)
; on the screen on position stored in pointsPotition variable
displayPoints PROC
    pusha
    mov bx, pointsPosition 
    mov cl, 10         ; divisor
    mov dx, ax         ; copy of AX register containing points

    ; first division by 10 (number of units)
    div cl              ; AX = DX:AX / CL
    add ah, 30H         ; conversion to ASCII code
    mov es:[bx+6], ah 

    ; Second division by 10 (number of tens)
    mov ah, 0
    div cl
    add ah, 30H  
    mov es:[bx+4], ah 

    ; Third division by 10 (number of hundreds)
    mov ah, 0
    div cl
    add ah, 30H  
    mov es:[bx+2], ah 

    ; Fourth division by 10 (number of thousands)
    mov ah, 0
    div cl
    add ah, 30H 
    mov es:[bx+0], ah 

    ; setting the color of the points counter
    mov al, 00001111B
    mov es:[bx+1], al
    mov es:[bx+3], al
    mov es:[bx+5], al
    mov es:[bx+7], al

    popa
    ret 
displayPoints ENDP

spawnFriut PROC
    pusha
    cmp isFruitSpawned, 1
    je fruitAlreadySpawned

trySpawnAgain:
    ; Getting the time in seconds
    mov ah, 2Ch        ; 2ch - Get system time
    int 21h            ; Call DOS
    mov al, dl         ; Copy the result from DL (seconds)

    ; Generating a number in the range 320 - 3800
    mov ah, al         
    mov bl, 24         ; Multiplating by 24 (random number allowing to spawn fruit on whole board, previously (8) it was only at the top section)
    mul bl 
    add ax, 320        ; Adding 320 to be sure that fruit will be spawned on the board
    mov cx, ax      
    mov bx, cx         ; CX is the random number

    mov ax, 0B800h      ; Screen memory address
    mov es, ax          ; Set ES to screen memory segment
    
    cmp byte PTR es:[bx], '*'   ; Check if there is a star on the generated position (border or snake)
    je trySpawnAgain

    mov byte PTR es:[bx], 'O'               ; Place the fruit on the screen
    mov byte PTR es:[bx+1], 01000010b  
    mov isFruitSpawned, 1

fruitAlreadySpawned:
    popa
    ret
spawnFriut ENDP

; Function shifting the snake's positions table right
shiftRight PROC
    pusha

    mov si, numberOfPositions

shiftLoop:          ; Loop shifting the snake's positions table right
    cmp si, 0       ; Check if the start of the table has been reached
    je shiftEnd     ; If so, end the loop
    mov ax, stackArea[si-2]   ; Move the value from the previous position to AX
    mov stackArea[si], ax     ; Move the value from AX to the current position
    sub si, 2                 ; Move to the previous position
    jmp shiftLoop             ; Repeat the loop

shiftEnd:
    mov word PTR stackArea[0], 0 ; Clear the first position in the table
    popa
    ret
shiftRight ENDP

; Function handling the clock interrupt and updating the snake move
move PROC
    pusha
    ;slowing down
    add timeMS, 55            ;addint the clock interrupt time to the timeMS variable
    xor ax, ax
    xor dx, dx 
    mov ax, tickCounter
    inc tickCounter
    mov dx, 0
    mov cx, 3
    div cx
    cmp ax,0
    je waitForNextTick
    mov tickCounter, 3

    call spawnFriut

    ; time update 
    mov ax, word PTR timeMS   ;copying the timeMS variable to AX register 
    cmp ax, 1000              ; Check if 1000 ms has passed if yes add another second
    jb skip_update_seconds
    sub timeMS, 1000          ; Subtract 1000 ms from the timeMS variable
    inc timeS                 ; Add one second to the timeS variable

skip_update_seconds:
    mov ax, 0B800h      ; Screen memory address
    mov es, ax          ; Set ES to screen memory segment
    
    mov bx, cs:counter       ; getting curent position of head of the snake

    ; moving the snake in the direction of the wasd keys (0 - UP, 1 - DOWN, 2 - LEFT, 3 - RIGHT)
    cmp cs:direction, 0     
    je move_up

    cmp cs:direction, 1       
    je move_down

    cmp cs:direction, 2       
    je move_left

    cmp cs:direction, 3     
    je move_right

move_up:
    sub bx, 160               ; move one row up (each row has 160 bytes)
    jmp update_screen

move_down:
    add bx, 160               ; move one row down
    jmp update_screen

move_left:
    sub bx, 2                 ; move one cell to the left (one position is 2 bytes [1:0] 1 - character, 0 - color)
    jmp update_screen

move_right:
    add bx, 2                 ; move one cell to the right
    jmp update_screen

update_screen:

    xor ax, ax                 ; clear the ax register
    mov ax, timeS              ; copy the timeS variable to the ax register
    call displayPoints

    cmp byte PTR es:[bx], '*'  ; check if the snake has collided with the border
    je colissionDetected 
    cmp byte PTR es:[bx], '0'  ; check if the snake has eaten the fruit
    je colissionDetected

    jmp noColission

colissionDetected:
    mov byte PTR collision, 1  ; set the collision variable to 1

noColission:
    cmp byte PTR es:[bx], 'O'  ; check if the snake has eaten the fruit
    jne noFruitEaten
    add timeS, 100             ; add 100 points to the timeS variable 
    mov isFruitSpawned, 0
    add snakeLength, 1

noFruitEaten:
    mov ax, bx              ;save the current position of the snake
    mov cx, snakeLength     ;save the current length of the snake
    shl cx, 1               ;multiply the length of the snake by 2 (each position is 2 bytes)
    mov bx, cx              ;moving to bx because index must be in basisc register (bx) (i think so, others registers are not working xd)
    mov cx, stackArea[bx]   ;getting the position of the tail of the snake
    mov bx, cx              
    mov byte PTR es:[bx], ' '  ;Clearing tail of the snake
    mov byte PTR es:[bx+1], 00000000B
    mov bx, ax              ;returning to state previous to the clearing the tail of the snake

    mov byte PTR es:[bx], '0' ;placing the head of the snake
    mov byte PTR es:[bx+1], 0000010B
    mov stackArea[0], bx    ;saving the position of the head of the snake in the table
    call shiftRight         ;shifting the snake's positions table right

    mov cs:counter, bx      ;saving the current position of the head of the snake
waitForNextTick:
    popa
    jmp dword PTR cs:wektor8  ; return to the original clock interrupt handler

move ENDP


; Function clearing the screen before the game starts
clearScreen PROC
    pusha

    mov ax, 0B800h      ; Screen memory address
    mov es, ax          ; Set ES to screen memory segment
    mov bx, 0           ; Set BX to 0 (start of the screen memory)

clear_loop:
    cmp bx, numberOfPositions          ; Sprawdź, czy osiągnięto koniec pamięci ekranu
    jnb endOfClear                     ; If bx >= all positions number, end the loop

    ; Calculating the row and column: BX/DX, result in AX (row), remainder in DX (column)
    mov ax, bx                     
    mov dx, 0
    mov cx, 160                    
    div cx      

    ; Checking if the current position is a border or an empty space
    cmp ax, 1  
    je border:               

    cmp ax, 24                     
    je border:             

    cmp dx, 0                      
    je border:               

    cmp dx, 158                  
    je border:               

border:
    ; empty characters inside the board
    mov byte PTR es:[bx], ' '      
    mov byte PTR es:[bx+1], 00001100b 
    jmp nextPosition

border:
    mov byte PTR es:[bx], '*'      
    mov byte PTR es:[bx+1], 00001111b 
    jmp nextPosition

    add bx, 2                      ; nex position 
    jmp clear_loop        

endOfClear:
    mov cs:clearCounter, bx              ; zapisanie ostatniej pozycji do zmiennej
    popa
    ret

clearCounter dw 160 ; starting from the second row

clearScreen ENDP

    ; INT 10H, function 5 sets the graphic controller mode
start:
    sti
    mov counter, (160*20)+80            ; Set the starting position of the snake
    mov direction, 0                    ; Set the starting direction of the snake
    call clearScreen                    ; Clear the screen

    ; i dont have any fucking clue what is happening there
    mov al, 0
    mov ah, 5
    int 10
    mov ax, 0
    mov ds,ax ; zerowanie rejestru DS
    
    ; odczytanie zawartości wektora nr 8 i zapisanie go
    ; w zmiennej 'wektor8' (wektor nr 8 zajmuje w pamięci 4 bajty
    ; począwszy od adresu fizycznego 8 * 4 = 32)
    mov eax,ds:[32] ; adres fizyczny 0*16 + 32 = 32
    mov cs:wektor8, eax

    ; wpisanie do wektora nr 8 adresu procedury 'obsluga_zegara'
    mov ax, SEG move ; część segmentowa adresu
    mov bx, OFFSET move ; offset adresu
    cli ; zablokowanie przerwań
    ; zapisanie adresu procedury do wektora nr 8
    mov ds:[32], bx ; OFFSET
    mov ds:[34], ax ; cz. segmentowa
    sti ;odblokowanie przerwań
    ; oczekiwanie na naciśnięcie klawisza 'x'

waitForKey:
    cmp byte PTR collision, 1
    je stopGame

    mov ah, 1
    int 16H                  ; Czekaj na naciśnięcie klawisza
    jz waitForKey            ; Jeśli brak naciśniętego klawisza, spróbuj ponownie

    mov ah, 0
    int 16H                  ; Odczytaj kod klawisza

    cmp al, 'x'
    je stopGame

    cmp al, 'w'
    je dir_move_up

    cmp al, 's'
    je dir_move_down

    cmp al, 'a'
    je dir_move_left

    cmp al, 'd'
    je dir_move_right

    jmp waitForKey
    ;changing direction of the snake
dir_move_up:
    mov cs:direction, 0  ; Set direction to UP
    jmp waitForKey

dir_move_down:
    mov cs:direction, 1  ; Set direction to DOWN
    jmp waitForKey

dir_move_left:
    mov cs:direction, 2  ; Set direction to LEFT
    jmp waitForKey

dir_move_right:
    mov cs:direction, 3  ; Set direction to RIGHT
    jmp waitForKey

stopGame:
    
    ; restore the original clock interrupt handler
    mov eax, cs:wektor8
    cli
    mov ds:[32], eax ; send the original clock interrupt handler address to the vector 8 in the table of interrupts
    sti
    ; End of the program
    mov al, 0
    mov ah, 4CH
    int 21H

    program ENDS
    myStack SEGMENT stack
    db 256 dup (?)
    myStack ENDS
END start

