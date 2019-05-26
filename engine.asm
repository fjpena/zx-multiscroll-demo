SCREEN_STILE_WIDTH EQU 13
STARTX_SCREEN EQU 32
STARTY_SCREEN EQU 8

prerotate_counter: db 0
prerotate_ntiles: db 0

curtile: db 0
map_offset: db 0
save_levelmap: dw 0

savesp: dw 0
savesp2: dw 0
savehl: dw 0
savebc: dw 0
curx:   db 0
curx_tile: db 3
previousx: db $ff
previousy: db $ff
previous_ysub: db $ff
cur_dispx: dw 288
cury: db 0
cury_tile: db 3
map_needs_update: db 0

; Prerotate tiles for map

PrerotateTiles:
        ld a, 10
        ld iy, tiles        ; First tile
        ld ix, tiles+96    ; First rotation
Prerotate_pertile:
        ld (prerotate_ntiles), a
        push iy
        push ix
        ld a, 3             ; 3 different rotations
Prerotate_outer:
        push af
        ld a, 16            ; 16 lines
Prerotate_inner:
        ld (prerotate_counter), a
        ld e, (iy+0)
        ld d, (iy+1)
        ld c, (iy+2)
        ld b, (iy+3)         
        ld l, (iy+4)
        ld h, (iy+5)         ; We get 6 bytes for a line
        ; Rotate 2 pixels to the right
        and a
        rr e
        rr d
        rr c
        rr b
        rr l
        rr h
        and a
        rr e
        rr d
        rr c
        rr b
        rr l
        rr h
        ; And store
        ld (ix+0), e
        ld (ix+1), d
        ld (ix+2), c
        ld (ix+3), b
        ld (ix+4), l
        ld (ix+5), h
        ld bc, 6
        add iy, bc
        add ix, bc      ; next line
        ld a, (prerotate_counter)
        dec a
        jr nz, Prerotate_inner
        pop af
        dec a
        jr nz, Prerotate_outer
        pop ix
        pop iy
        ld bc, 96*4       ; next tile
        add iy, bc
        add ix, bc
        ld a, (prerotate_ntiles)
        dec a
        jr nz, Prerotate_pertile
        ret


; Draw background map
; Variables:
;   - curx
;   - cur_dispx


DrawBkg: 
		ld de, tiletable
		ld (savesp), sp
        ld a, (curx)
        and $4
        rrca
        rrca
        ld c, a
        ld a, 30
        sub c
        ld c, a
        ld b, 0
;        ld hl, 16384+32
        ld hl, 49152+32
        add hl, bc

		exx
		ld bc, $0000
		exx

nxtmap: ld a, (de)
        ld (tilerw+1), a    ; Modify the low byte of the JP
        inc e
        ld a, (de)
        or a
        jr z, endmap
        ld (tilerw+2), a    ; Modify the high byte of the JP
        inc e

        ld a, (de)
        ld iyl, a
        inc e
        ld a, (de)
        ld iyh, a			; IY points to the first tile
        inc e
        ld a, (de)
        ld ixl, a
        inc e
        ld a, (de)
        ld ixh, a
        inc e
        ld a, (de)          ; number of lines to display of this stile
        ld (nxtrow+1), a
        ; 16-number of lines * 6 is the initial displacement (if this is the first line)
        ld c, a
        ld a, 16
        sub c
        add a, a            ; * 2
        ld c, a
        add a, a            ; * 4
        add a, c            ; * 6
        ld (savehl), hl
        ld hl, (cur_dispx)
        ld c, a
        ld b, 0
        add hl, bc
        ld c, l
        ld b, h
        ld hl, (savehl)
        inc e
        ld a, (de)
        and a
        jr z, nxt_start
        ld bc, (cur_dispx)  ; 0: displace 0, 96: 2 pixels, 192: 4 pixels, 288: 6 pixels
nxt_start:
        inc e
        add iy, bc			; IY points to the first tile + displacement
        add ix, bc			; IX points to the second tile + displacement
nxtrow: ld b, $16          ; Number of lines per stile
        ld a, b
        and a
        jr z, nxtmap
nxtln:  exx
        ld sp, iy          ; Get the next 6 bytes of tile into BC,DE and AF
        pop de
        pop hl
        pop af
        exx
        ld sp, hl          ; Point SP back into the screen area
        exx
tilerw: jp $0000           ; And go draw the next scanline

; Set up the data for the next scanline

nxtscn: ld de, $0006
        add iy, de         ; Step down one row in the tiles
        add ix, de
        exx                ; Switch in our working registers.
                           ; HL=Screen line, B=tile line, C=Tile row, DE=map
        inc h              ; Down one scanline in display
    	ld a,h
		and 7
		jr nz, nxt_nextthird		; if the low 3 bits of H are zero
nxt_nextchar:
        ld a, l
        add a, $20         ; Move down one screen row
        ld l, a
        jr c, nxt_nextthird        ; If carry then we crossed into the next third
        ld a, h            ; Otherwise we need to subtract 8 from H
        sub $08            ; to stay in the same screen segment
        ld h, a
nxt_nextthird:
        djnz nxtln         ; Retrieve tile data and draw another scanline
;inseg:  dec c
        jr nxtmap
;second_tile:
 ;       ld b, $00
  ;      jr nxtln
endmap: ld sp, (savesp)
        ret





; Prepare tables for next draw
; B': tile1
; C': tile2
; D': curtile
; A: offset in tiletable

PrepareMapUpdate:
        ld ix, tiletable+2
        ld de, line1
        ld (map_offset), a

        ld hl, levelmap
        ; Add Y offset
        ld a, (mapwidth)
        ld c, a
        ld b, 0
        ld a, (cury_tile)
        and a
        jr z, no_addy
addy_loop:
        add hl, bc
        dec a
        jr nz, addy_loop
no_addy:
        ; Add X offset
        ld a, (map_offset)
        add a, SCREEN_STILE_WIDTH - 1
        ld c, a
        ld b, 0
        add hl, bc
        ld b, 8     ; outer counter
prepare_outer_loop:
        ld (save_levelmap), hl
        ld a, $ff
        exx
        ld b, a
        ld c, a
        ld d, a
        exx
        ld c, SCREEN_STILE_WIDTH    ; inner counter
        push de
prepare_loop:
        ld a, (hl)
        and a
        jp z, prepare_tile_empty    ; not switching the tile for an empty one
        ex af, af'
        ld a, (hl)
        rrca
        rrca
        and $3f         ; Tile number / 4 is the actual 48x16 supertile        
        exx             ; alternate registers (tile1, tile2, curtile)
        cp d
        exx
        jp z, prepare_tile1_same  ; the same current tile, just push
        exx
        cp b            ; is it tile1?
        jr z, prepare_switch_tile1
        ; if it's not, this might be the first one
        ld h, b
        inc h
        jr nz, prepare_loop_is_it_tile2 ; so it's not the first time
        ; First tile and current tile is A
        ld b, a
        ld d, a
        ; Now calculate the address from the tile number
        ld h, a
        and 1           ; this resets the carry flag
        rrca
        ld (ix+0), a
        ld a, h
        srl a
        add a, h
        add a, $a0      ; Tiles start in $A000
        ld (ix+1), a
        jr prepare_tile1
prepare_loop_is_it_tile2:
        ;  this could be the first time the second tile is found
        ld h, c
        inc h
        jr nz, prepare_switch_tile2 ; so not the first time switch!        
        ; Second tile and current tile is A
        ld c, a
        ; Now calculate the address from the tile number
        ld h, a
        and 1
        rrca
        ld (ix+2), a
        ld a, h
        srl a
        add a, h
        add a, $a0      ; Tiles start in $A000
        ld (ix+3), a
        ld a, h         ; restore the value of A
        jr prepare_switch_tile2
prepare_switch_tile1:
        ld d, a     ; set the current tile
        ; We are going to insert the following sequence:
        ;         ld (savesp), sp           ED 73 xx yy
        ;         ld sp, iy                 FD F9
        ;         pop de                    D1
        ;         pop hl                    E1
        ;         pop af                    F1
        ;         ld sp, (savesp)           ED 7B xx yy
        exx
        ld (savehl), hl
        ld (savebc), bc
        ld hl, block_iy
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ld hl, (savehl)
        ld bc, (savebc)
        jr prepare_tile1_same
prepare_switch_tile2:
        ld d, a     ; set the current tile
        ; We are going to insert the following sequence:
        ;         ld (savesp), sp
        ;         ld sp, ix
        ;         pop de
        ;         pop hl
        ;         pop af
        ;         ld sp, (savesp)
        exx
        ld (savehl), hl
        ld (savebc), bc
        ld hl, block_ix
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        ld hl, (savehl)
        ld bc, (savebc)
        jr prepare_tile1_same
prepare_tile1:
        exx
prepare_tile1_same:
        ex af, af'
prepare_tile1_ok:
        and $3      ; (Tile AND 3) is the number to use in the push command
        rrca
        rrca
        rrca
        rrca        ; set it in bits 00xx0000
        or 11000101b    ; PUSH AF opcode is F5 (3), PUSH HL is E5 (2), PUSH DE is D5 (1), PUSH BC is C5 (0)
        ld (de), a      ; write the opcode
        inc de        
prepare_loop_next:
        dec hl
        dec c
        jr z, prepare_nextline
        jp prepare_loop
prepare_tile_empty:
        ld a, $C5   ; PUSH BC
        ld (de), a      ; write the opcode
        inc de        
        jr prepare_loop_next
prepare_nextline:
        ld a, $C3   ; JP XX
        ld (de), a
        inc de
        ld hl, nxtscn
        ld a, l
        ld (de), a
        inc de
        ld a, h
        ld (de), a
        ld de, 8
        add ix, de              ; next line
        pop de
        ld hl, 64
        add hl, de
        ex de, hl
        dec b
        ret z

        ld hl, (save_levelmap)
        push bc
        ld a, (mapwidth)
        ld c, a
        ld b, 0
        add hl, bc
        pop bc

        jp prepare_outer_loop

block_iy:                     ; 13 bytes
    ld (savesp2), sp           ; ED 73 xx yy
    ld sp, iy                 ; FD F9
    pop de                    ; D1
    pop hl                    ; E1
    pop af                    ; F1
    ld sp, (savesp2)           ; ED 7B xx yy

block_ix:                     ; 13 bytes
    ld (savesp2), sp           ; ED 73 xx yy
    ld sp, ix                 ; DD F9
    pop de                    ; D1
    pop hl                    ; E1
    pop af                    ; F1
    ld sp, (savesp2)           ; ED 7B xx yy



; Move Camera, based on the reference created by an entity
; INPUT:
;   - IX: Entity to use as a reference
MoveCamera:
    xor a
    ld (map_needs_update), a
    ; The X position is (curx_tile * 16) + curx*2
    ld h, (ix+1)
    ld l, (ix+2)        ; X in level coords
    ld bc, 88           ; FIXME magic constant
    and a
    sbc hl, bc          ; X - 88 is where the camera should be
    push hl
    ld a, l        ; to get curx we just need the low byte
    and $f
    rrca
    ld (curx), a
    and 3
    ld b, a
    ld a, 3
    sub b
    add a, a            ; (3-a) is the actual value
    ld hl, Multiply_by_96
    ld c, a
    ld b, 0
    add hl, bc		; HL points to the value in the array
    ld c, (hl)
    inc hl
    ld b, (hl)		; BC = 96 * xcounter & 3
    ld (cur_dispx), bc
    pop hl          ; now, divide by 16 to get curx_tile
    srl h
    rr l
    srl h
    rr l
    srl h
    rr l
    srl h
    rr l            ; X / 16 is the X coord in tiles
    ld a, l 
    ld (curx_tile), a
    ; The Y position is (cury_tile * 16) + cury
    ld h, (ix+3)
    ld l, (ix+4)        ; 4 in level coords
    ld bc, 48           ; FIXME magic constant
    and a
    sbc hl, bc          ; Y - 48 is where the camera should be
    ld a, l        ; to get curx we just need the low byte
    and $f
    ld (cury), a
    srl h
    rr l
    srl h
    rr l
    srl h
    rr l
    srl h
    rr l            ; Y / 16 is the Y coord in tiles
    ld a, l 
    ld (cury_tile), a
    ; Finally, check if we need to recalculate anything from the pop stuff
    ld a, (previousx)
    ld b, a
    ld a, (curx_tile)
    cp b       
    jr z, MoveCamera_noxchange
    ld (previousx), a
    ld a, 1
    ld (map_needs_update), a
MoveCamera_noxchange:
    ld a, (previousy)
    ld b, a
    ld a, (cury_tile)
    cp b
    jr z, MoveCamera_noychange
    ld (previousy), a
    ld a, 1
    ld (map_needs_update), a
MoveCamera_noychange:
    ; If the camera moved in Y, we need to adjust the tables too
    ld a, (previous_ysub)
    ld b, a
    ld a, (cury)
    cp b
    jr z, MoveCamera_end
    ld (previous_ysub), a
    ld (tiletable+8*7+6), a
    sub 16
    neg
    ld (tiletable+6), a
MoveCamera_end:
    ld a, (map_needs_update)
    and a
    ret z
    ld a, (curx_tile)
    call PrepareMapUpdate
    ret
