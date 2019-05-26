org 24576
INCLUDE "input.asm"
INCLUDE "im2.asm"
INCLUDE "entities.asm"
INCLUDE "depack.asm"
INCLUDE "rambank.asm"
END_P1:

org $8000
IM2table: ds 257         ; IM2 table (reserved)

start_game:

set_interrupt:
        ld a, 0x9a
        ld hl, 0x8000
        ld de, ISR
        call SetIM2

pre_begin:
        xor a
        call LoadLevel

        ld hl, marco
        call depack_to_both_screens
        call setscreen0

        call InitSprCacheList
        call PrerotateTiles
        call InitEntities

        call InitPlayer
        call MoveCamera

        ld a, (curx_tile)        ; bit 0-1 is the displacement, bit 2 the start tile
        call PrepareMapUpdate
begin:
        ld a, (current_screen_bank)
        ld b, a
        call setrambank_with_di

        ; Draw current frame
    	di
;        ld a, 3
;        out ($fe), a
        call DrawBkg
		ei
;        ld a, 2
;        out ($fe), a
        call DrawEntities
;        xor a
;        out ($fe), a
        ld b, 0
        call setrambank_with_di ; For the rest of the frame, we want to use RAM bank 0

        ; Prepare next frame
        ld a, 3
        ld hl, key_defs
        call get_joystick   ; we get the result in A
        ld (joystick_state), a
        and 1
        jr nz, begin_noack
        xor a
        ld (jump_ack), a
begin_noack:
        call ProcessActions
        call ApplyGravity
        call MoveEntities
        ld ix, EntityList       ; Use the player as reference
        call MoveCamera     ; Finally, adjust camera to keep player in centre

        halt
        call switchscreen
        ld a, (current_screen_bank)
        xor 2               ; switch from 5 to 7
        ld (current_screen_bank), a
        jr begin

        
ISR:
    ret

; Random routine from http://wikiti.brandonw.net/index.php?title=Z80_Routines:Math:Random
;-----> Generate a random number
; ouput a=answer 0<=a<=255
; all registers are preserved except: af

random:
        push    hl
        push    de
        ld      hl,(randData)
        ld      a,r
        ld      d,a
        ld      e,(hl)
        add     hl,de
        add     a,l
        xor     h
        ld      (randData),hl
        pop     de
        pop     hl
        ret


; Load level
; INPUT:
; - A: level to load
LoadLevel:
    push af
    call setscreen0
    call switchscreen
    ld b, 6
    call setrambank_with_di   
    pop af
    add a, a
    ld e, a
    ld d, 0
    ld hl, 49152
    add hl, de
    ld e, (hl)
    inc hl
    ld d, (hl)
    ex de, hl       ; HL points to the packed level
    ld de, 16384
    call depack

    ld b, 0
    call setrambank_with_di
    ld hl, 16384
    ld de, $c000 ;$d000
    ld bc, 4096
    ldir
    call setscreen0
    ret

current_screen_bank: db 7
jump_ack: db 0
joystick_state: db 0
key_defs: dw KEY_Q, KEY_A, KEY_O, KEY_P, KEY_SPACE, KEY_CAPS
randData: dw 42


INCLUDE "engine.asm"
INCLUDE "drawsprite.asm"

line1:
    ds 64
line2:
    ds 64
line3:
    ds 64
line4:
    ds 64
line5:
    ds 64
line6:
    ds 64
line7:
    ds 64
line8:
    ds 64
END_P2:

org $99c0
tiletable:
; Code address, tile1 address, tile2 address, (lastline, rows)
dw line1, $0000, $0000, $0010
dw line2, $0000, $0000, $0010
dw line3, $0000, $0000, $0010
dw line4, $0000, $0000, $0010
dw line5, $0000, $0000, $0010
dw line6, $0000, $0000, $0010
dw line7, $0000, $0000, $0010
dw line8, $0000, $0000, $0100
dw $0000



org $a000
tiles:
INCLUDE "tile1.asm"
org $a180                   ; 384 bytes per 48x16 tile (with 4 different rotations)
INCLUDE "tile2.asm"
org $a300
INCLUDE "tile3.asm"
org $a480
INCLUDE "tile4.asm"
org $a600
INCLUDE "tile5.asm"
org $a780
INCLUDE "tile6.asm"
org $a900
INCLUDE "tile7.asm"
org $aa80
INCLUDE "tile8.asm"
org $ac00
INCLUDE "tile9.asm"
org $ad80
INCLUDE "tile10.asm"


org $c000
mapwidth: db 0
mapheight: db 0
start_x: dw 0
start_y: dw 0
ptr_levelscript: dw 0
levelmap: ds 4096-8


org $e000
marco:
INCBIN "marco.pck"
