; -------------------------------------------------------------------------
; Interleaved to Planar Mask Converter (Core)
; -------------------------------------------------------------------------
; A0 - Source (Scanline Interleaved: All P0-Line0, then all P1-Line0...)
; A1 - Destination (1-Plane Mask)
; D0 - Width in px (e.g., 128px)
; D1 - Height in lines (e.g., 128)
; D2 - Depth (e.g., 5)
; -------------------------------------------------------------------------

InterleavedToPlanarMask:
    movem.l d3-d7/a0/a1,-(sp)
	
	lsr.w   #4,d0

    move.w  d0,d7               ; Save width in words
    add.w   d7,d7               ; D7 = Bytes per line (e.g., 16)
    
    subq.w  #1,d1               ; Height loop
.line_loop:
    move.w  d0,d3               ; Word counter for this line
    subq.w  #1,d3
    
.word_loop:
    move.w  (a0),d5             ; Get word from Plane 0
    
    ; We use A2 as a temporary pointer to jump through planes
    move.l  a0,a2               
    move.w  d2,d4               ; Depth counter
    subq.w  #2,d4               ; Adjust for P0 and dbra
    bmi.s   .write_word

.or_planes:
    add.w   d7,a2               ; Jump to the same horizontal word in the NEXT plane
    or.w    (a2),d5             ; OR the bits
    dbra    d4,.or_planes

.write_word:
    move.w  d5,(a1)+            ; Save resulting mask word
    addq.l  #2,a0               ; Move source to next word in Plane 0
    dbra    d3,.word_loop

    ; At the end of a line, A0 is at the start of Plane 1, Line 0.
    ; We need to skip the remaining planes to get to Plane 0, Line 1.
    move.w  d2,d4               ; Get depth
    subq.w  #1,d4               ; Already processed 1 plane width via .word_loop
    mulu.w  d7,d4               ; Bytes to skip
    add.l   d4,a0               ; A0 now at start of next line, Plane 0
    
    dbra    d1,.line_loop

    movem.l (sp)+,d3-d7/a0/a1
    rts	
