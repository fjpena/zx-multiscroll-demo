; B: new RAM page to put in  $C000 - $FFFF
; Assumes interrupts are disabled
setrambank:	
        ld a, (23388)		;System var with the previous value
		and $f8			;Preserve the high bits
		or b			;Set RAM page in B
		ld bc, $7ffd		;Port to write to
     	ld	(23388),a	;Update system var
     	out	(c),a		;Go
		ret		

setrambank_with_di:
        di
        call setrambank
        ei
        ret


; Switch the visible screen
; Assumes interrupts are disabled
		
switchscreen:	
        ld	a,(23388)	;System var with the previous value
   		xor	8		    ;switch screen
   		ld	bc,32765	;Port to write to
   		ld	(23388),a	;Update system var
   		out	(c),a		;Switch
		ret

setscreen0:
        ld	a,(23388)	;System var with the previous value
        and $f7         ; leave bit 3 as 0
   		ld	bc,32765	;Port to write to
   		ld	(23388),a	;Update system var
   		out	(c),a		;Switch
		ret

        
