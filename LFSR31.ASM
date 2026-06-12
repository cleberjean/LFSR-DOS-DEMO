;*****************************************************************************
; Linear Feedback Shift Register Use Demonstration for 8086 CPU
; Cleber Jean Barranco <cleberjean@hotmail.com>
; Version 3.1 (with messages) from 10jun2026.
; Runs "Fade In" and "Fade Out" effects until the Esc key is pressed.
;
; Compile with: nasm lfsr.asm -o lfsr.com
;
; NOTE: BP register stores the LFSR seed THROUGHOUT the program!
;*****************************************************************************


    cpu   8086                         ; code for 8086 (OBRIGATORY directive)

    org   100h                         ; Program is a .COM file


;-----------------------------------------------------------------------------
; Constants
;-----------------------------------------------------------------------------
    FADE_IN_COLOR       equ 0x0F       ; Color for screen full
    FADE_OUT_COLOR      equ 0x00       ; Color for screen empty
    LFSR_XOR_MASK       equ 0xB400     ; XOR mask for LFSR computing
    LFSR_INITIAL_SEED   equ 1          ; LFSR initial seed (CANNOT be = 0)
    LFSR_MAX_PERIOD     equ 64000      ; Fill 64000 bytes from screen 320x200
    ESC_KEY             equ 0x1B       ; Esc key ASCII code
    PIXELS_PER_FRAME    equ 512        ; (512 ~ 2s) The lower the value, the
                                       ; slower the effect
    POSITION_MSG_FULL   equ 0x6E54     ; VGA offset where to print (28160 + 88)
    POSITION_MSG_BLANK  equ POSITION_MSG_FULL - 4 ; As "The Screen is Blank"
                                                  ; is one char wide than
                                                  ; "The Screen is Full" msg,
                                                  ; it is printed four pixels
                                                  ; before on screen. 
    
    CHARSET_BIOS_SEGMEM equ 0xF000      ; BIOS Charset Bitmaps Table segment
    CHARSET_BIOS_OFFSET equ 0xFA6E      ; BIOS Charset Bitmaps Table offset


;-----------------------------------------------------------------------------
; Program Start
; Checks if Video Card is a VGA/MCGA (1A00h function from INT 10h)
;-----------------------------------------------------------------------------
Begin:   
    mov    ax,1A00h
    int    10h                         ; Checks presence of VGA/MCGA card
    cmp    al,1Ah
    jne    No_VGA                      ; IF AL != 1Ah video card not is VGA
    cmp    bl,08h
    je     Get_Video_Mode              ; VGA with a color monitor
    cmp    bl,0Ah
    je     Get_Video_Mode              ; MCGA with a color monitor (digital)
    cmp    bl,0Ch
    je     Get_Video_Mode              ; MCGA with a color monitor


;-----------------------------------------------------------------------------
; VGA with an W&B Monitor or is Not a VGA
;-----------------------------------------------------------------------------
No_VGA:
    mov    dx,Need_VGA_Msg             ; Error message for no VGA video card
    mov    ah,09h
    int    21h                         ; Show error message
    int    20h                         ; Backs to DOS (All DOSes)


;-----------------------------------------------------------------------------
; Gets and Saves the Current Video Mode
;-----------------------------------------------------------------------------
Get_Video_Mode:
    mov   ah,0Fh
    int   10h                          ; Gets current video mode
    push  ax                           ; Saves current video mode
                                       ; Will restored on before to return to DOS


;-----------------------------------------------------------------------------
; Change Video Mode to 320x200 by 256 Colors
;-----------------------------------------------------------------------------
Set_VGA_Mode:    
    mov   ax,0013h                     ; Video mode 13h
    int   10h                          ; Change to MCGA (320x200x256)


;-----------------------------------------------------------------------------
; Get Charset Bitmaps Table Address and Saves   
; Also may use F000:FA6E BIOS address. (But is not 100% reliable!)
;-----------------------------------------------------------------------------
    mov   ax, 1130h
    mov   bh, 03h                      ; ROM font 8x8
    int   10h                          ; Gets charset bitmaps address in ES:BP
    mov   [Charset_BMP_Seg],es         ; Charset bitmaps segment
    mov   [Charset_BMP_Off],bp         ; Charset bitmaps offset address start


;-----------------------------------------------------------------------------
; 1 Second Delay for Monitor Change Resolution   
;-----------------------------------------------------------------------------
    mov   cx,70                        ; 70 frames = 1 second on 70 FPS
    call  Count_Retrace                ; Waits the monitor to change resolution
;    cmp   al,ESC_KEY
;    je    Finish


;-----------------------------------------------------------------------------
; Init Registers
;-----------------------------------------------------------------------------
    mov   ax,0A000h                    ; VGA 320x200 segment
    mov   es,ax                        ; ES will point to VGA
    push  cs                           ; Gets code segment
    pop   ds                           ; DS points to vars into program code
    cld                                ; Index registers increments
    
    call  Wait_Vertical_Retrace        ; Checks if retrace is in progress
                                       ; and wait it to restart

;-----------------------------------------------------------------------------
; Start of "Fade In" Effect
;-----------------------------------------------------------------------------
Fade_In_Start:    
    call  Get_Initial_LFSR_Seed


;-----------------------------------------------------------------------------
; Fade In Effect    
;-----------------------------------------------------------------------------
Fade_In_Frame_Loop:    
    mov   cx,PIXELS_PER_FRAME


Fade_In_Plot_Loop:
    mov   al,FADE_IN_COLOR             ; NOTE: AL is changed by the keyboard
                                       ;       checking, then we have restore 
                                       ;       it.
    mov   di,bp                        ; Copies LFSR number to DI
    dec   di                           ; This allow to unplot at position 0
    stosb                              ; Plots the dot
    call  Get_LFSR_Number
    cmp   bp,[Initial_Seed]            ; The screen is full?
    je    Pause_FI                     ; Yes, then makes a pause for Fade Out
    loop  Fade_In_Plot_Loop

; Checks Keyboard    
    call  Check_Keyboard               ; Checks keyboard
    cmp   al,ESC_KEY                   ; Was Esc key pressed?
    je    Finish                       ; Yes, terminates program
    call  Wait_Vertical_Retrace        ; 
    jmp   Fade_In_Frame_Loop           ;


;-----------------------------------------------------------------------------
; Pause of Aprox. 2.5 Seconds for the Transition Between Fade In and Fade Out
; Finish the program if Esc key is pressed while pause is in progress.
;-----------------------------------------------------------------------------
Pause_FI:    
;    mov   cx,60                        ; Wait 60 frames
;    call  Count_Retrace                ; Waits 1s (on 60 FPS) to show the message
    mov   si,Msg_Full
    mov   di,POSITION_MSG_FULL
    call  Show_Message
    call  Pause
    cmp   al,ESC_KEY                   ; Was Esc key pressed?
    je    Finish                       ; Yes, terminates program


;-----------------------------------------------------------------------------
; Start of "Fade Out" Effect
;-----------------------------------------------------------------------------
Fade_Out_Start:    
    call  Get_Initial_LFSR_Seed        ; Get a new seed

Fade_Out_Frame_Loop:    
    mov   cx,PIXELS_PER_FRAME          ; Loads loop counter with the number 
                                       ; of pixels per frame
Fade_Out_Plot_Loop:
    mov   al,FADE_OUT_COLOR            ; NOTE: AL is changed by the keyboard
                                       ;       checking, then we have restore 
                                       ;       it.
    mov   di,bp                        ; Copies LFSR number to DI
    dec   di                           ; This allow to unplot at position 0
    stosb                              ; Unplots the dot
    call  Get_LFSR_Number
    cmp   bp,[Initial_Seed]            ; The screen is clean?
    je    Pause_FO                     ; Yes, then pause to restart effects
    loop  Fade_Out_Plot_Loop
    
; Checks Keyboard    
    call  Check_Keyboard               ; Checks keyboard
    cmp   al,ESC_KEY                   ; Was Esc key pressed?
    je    Finish                       ; Yes, terminates program
    call  Wait_Vertical_Retrace        ; 
    jmp   Fade_Out_Frame_Loop          ;


;-----------------------------------------------------------------------------
; Pause of 2.5 Seconds for the Transition Between Fade Out and Fade In
; Finish the program if Esc key is pressed while pause is in progress.
;-----------------------------------------------------------------------------
Pause_FO:
;    mov   cx,60                        ; Wait 60 frames
;    call  Count_Retrace                ; Waits 1s (on 60 FPS) to show the message
    mov   si,Msg_Clean
    mov   di,POSITION_MSG_BLANK
    call  Show_Message
    call  Pause
    cmp   al,ESC_KEY                   ; Was Esc key pressed?
    jne   Fade_In_Start                ; No, then restart effects


;-----------------------------------------------------------------------------
; Program End
;-----------------------------------------------------------------------------
Finish:
    pop   ax                           ; Restores original video mode (AL)
    xor   ah,ah                        ; Function 0
    int   10h                          ; Backs to original video mode
    int   20h                          ; Backs to DOS (All DOSes)


;-----------------------------------------------------------------------------
; A Litte Delay Using a Frames Counter Routine
; Counts the start of Vertical Retraces to know the pause time.
; Checks keyboard during pause. (no locking)
; Exits if Esc is pressed, returning Esc code in AL.
;
; Loading CX with a frames number and calling Count_Retrace, allow modify
; the pause duration.
;-----------------------------------------------------------------------------
Pause:
    mov    cx,154                      ; 150 frames (2,5 seconds in 60 FPS).
                                       ; And + 4, to break the synchronization
                                       ; of LFSR seed with the time.
Count_Retrace:
    call   Check_Keyboard
    cmp    al,ESC_KEY                  ; Checks if Esc was pressed during timing.
    je     Exit_Pause                  ; Yes, then aborts pause.
    call   Wait_Vertical_Retrace       ; Waits Vertical Retrace to start to count it.
    loop   Count_Retrace               ; Backs to counter a new retrace.
    xor    al,al                       ; None key was pressed during pause,
                                       ; then returns with AL = 0.
Exit_Pause:
    ret


;-----------------------------------------------------------------------------
; Wait Vertical Retrace to Finish, Case It Is in Progress
;-----------------------------------------------------------------------------
Wait_Vertical_Retrace:    
    mov   dx,03DAh
    in    al,dx
    test  al,8
    jnz   Wait_Vertical_Retrace

Wait_Vertical_Retrace_Start:
;    mov   dx,03DAh                    ; Use if you will need call
                                       ; Wait_Vertical_Retrace_Start from
                                       ; another place in the code.
    in    al,dx
    test  al,8
    jz    Wait_Vertical_Retrace_Start
    ret


;-----------------------------------------------------------------------------
; Checks Keyboard
; Returns AX = 0 if none key was pressed.   
;-----------------------------------------------------------------------------
Check_Keyboard:
    mov   ah,01h
    int   16h                          ; Checks if any key was pressed
    jnz   Get_Key                      ; Yes, then gets the pressed key
    xor   ax,ax                        ; Key Code for none key pressed (0)
    ret

; Reads Keyboard Buffer (get pressed key)
Get_Key:    
    xor   ah,ah
    int   16h                          ; Gets the value of the pressed key
    ret                                ; Returns with pressed key in AL.


;-----------------------------------------------------------------------------
; Initializes Initial FLSR Seed (= RANDOMIZE TIMER in QBasic)
; Gets initial seed from system ticks.
; Input:  None.
; Output: DX, BP = Random seed for the LFSR.
;-----------------------------------------------------------------------------
Get_Initial_LFSR_Seed:
    xor   ah,ah
    int   1Ah                          ; Get system clock ticks since midnight
    xor   dx,cx                        ; XOR between high and low order
    jnz   Seed_Not_Zero                ; If non zero, store on memory and copies to DI
    inc   dx                           ; Turns seed = 1 (seed CANNOT be 0)

Seed_Not_Zero:
    cmp   dx,LFSR_MAX_PERIOD           ; Checks if seed is on range 1 to 64000
    jbe   Seed_OK                      ; Is seed > 64000?
    call  Get_LFSR_Number              ; Yes, then raffle a new value into 
                                       ; period from 1 to 64000.
    mov   dx,bp                        ; Copies the drawn LFSR seed in DX,
                                       ; to save it on the next instruction.
Seed_OK:
    mov   [Initial_Seed],dx            ; Randomize LFSR initial seed
    mov   bp,dx                        ; Initializes BP (LFSR Seed Register)
    ret


;-----------------------------------------------------------------------------
; LFSR Galois Number Generator (stored in BP reg by all program execution)
; Since LFSR does not generate the value 0 (is prohibited), we must
; generate a period from 1 to 64000, to obtain the value 0 (if BP = 1), 
; by decrementing BP before using it and incrementing it again after use,
; to back it to a non zero value, since BP stores the LFSR seed throughout 
; the program.
; Input : BP = LFSR seed
; Output: BP = new LFSR seed (value from 1 to 64000)
;              Decrement BP value by 1 to get 0 to 63999, BUT you must
;              restore it again, after the use.
;-----------------------------------------------------------------------------
Get_LFSR_Number:
    shr   bp,1
    jnc   Check_Bound
    xor   bp,LFSR_XOR_MASK

; Checks Value Limit (not used if period is 65536)
Check_Bound:
    cmp   bp,LFSR_MAX_PERIOD
    ja    Get_LFSR_Number              ; Gen another number if number >= max period
                                       ; JA allow generate from 0 up to maximum 
                                       ; period - 1, by decrementing BP, using
                                       ; it and incrementing it again to
                                       ; correct it for a non zero value.
    ret


;;-----------------------------------------------------------------------------
;; LFSR Galois Number Generator (2nd Option - Not Uses BP)
;; Generates a period from 1 up to 64000.
;; To get 0 to 63999, decrement AX by 1, where use it on code.
;;
;; Input : None.
;; Output: AX = new LFSR seed.
;;         Use another register if desire to preserve AX.
;;-----------------------------------------------------------------------------
;Get_LFSR_Number:
;    mov   ax,[LFSR_Seed]               ; Gets LFSR seed saved on RAM memory
;    shr   ax,1
;    jnc   Check_Bound
;    xor   ax,LFSR_XOR_MASK
;
;; Checks Value Limit (not used if period is 65536)
;Check_Bound:
;    cmp   ax,LFSR_MAX_PERIOD
;    ja    Get_LFSR_Number              ; Gen another number if number >= max period
;                                       ; JA allow generate from 0 up to the
;                                       ; maximum period - 1 (by decrementing AX).
;    mov   [LFSR_Seed],ax               ; preserves LFSR seed on RAM memory
;    ret


;-----------------------------------------------------------------------------
; Show Message on Screen
; Input : SI = Offset Address of the message to show
;         DI = VGA Offset Address where to print
; Output: AX = 0
;         BX, DI and SI destroyed
;-----------------------------------------------------------------------------
Show_Message:
    lodsb                              ; Gets character to print
    test  al,al                        ; Checks message end (null char)
    jz    End_Printing
    call  Draw_Char_Mode_13h           ; Prints a single character
    jmp   Show_Message

End_Printing:
    ret


;-----------------------------------------------------------------------------
; Draw_Char_Mode_13h Routine
; Derived from Google Gemini Code
; Draws an 8x8 character on screen with inverted background color.
;
; Input : AL = ASCII Code of the character.
;         DI = Screen Offset Address where to print.
; Output: DI = Char position (Offset Address) on screen, for next printing.
;         DS, ES and SI preserveds.
;         AX, BX, CX and DX destroyed.
;-----------------------------------------------------------------------------
Draw_Char_Mode_13h:
; Saves All Original Values from Registers that Will Are Used  
    push  di                           ; Saves the printing offset address
    push  si
    push  ds
    push  es


; Gets Charset Bitmaps Table Address
; Also may be in F000h:FA6Eh BIOS address. (But is not 100% reliable!)  
    mov   ds,[cs:Charset_BMP_Seg]
    mov   si,[cs:Charset_BMP_Off]
    
; Gets the Character Bitmap Table Offset Address    
    xor   ah,ah                        ; AX = Character ASCII code
    shl   ax,1
    shl   ax,1
    shl   ax,1                         ; AX = ASCII * 8 (Each char fills 8 bytes)
    add   si,ax                        ; DS:SI = Address of the our character
                                       ; bitmap.
    mov   ax,0A000h
    mov   es,ax                        ; Points ES to VGA graphics segment

    mov   dx,312                       ; Skip line constant (320 - 8 dots)
;    mov   bh,0x0F                      ; XOR inverting mask (0x0F = Black/White)
    mov   bh,0x0E                      ; XOR inverting mask (0x0E = Blue/Yellow)
    mov   ch,8                         ; Initializes the rows counter


; Draws the Entire Character on Screen
Draw_Char_Loop:
    lodsb                              ; AL = Char bitmap row, SI = Next row
    mov   cl,8                         ; Char row 8 bits counter

Draw_Char_Row_Loop:
    shl   al,1                         ; Shifts bit to Carry Flag
    jnc   Draw_Char_Next_Bit           ; If bit is 0 (bg): do none

; If Bit is 1: Plots the Dot, Inverting the Screen Background Color
    mov   bl,[es:di]                   ; Gets the screen background pixel color.
    xor   bl,bh                        ; Invert pixel.
    mov   [es:di],bl                   ; Plots the inverted pixel color back
                                       ; on screen.
Draw_Char_Next_Bit:
    inc   di                           ; Increment the screen pointer (Axis X)
    dec   cl
    jnz   Draw_Char_Row_Loop           ; Processes all the 8 bits from
                                       ; character bitmap row.
    add   di,dx                        ; Skips to the next line on screen (Axis Y)
    dec   ch                           ; Decrement the rows counter.
    jnz   Draw_Char_Loop               ; Backs to plot the next char row, if 
                                       ; not printed all 8 rows from char.

; Restores All Original Values from Used Registers   
    pop   es
    pop   ds
    pop   si
    pop   di                           ; Restores the VGA printing offset
    add   di,8                         ; Next char position (VGA offset)
    ret


;-----------------------------------------------------------------------------
; Vars
;-----------------------------------------------------------------------------
    section .data                      ; (Nasm Directive) (Optional!)

;LFSR_Seed        dw 1                  ; LFSR seed NEVER must be 0, or
;                                       ; LFSR will freeze with zeros

Initial_Seed     dw 1                  ; Stores the randomized LFSR initial
                                       ; seed and used to check the restart
                                       ; of LFSR sequence

Charset_BMP_Seg  dw 0F000h             ; Segment of Charset Bitmaps Table (0F000h = BIOS Charset)
Charset_BMP_Off  dw 0FA6Eh             ; Offset Address of Charset Bitmaps (0FA6Eh = BIOS Charset)


Need_VGA_Msg     db 0Dh, 0Ah, "I need a VGA video card!", 0Dh, 0Ah, "$"

Msg_Full         db "The Screen is Full", 0
Msg_Clean        db "The Screen is Blank", 0

PGM_SIGNATURE    db "LFSR V3.1 10MAY2026"

