; -------------------------------------------------------------------------
; Convert Interleaved Mask to Planar
; -------------------------------------------------------------------------
; A0 - Source (Planar)
; A1 - Destination (Interleaved)
; D0 - Width in words (e.g., 20 for 320px)
; D1 - Height in lines
; D2 - Depth (Number of bitplanes)
; -------------------------------------------------------------------------

Main:
	LEA	Source(PC),A0
	LEA	Dest(PC),A1
	MOVE.L	#128,D0
	MOVE.L	#128,D1
	MOVEQ	#2,D2
	BSR	ConvertInterleavedToPlanar
	RTS	

ConvertInterleavedToPlanar:
    movem.l d2-d7/a2-a3,-(sp)   ; Save registers

    ; --- 1. Calculate Row Width (Bytes) ---
    ; RowBytes = ((Width + 15) / 16) * 2
    move.l  d0,d3
    add.l   #15,d3
    lsr.l   #4,d3
    lsl.l   #1,d3               ; D3 = RowBytes (e.g., 40 for 320px)

    ; --- 2. Allocate Temp Buffer on Stack ---
    ; We use this to accumulate the OR operations for one line.
    move.l  d3,d4
    addq.l  #3,d4
    andi.l  #$FFFFFFFC,d4       ; Align size to Longword
    sub.l   d4,sp               ; Reserve stack space
    move.l  sp,a2               ; A2 points to Temp Line Buffer

    subq.w  #1,d1               ; Prepare Height Loop (DBRA)

.RowLoop:
    ; --- Step A: Copy First Plane to Temp Buffer ---
    ; We treat Plane 0 as the base of our mask.
    move.l  a2,a3               ; A3 = Temp Buffer Cursor
    move.l  d3,d0               ; Bytes to copy
    lsr.l   #1,d0               ; Words
    subq.l  #1,d0               ; DBRA count
.CopyP0:
    move.w  (a0)+,(a3)+         ; Copy Plane 0 -> Temp
    dbra    d0,.CopyP0

    ; --- Step B: OR Remaining Planes ---
    ; If Depth > 1, we OR the subsequent planes into the Temp Buffer.
    move.w  d2,d5               ; D5 = Depth
    subq.w  #2,d5               ; Subtract 1 (P0 done) and 1 for DBRA
    blt.s   .WriteMask          ; If Depth=1, skip straight to writing

.PlaneLoop:
    move.l  a2,a3               ; Reset Buffer Cursor
    move.l  d3,d0               ; Reset Word Count
    lsr.l   #1,d0
    subq.l  #1,d0
.ORLoop:
    move.w  (a0)+,d6            ; Read Word from Plane N
    or.w    d6,(a3)+            ; OR it with the Mask in Temp Buffer
    dbra    d0,.ORLoop
    
    dbra    d5,.PlaneLoop       ; Next Plane

    ; --- Step C: Write Final Mask to Destination ---
.WriteMask:
    ; A2 holds the combined mask for this row.
    ; A0 is already pointing to the start of the NEXT interleaved row.
    move.l  a2,a3               ; Source = Temp Buffer
    move.l  d3,d0               ; Count
    lsr.l   #1,d0
    subq.l  #1,d0
.CopyDest:
    move.w  (a3)+,(a1)+         ; Write to Planar Mask Buffer
    dbra    d0,.CopyDest

    dbra    d1,.RowLoop         ; Next Line

    ; --- Cleanup ---
    add.l   d4,sp               ; Restore Stack
    movem.l (sp)+,d2-d7/a2-a3   ; Restore Registers
    rts

Source
	incbin	imagemask
Dest
	DS.B	16*128
