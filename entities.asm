; Entity structure:
;
; - Byte 0: sprnum (0-63), $ff is inactive
; - Byte 1-2: x (in level coords)       ; FIXME: we are storing it in the wrong order
; - Byte 3-4: y (in level coords)       ; FIXME: we are storing it in the wrong order
; - Byte 5: flags
;          bit 0: gravity applies to this entity
; - Byte 6: state
; - Byte 7: x speed
; - Byte 8: y speed
; - Byte 9: x acceleration
; - Byte 10: y acceleration
; - Byte 11: params1
; - Byte 12: for enemies, number in enemy table
; - Byte 13: for enemies, number of hits to receive until it goes dizzy
; - Byte 14: params2
; - Byte 15: reserved

MAX_ENTITIES EQU 16
ENTITY_SIZE EQU 16

FLAG_ENTITY_NONE    EQU 0
FLAG_GRAVITY_ON     EQU 1
FLAG_CROSS_WALLS    EQU 2

STATE_IDLE_LEFT     EQU 0
STATE_IDLE_RIGHT    EQU 1
STATE_FALL_LEFT     EQU 2
STATE_FALL_RIGHT    EQU 3
STATE_JUMP_LEFT     EQU 4
STATE_JUMP_RIGHT    EQU 5
STATE_WALK_LEFT     EQU 6
STATE_WALK_RIGHT    EQU 7

SPRITE_IDLE_LEFT_1      EQU 0
SPRITE_IDLE_LEFT_2      EQU 1
SPRITE_WALK_LEFT_1      EQU 1
SPRITE_WALK_LEFT_2      EQU 2
SPRITE_JUMP_LEFT        EQU 2
SPRITE_IDLE_RIGHT_1     EQU 3
SPRITE_IDLE_RIGHT_2     EQU 4
SPRITE_WALK_RIGHT_1     EQU 4
SPRITE_WALK_RIGHT_2     EQU 5
SPRITE_JUMP_RIGHT       EQU 5


GRAVITY EQU 1

EntityList: ds MAX_ENTITIES * ENTITY_SIZE     ; 256 bytes for active entities?
current_screen_x: dw 0
current_screen_y: dw 0
state_functions: dw state_idle, state_fall, state_jump, state_walk


InitEntities:
    ld hl, EntityList
    ld de, EntityList + 1
    ld a, $ff
    ld (hl), a
    ld bc, MAX_ENTITIES*ENTITY_SIZE-1
    ldir
    ret 

InitPlayer:
    ld ix, EntityList
    ld de, (start_x)
    ld (ix+1), d
    ld (ix+2), e
    ld de, (start_y)
    ld (ix+3), d
    ld (ix+4), e
    ld (ix+5), FLAG_GRAVITY_ON
    ld (ix+0), SPRITE_IDLE_RIGHT_1        ; idle player
    ld (ix+6), STATE_IDLE_RIGHT
state_set_idle_common:
    xor a
    ld (ix+7), a        ; Initially, all speeds and accelerations are 0
    ld (ix+8), a
    ld (ix+9), a
    ld (ix+10), a
    ld (ix+11), 24
state_none:
    ret

; Create a new entity
; OUTPUT:
;   - ix: pointer to new entity, $0000 if no entity can be allocated
NewEntity:
    ld ix, EntityList+ENTITY_SIZE
    ld b, MAX_ENTITIES-1
    ld de, ENTITY_SIZE
NewEntity_loop:
    ld a, (ix+0)
    cp $ff
    jr z, state_set_idle_common ; we will return ix with the new entity, and some common stuff will be pre-allocated for us
NewEntity_next:
    dec b
    jr z, NewEntity_NoEntity
    add ix, de
    jr NewEntity_loop
NewEntity_NoEntity:
    ld ix, 0
    ret

state_set_idle:
    ld a, (ix+6)
    and 1
    add a, STATE_IDLE_LEFT
    ld (ix+6),a
    and a
    jr nz, sprite_set_idle_right
sprite_set_idle_left:
    ld (ix+0), SPRITE_IDLE_LEFT_1        ; idle player
    jp state_set_idle_common
sprite_set_idle_right:
    ld (ix+0), SPRITE_IDLE_RIGHT_1        ; idle player
    jp state_set_idle_common

; Calculate the current screen coordinates
CalcCurScrCoords:
    ld a, (curx)
    rlca            ; curx*2 = pixel position
    ld e, a
    ld d, 0
    ld a, (curx_tile)
    ld l, a
    ld h, 0
    add hl, hl
    add hl, hl
    add hl, hl
    add hl, hl  ; curx_tile * 16 is the pixel position
    add hl, de  ; (curx_tile * 16) + curx*2
    ld (current_screen_x), hl
    ld a, (cury)
    ld e, a     ; D is already 0
    ld a, (cury_tile)
    ld l, a
    ld h, 0
    add hl, hl
    add hl, hl
    add hl, hl
    add hl, hl  ; cury_tile * 16 is the pixel position
    add hl, de  ; (cury_tile * 16) + cury
    ld (current_screen_y), hl
    ret

DrawEntities:
    ; First, calculate pixel position of upper-left corner
    call CalcCurScrCoords
    ld ix, EntityList + MAX_ENTITIES*(ENTITY_SIZE-1)
    ld a, MAX_ENTITIES
DrawEntities_Loop:
    push af
    ld a, (ix+0)
    cp $ff
    jr z, DrawEntities_Next
    ex af, af'
    call EntityInScreen ; check if entity is in the screen, will set carry flag if not
    jr c, DrawEntities_Next
    ex af, af'
    ; Draw entity
    ld e, a
    ld d, 0
    exx
    and a               ; reset carry flag
    ld h, (ix+1)
    ld l, (ix+2)        ; X in level coords
    ld bc, (current_screen_x)
    sbc hl, bc         
    ld a, l
    exx
    add a, STARTX_SCREEN           ;  Start X position of the window
    ld b, a
    exx
    and a               ; reset carry flag
    ld h, (ix+3)
    ld l, (ix+4)        ; Y in level coords
    ld bc, (current_screen_y)
    sbc hl, bc         
    ld a, l
    exx
    add a, STARTY_SCREEN           ; Start Y position of the window
    ld c, a
    push ix
    call DrawSprite
    pop ix
DrawEntities_Next:
    ld bc, -ENTITY_SIZE
    add ix, bc
    pop af
    dec a
    jr nz, DrawEntities_Loop
    ret

; Check if entity is to be shown in the screen
; INPUT:
;   - IX: pointer to entity
; OUTPUT:
;   - Carry flag set: should be clipped
;   - Carry flag not set: in screen
EntityInScreen:
    and a               ; reset carry flag
    ld h, (ix+1)
    ld l, (ix+2)        ; X in level coords
    ld bc, 8
    add hl, bc
    ld bc, (current_screen_x)
    sbc hl, bc          ; if hl < 0, do not draw. If hl > 200, do not draw
    jp m, Entity_DoNotDraw  ; HL < 0
    ld a, h
    and a
    jr nz, Entity_DoNotDraw
    ld a, l
    cp 200
    jr nc, Entity_DoNotDraw
    and a               ; reset carry flag
    ld h, (ix+3)
    ld l, (ix+4)        ; Y in level coords
    ld bc, 8
    add hl, bc
    ld bc, (current_screen_y)
    sbc hl, bc          ; if hl < 0, do not draw. If hl > 112, do not draw
    jp m, Entity_DoNotDraw  ; HL < 0
    ld a, h
    and a
    jr nz, Entity_DoNotDraw
    ld a, l
    cp 112
    jr nc, Entity_DoNotDraw
    xor a               ; Ok, it fits in the screen
    ret
Entity_DoNotDraw:
    scf
    ret

; Check all objects, apply gravity to them if needed
ApplyGravity:
    ld ix, EntityList
    ld a, MAX_ENTITIES
ApplyGravity_Loop:
    push af
    ld a, (ix+0)
    cp $ff
    jp z, ApplyGravity_Next
    ld a, (ix+5)
    and 1                       ; if bit 0 of flags is 0, no gravity applies
    jr z, ApplyGravity_Next
    ld de, 16
    call Entity_CanMoveInY
    jr nc, ApplyGravity_Next
ApplyGravity_Fall:
    ld (ix+10), GRAVITY
    ; If we are jumping, we want to apply gravity but NOT change the state to falling
    ld a, (ix+6)
    and $fe
    cp STATE_JUMP_LEFT
    jr z, ApplyGravity_Next
    ld a, (ix+6)
    and 1
    add a, STATE_FALL_LEFT
    ld (ix+6), a
ApplyGravity_Next:
    ld bc, ENTITY_SIZE
    add ix, bc
    pop af
    dec a
    jp nz, ApplyGravity_Loop
    ret


; Process actions for all entities

ProcessActions:
    ld ix, EntityList
    ld a, MAX_ENTITIES
ProcessActions_Loop:
    push af
    ld a, (ix+0)
    cp $ff
    jr z, ProcessActions_Next
    call ProcessAction
ProcessActions_Next:
    ld bc, ENTITY_SIZE
    add ix, bc
    pop af
    dec a
    jr nz, ProcessActions_Loop
    ret

; Process input events for this entity
;
; INPUT:
;   - IX: pointer to entity
;   - joystick_state: joystick state:
; Bit #:  76     5     4   3210
;         ||     |     |   ||||
;         XX 	BUT2  BUT1 RLDU
ProcessAction:
    ld a, (ix+6)    ; Get state
    and $fe         ; The low bit just indicates if we are looking left or right
    ld c, a
    ld b, 0
    ld hl, state_functions
    add hl, bc              ; HL gets the pointer to the function
    ld e, (hl)
    inc hl
    ld d, (hl)              ; DE now has the address
    ld (ProcessAction_call+1), de
ProcessAction_call:
    jp 0                  ; and jump to the function


state_idle:
    ld a, (joystick_state)
    bit 0, a
    jp nz, state_idle_jump
    bit 2, a
    jp nz, state_idle_left
    bit 3, a
    jp nz, state_idle_right
    ; If we do nothing, keep on with our idle routine
    ld a, (ix+11)
    dec a
    ld (ix+11), a
    ret nz
    ld (ix+11), 24    
    ld a, (ix+0)
    cp SPRITE_IDLE_LEFT_2
    jr z, state_idle_left1
    cp SPRITE_IDLE_RIGHT_2
    jr z, state_idle_right1
    inc a
    ld (ix+0), a
    ret
state_idle_left1:
    ld (ix+0), SPRITE_IDLE_LEFT_1
    ret
state_idle_right1:
    ld (ix+0), SPRITE_IDLE_RIGHT_1
    ret                     


state_idle_jump:
    bit 2, a
    jr nz, state_idle_jump_left
    bit 3, a
    jr nz, state_idle_jump_right
state_idle_jump_up:
    ld a, (jump_ack)
    and a
    ret nz              ; we need to wait until the player releases the jump key before jumping again
    ld a, 1
    ld (jump_ack), a
    ld a, (ix+6)
    and 1
    add a, STATE_JUMP_LEFT
    ld (ix+6), a
    ld (ix+8), -8 ; Y speed
    ld (ix+11), 8  ; max number of frames to keep the Y speed
    ret
state_idle_left:
    ; Now set the speed
    ld (ix+0), SPRITE_WALK_LEFT_1
    ld (ix+6), STATE_WALK_LEFT
    ld (ix+7), -2
    ld (ix+11), 4   ; number of frames waiting for the next frame
    ret
state_idle_right:
    ; Now set the speed
    ld (ix+0), SPRITE_WALK_RIGHT_1
    ld (ix+6), STATE_WALK_RIGHT
    ld (ix+7), 2
    ld (ix+11), 4   ; number of frames waiting for the next frame
    ret
state_idle_jump_left:
    ld a, (jump_ack)
    and a
    ret nz              ; we need to wait until the player releases the jump key before jumping again
    ld a, 1
    ld (jump_ack), a
    ld (ix+0), SPRITE_JUMP_LEFT
    ld (ix+6), STATE_JUMP_LEFT
    ld (ix+7), -2
    ld (ix+8), -8 ; Y speed
    ld (ix+11), 8  ; max number of frames to keep the Y speed
    ret
state_idle_jump_right:
    ld a, (jump_ack)
    and a
    ret nz              ; we need to wait until the player releases the jump key before jumping again
    ld a, 1
    ld (jump_ack), a
    ld (ix+0), SPRITE_JUMP_RIGHT
    ld (ix+6), STATE_JUMP_RIGHT
    ld (ix+7), 2
    ld (ix+8), -8 ; Y speed
    ld (ix+11), 8  ; max number of frames to keep the Y speed
    ret

state_fall:
    ld a, (joystick_state)
    bit 2, a
    jr nz, state_fall_left
    bit 3, a
    jr nz, state_fall_right
    ret
state_fall_left:
    ld (ix+0), SPRITE_JUMP_LEFT
    ld (ix+6), STATE_FALL_LEFT
    ld (ix+7), -2
    ret
state_fall_right:
    ld (ix+0), SPRITE_JUMP_RIGHT
    ld (ix+6), STATE_FALL_RIGHT
    ld (ix+7), 2
    ret


state_jump:
    ld a, (ix+11)
    and a
    jr z, state_jump_next
    dec a
    ld (ix+11), a
    ld a, (joystick_state)
    bit 0, a
    jr z, state_jump_next
    ld (ix+8), -8  ; keep the Y speed for a while  FIXME magic constant
state_jump_next:
    ld a, (joystick_state)
    bit 2, a
    jr nz, state_jump_left
    bit 3, a
    jr nz, state_jump_right
    ret
state_jump_left:
    ld (ix+0), SPRITE_JUMP_LEFT
    ld (ix+6), STATE_JUMP_LEFT
    ld (ix+7), -2
    ret
state_jump_right:
    ld (ix+0), SPRITE_JUMP_RIGHT
    ld (ix+6), STATE_JUMP_RIGHT
    ld (ix+7), 2
    ret

state_walk:
    ld a, (joystick_state)
    bit 0, a
    jp nz, state_idle_jump  ; we are sharing the state handling
    bit 2, a
    jr nz, state_walk_left
    bit 3, a
    jr nz, state_walk_right
    call state_set_idle
    ret
state_walk_left:
    ld a, (ix+11)
    dec a
    ld (ix+11), a
    jr nz, state_walk_left_done
    ld (ix+11), 4
    ld a, (ix+0)
    cp SPRITE_WALK_LEFT_1
    jr nz, state_walk_left_1
    ld (ix+0), SPRITE_WALK_LEFT_2
    jr state_walk_left_done
state_walk_left_1:
    ld (ix+0), SPRITE_WALK_LEFT_1
state_walk_left_done:
    ld (ix+6), STATE_WALK_LEFT
    ld (ix+7), -2
    ret
state_walk_right:
    ld a, (ix+11)
    dec a
    ld (ix+11), a
    jr nz, state_walk_right_done
    ld (ix+11), 4
    ld a, (ix+0)
    cp SPRITE_WALK_RIGHT_1
    jr nz, state_walk_right_1
    ld (ix+0), SPRITE_WALK_RIGHT_2
    jr state_walk_right_done
state_walk_right_1:
    ld (ix+0), SPRITE_WALK_RIGHT_1
state_walk_right_done:
    ld (ix+6), STATE_WALK_RIGHT
    ld (ix+7), 2
    ret

; Process movement for all entities, considering speed, acceleration and environment
MoveEntities:
    ld ix, EntityList
    ld a, MAX_ENTITIES
MoveEntities_Loop:
    push af
    ld a, (ix+0)
    cp $ff
    jr z, MoveEntities_Next
    ; First, add acceleration to speed
    ld a, (ix+8)
    add a, (ix+10)
    ld (ix+8), a        ; Y
    ld a, (ix+7)
    add a, (ix+9)
    ld (ix+7), a        ; X
    ; Now, check if X movement is possible
    and a
    jr z, MoveEntities_Y_start ; If the X speed is 0, just go
    bit 7, a             ; This is a negative movement, we want to move that number of pixels in X
    jr z, MoveEntities_X_positive
MoveEntities_X_negative:
    call AtoDEextendsign    ; Move A to DE, keeping sign
	jr MoveEntities_X_go
MoveEntities_X_positive:
    add a, 8            ; we need to add this to the check
    ld e, a
    ld d, 0
MoveEntities_X_go:
    call Entity_CanMoveInX
    jr nc, MoveEntities_Y_start
    ; Ok, so we can move in X, lets apply it
    ld h, (ix+1)
    ld l, (ix+2)        ; X in level coords
    ld a, (ix+7)
    call AtoDEextendsign ; Convert to 16bit signed
    add hl, de
    ld (ix+1), h
    ld (ix+2), l
MoveEntities_Y_start:
    ; Finally, check if Y movement is possible
    ld a, (ix+8)    ; Y speed
    and a
    jr z, MoveEntities_Next ; skip if Y speed is 0
    ; For the Y movemement, we have to go in amounts of 2 pixels
    bit 7, a
    jr z, MoveEntities_Y_Down
    call Entity_MoveUp
    jr nc, MoveEntities_Y_SetIdle
    jr MoveEntities_Next
MoveEntities_Y_Down:
    call Entity_MoveDown
    jr nc, MoveEntities_Y_SetIdle
    jr MoveEntities_Next
MoveEntities_Y_SetIdle:
    call state_set_idle
    jr MoveEntities_Next
MoveEntities_Next:
    ld bc, ENTITY_SIZE
    add ix, bc
    pop af
    dec a
    jr nz, MoveEntities_Loop
    ret

    
Entity_MoveUp:
    ld a, (ix+8)    ; Get speed
Entity_MoveUp_Loop:
    push af
    call AtoDEextendsign    ; Move A to DE, keeping sign
    call Entity_CanMoveInY
    jr nc, Entity_MoveUp_Exit          ; If we cannot move, just return here
    ; We can move, decrease Y
    ld h, (ix+3)
    ld l, (ix+4)        ; Y in level coords
    dec hl
    ld (ix+3), h
    ld (ix+4), l
    pop af
    ; Now, A-1 and see if we should continue
    inc a
    jr nz, Entity_MoveUp_Loop
    scf         ; Set carry flag to indicate we were able to move without hitting anything
    ret
Entity_MoveUp_Exit:
    pop af      ; To avoid a heap error
    scf         ; We still allow the player to move and not go idle
    ret

Entity_MoveDown:
    ld a, (ix+8)    ; Get speed
Entity_MoveDown_Loop:
    push af
    ld de, 15       ; We check the speed in amounts of 1 pixel
    call Entity_CanMoveInY
    jr nc, Entity_MoveDown_Exit          ; If we cannot move, just return here
    ; We can move, increase Y
    ld h, (ix+3)
    ld l, (ix+4)        ; X in level coords
    inc hl
    ld (ix+3), h
    ld (ix+4), l
    pop af
    ; Now, A-1 and see if we should continue
    dec a
    jr nz, Entity_MoveDown_Loop
    scf         ; Set carry flag to indicate we were able to move without hitting anything
    ret
Entity_MoveDown_Exit:
    pop af      ; To avoid a heap error
    xor a
    ret

; INPUT:
;   - IX: pointer to entity
;   - DE: value to move in X (if positive, +8)
; OUTPUT:
;   - Carry flag on: can move
;   - Carry flag off: cannot move
Entity_CanMoveInX:
    push de
    ld h, (ix+1)
    ld l, (ix+2)        ; X in level coords
    add hl, de          ; Increase X
    ld d, (ix+3)
    ld e, (ix+4)        ; Y in level coords
    call GetMapPos      ; Get the value in A
    pop de
    dec a
    and $fc
    jr z, E_CMC_CannotMove ; FIXME: we are hardcoding only tile 1 to be "hard"
    ; We now need to calculate for Y + 14, DE is still in effect
    ld h, (ix+1)
    ld l, (ix+2)        ; X in level coords
    add hl, de
    ld d, (ix+3)
    ld e, (ix+4)        ; Y in level coords
    ex de, hl
    ld bc, 14
    add hl, bc
    ex de, hl
    call GetMapPos      ; Get the value in A
    dec a
    and $fc
    jr z, E_CMC_CannotMove ; FIXME: we are hardcoding only tile 1 to be "hard"
    scf
    ret
E_CMC_CannotMove:
    xor a
    ret


; INPUT:
;   - IX: pointer to entity
;   - DE: value to move in Y (if positive, +14)
; OUTPUT:
;   - Carry flag on: can move
;   - Carry flag off: cannot move

Entity_CanMoveInY:
    push de
    ld h, (ix+3)
    ld l, (ix+4)        ; Y in level coords
    add hl, de
    ld d, (ix+1)
    ld e, (ix+2)        ; X in level coords
    ex de, hl           ; HL: X in level coords, DE: Y + delta in level coords
    call GetMapPos
    pop bc
    dec a
    and $fc
    jr z, Entity_CannotMoveY ; FIXME: we are hardcoding only tile 1 to be "hard"
    ; Let's check on the same Y, and X+8
    ld d, (ix+1)
    ld e, (ix+2)        ; X in level coords
    ld h, (ix+3)
    ld l, (ix+4)        ; Y in level coords
    add hl, bc
    ex de, hl           ; HL: X in level coords, DE: Y + delta in level coords
    ; There is some "magic" involved in this 8. TL;DR: we are actually drawing the background
    ; 6 pixels to the right, due to the scrolling technique. Every screen space calculation
    ; needs to keep this in mind, and in this case we MUST do it, to avoid visual artifacts
    ld bc, 8
    add hl, bc          ; HL: X+8 in level coords, DE: Y + 16 in level coords 
    call GetMapPos
    dec a
    and $fc
    jr z, Entity_CannotMoveY ; FIXME: we are hardcoding only tile 1 to be "hard"
Entity_WillMoveY:
    scf
    ret
Entity_CannotMoveY:
    xor a
    ret


; Get tile value from a position in the map
; - INPUT:
;   HL: X position (in map absolute coords)
;   DE: Y position (in map absolute coords)
;
; - OUTPUT:
;   A: tile from map

GetMapPos:
    srl h
    rr l
    srl h
    rr l
    srl h
    rr l
    srl h
    rr l            ; X / 16 is the X coord in tiles
    ld c, l         ; and we can only have up to 256 tiles in X or Y, so it is safe

    srl d
    rr e
    srl d
    rr e
    srl d
    rr e
    srl d
    rr e            ; X / 16 is the / coord in tiles
    ld b, e         ; So C: X coord in tiles , B: Y coord in tiles

    ld iy, levelmap
    push bc
    ld b, 0
    add iy, bc      ; levelmap + X
    pop bc
    ld a, b         ; A: Y coord in tiles, we need to multiply by mapwidth
    and a
    jr z, GetMapPos_Y0
    ex af, af'
    ld a, (mapwidth)
    ld c, a
    ld b, 0
    ld hl, 0
    ex af, af'
GetMapPos_multiply:
    add hl, bc
    dec a
    jr nz, GetMapPos_multiply
GetMapPos_Y0:
    ld c, l
    ld b, h
    add iy, bc      ; iy points to the point in the map
    ld a, (iy+0)
    ret

AtoDEextendsign:
    ; We are extending the sign to DE, using a trick from http://wikiti.brandonw.net/index.php?title=Z80_Routines:Math:Signed_Math
    ld e, a
	rlca		; or rla
	sbc a, a
	ld d, a
    ret
