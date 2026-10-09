; ---------------------------------------------------------------
; HELLO WORLD - bouncing text demo for the ZX Spectrum 48K
;
; Draws "HELLO WORLD" straight into screen memory using the ROM
; font, then bounces it round the full 32x24 character grid like
; a DVD screensaver. It changes colour on every bounce. Press any
; key to quit back to BASIC.
;
; Loads and runs at 32768 (RANDOMIZE USR 32768).
; ---------------------------------------------------------------

        ORG     32768

SCREEN  EQU     0x4000          ; pixel memory
ATTRS   EQU     0x5800          ; colour attributes
FONT    EQU     0x3C00          ; ROM font: 8 bytes per character, code 0 first
BORDCR  EQU     0x5C48          ; system variable holding the BASIC border colour
CLS     EQU     0x0D6B          ; ROM routine: clear the screen

MSGLEN  EQU     11              ; length of the message (excluding the 0 terminator)
MAXX    EQU     32-MSGLEN       ; right-most column the text can start on
MAXY    EQU     23              ; bottom row
FRAMES  EQU     4               ; 50Hz frames between moves (higher = slower)

start:
        xor     a
        out     (0xFE),a        ; black border

        ld      hl,SCREEN       ; wipe the pixels
        ld      de,SCREEN+1
        ld      bc,0x17FF
        ld      (hl),0
        ldir

        ld      hl,ATTRS        ; white ink on black paper everywhere
        ld      de,ATTRS+1
        ld      bc,0x02FF
        ld      (hl),7
        ldir

wait_release:                   ; ignore the ENTER key that started us
        call    read_keys
        jr      nz,wait_release

main:
        halt                    ; sync to the 50Hz frame interrupt
        call    read_keys
        jr      nz,quit         ; any key -> back to BASIC

        ld      hl,delay        ; only move every FRAMES frames
        dec     (hl)
        jr      nz,main
        ld      (hl),FRAMES

        call    erase
        call    step
        call    draw
        jr      main

quit:
        call    CLS
        ld      a,(BORDCR)      ; put the BASIC border colour back
        and     0x38
        rrca
        rrca
        rrca
        out     (0xFE),a
        ret

; ---------------------------------------------------------------
; read_keys: Z set if no key is pressed
; ---------------------------------------------------------------
read_keys:
        xor     a
        in      a,(0xFE)        ; A=0 selects every keyboard half-row at once
        and     0x1F            ; a 0 bit means a key is down
        cp      0x1F
        ret

; ---------------------------------------------------------------
; step: move one cell diagonally, bouncing off the edges
; ---------------------------------------------------------------
step:
        ld      a,(posx)
        ld      hl,dirx
        add     a,(hl)
        ld      (posx),a
        or      a               ; hit the left edge?
        jr      z,bounce_x
        cp      MAXX            ; hit the right edge?
        jr      nz,step_y
bounce_x:
        ld      a,(hl)          ; reverse horizontal direction
        neg
        ld      (hl),a
        call    next_colour

step_y:
        ld      a,(posy)
        ld      hl,diry
        add     a,(hl)
        ld      (posy),a
        or      a               ; hit the top?
        jr      z,bounce_y
        cp      MAXY            ; hit the bottom?
        ret     nz
bounce_y:
        ld      a,(hl)          ; reverse vertical direction
        neg
        ld      (hl),a
        ; fall through to next_colour

next_colour:                    ; ink cycles 1..7 (blue .. white)
        ld      a,(ink)
        inc     a
        cp      8
        jr      c,colour_ok
        ld      a,1
colour_ok:
        ld      (ink),a
        ret

; ---------------------------------------------------------------
; erase: blank the pixels of the text at its current position
; ---------------------------------------------------------------
erase:
        ld      a,(posy)
        ld      b,a
        ld      a,(posx)
        ld      c,a
        call    cell_addr
        ld      c,MSGLEN
erase_cell:
        push    hl
        ld      b,8
        xor     a
erase_line:
        ld      (hl),a
        inc     h               ; next pixel line is 256 bytes on
        djnz    erase_line
        pop     hl
        inc     l
        dec     c
        jr      nz,erase_cell
        ret

; ---------------------------------------------------------------
; draw: colour the cells, then blit each glyph from the ROM font
; ---------------------------------------------------------------
draw:
        ld      a,(posy)
        ld      b,a
        ld      a,(posx)
        ld      c,a

        call    attr_addr       ; HL = attribute address (B, C preserved)
        ld      a,(ink)
        or      0x40            ; BRIGHT, black paper
        ld      d,MSGLEN
draw_attr:
        ld      (hl),a
        inc     l
        dec     d
        jr      nz,draw_attr

        call    cell_addr       ; HL = pixel address of first cell
        ld      de,msg
draw_char:
        ld      a,(de)
        or      a
        ret     z               ; 0 terminator
        inc     de
        ld      c,a             ; BC = FONT + code*8
        ld      b,0
        sla     c
        rl      b
        sla     c
        rl      b
        sla     c
        rl      b
        ld      a,b
        add     a,FONT>>8
        ld      b,a
draw_line:
        ld      a,(bc)
        ld      (hl),a
        inc     bc
        inc     h
        ld      a,c
        and     7               ; 8 bytes copied when low 3 bits wrap to 0
        jr      nz,draw_line
        ld      a,h             ; back up to the top of the cell
        sub     8
        ld      h,a
        inc     l               ; next column
        jr      draw_char

; ---------------------------------------------------------------
; cell_addr: B=row (0-23), C=column (0-31) -> HL = pixel address
; attr_addr: B=row, C=column -> HL = attribute address
; Both preserve B and C.
; ---------------------------------------------------------------
cell_addr:
        ld      a,b
        and     0x18            ; which third of the screen
        or      0x40
        ld      h,a
        ld      a,b
        and     7               ; row within the third, times 32
        rrca
        rrca
        rrca
        add     a,c
        ld      l,a
        ret

attr_addr:
        ld      a,b             ; row*32 = (row>>3)*256 + (row&7)*32
        rrca
        rrca
        rrca
        ld      l,a
        and     3
        or      0x58
        ld      h,a
        ld      a,l
        and     0xE0
        add     a,c
        ld      l,a
        ret

; ---------------------------------------------------------------
; data
; ---------------------------------------------------------------
msg:    DB      "HELLO WORLD",0
posx:   DB      5
posy:   DB      3
dirx:   DB      1               ; +1 or 255 (-1)
diry:   DB      1
ink:    DB      2
delay:  DB      1
