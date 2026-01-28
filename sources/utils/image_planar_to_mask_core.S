; ---------------------------------------------------------------------------
; Image planar to Mask (PlanMask): Generates a 1-bit mask from a multi-plane image
; Inputs:
; A0 - Pointer to Source Planar Image
; A1 - Pointer to Destination Mask Buffer
; D0 - Width in pixels (should be multiple of 16 for this word-based routine)
; D1 - Height in pixels
; D2 - Depth (number of bitplanes)
; ---------------------------------------------------------------------------

CreatePlanarMask:
    movem.l d0-d7/a0-a2,-(sp)   ; Save all used registers

    ; 1. Calculate Words Per Plane
    lsr.w   #4,d0               ; D0 = Width in WORDS (Pixels / 16)
    mulu.w  d1,d0               ; D0 = Total WORDS per bitplane
    move.l  d0,d3               ; D3 = Word count for loop
    
    ; 2. Calculate Plane Offset in Bytes
    move.l  d0,d4
    add.l   d4,d4               ; D4 = Bytes per plane (Words * 2)

    subq.l  #1,d3               ; Adjust for DBF (Total words - 1)
    bmi.s   .exit               ; Safety check for 0 size

.word_loop:
    move.w  (a0)+,d5            ; Grab word from Plane 0, A0 now points to Word+1
    
    move.w  d2,d6               ; D6 = Plane counter (Depth)
    subq.w  #2,d6               ; Already have Plane 0, so need (Depth - 1) iterations
    bmi.s   .write_mask         ; If depth was 1, just write it out

    move.l  a0,a2               ; A2 = Pointer to Word+1 in Plane 0
    subq.l  #2,a2               ; A2 = Pointer back to Current Word in Plane 0
    move.l  d4,d7               ; D7 = Plane Offset

.plane_loop:
    add.l   d7,a2               ; Move A2 to the same word in the NEXT plane
    or.w    (a2),d5             ; OR the bits into our mask accumulator
    dbf     d6,.plane_loop      ; Repeat for all remaining planes

.write_mask:
    move.w  d5,(a1)+            ; Store the combined mask word in destination
    dbf     d3,.word_loop       ; Move to next word in the image

.exit:
    movem.l (sp)+,d0-d7/a0-a2   ; Restore all
    rts