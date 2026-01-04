;---------------------------------------------------------------------------
; Create Interleaved Mask
;
; Converts an Interleaved Image into an Interleaved Mask suitable for
; single-pass Blitter operations (Cookie Cutter).
;
; Logic: 
;   1. Reads all planes for a specific row.
;   2. ORs them together to create a single mask line.
;   3. Writes that mask line 'Depth' times to the destination.
;
; Inputs:
;   A0 = Source Buffer (Interleaved Image)
;   A1 = Destination Buffer (Interleaved Mask)
;   D0 = Width (Pixels)
;   D1 = Height (Lines)
;   D2 = Depth (Bitplanes)
;
;---------------------------------------------------------------------------

WIDTH=128
HEIGHT=128
DEPTH=2

Main:
	LEA	Source(PC),A0
	LEA	Dest(PC),A1
	MOVE.L	#WIDTH,D0
	MOVE.L	#HEIGHT,D1
	MOVEQ	#DEPTH,D2
	BSR	CreateInterleavedMask
	RTS

CreateInterleavedMask:
    movem.l d2-d7/a2-a4,-(sp)

    ; --- 1. Calculate Row Width (Bytes) ---
    ; RowBytes = ((Width + 15) / 16) * 2
    move.l  d0,d3
    add.l   #15,d3
    lsr.l   #4,d3
    lsl.l   #1,d3               ; D3 = RowBytes (e.g., 40 for 320px)

    ; --- 2. Allocate Temp Buffer on Stack ---
    ; We need one line of space to build the combined mask
    move.l  d3,d4
    addq.l  #3,d4
    andi.l  #$FFFFFFFC,d4       ; Long-align size
    sub.l   d4,sp               ; Reserve stack
    move.l  sp,a2               ; A2 points to Temp Mask Buffer

    subq.w  #1,d1               ; Prepare Height for DBRA

.LineLoop:
    ; --- Step A: Build the Mask for this Line ---
    ; First, copy Plane 0 to the Temp Buffer (Base Mask)
    move.l  a2,a3               ; A3 = Temp Buffer Cursor
    move.l  a0,a4               ; A4 = Source Cursor (Preserve A0 for later?) 
                                ; No, we advance A0 as we read.
    
    move.l  d3,d0               ; Bytes to copy
    lsr.l   #1,d0               ; Words
    subq.l  #1,d0               ; DBRA count
.CopyP0:
    move.w  (a0)+,(a3)+         ; Copy Plane 0 to Buffer
    dbra    d0,.CopyP0

    ; Now OR the remaining planes into the Temp Buffer
    move.w  d2,d5               ; D5 = Planes to process
    subq.w  #2,d5               ; Subtract 1 (P0 done) and 1 for DBRA loop count
    blt.s   .MaskDone           ; If Depth=1, we are done

.ORPlanesLoop:
    move.l  a2,a3               ; Reset Buffer Cursor to start
    move.l  d3,d0               ; Bytes to process
    lsr.l   #1,d0               ; Words
    subq.l  #1,d0
.ORRow:
    move.w  (a0)+,d6            ; Read word from Plane N
    or.w    d6,(a3)+            ; OR it into Mask Buffer
    dbra    d0,.ORRow
    
    dbra    d5,.ORPlanesLoop    ; Repeat for next plane

.MaskDone:
    ; At this point:
    ; - A2 contains the combined mask for this scanline.
    ; - A0 has advanced past all planes for this scanline (Ready for next line).

    ; --- Step B: Write Mask Interleaved (Repeated) ---
    ; We write the buffer content D2 times to A1
    move.w  d2,d5               ; D5 = Depth
    subq.w  #1,d5               ; DBRA count

.WriteLoop:
    move.l  a2,a3               ; Source = Temp Buffer
    move.l  d3,d0               ; Size
    lsr.l   #1,d0               ; Words
    subq.l  #1,d0
.CopyDest:
    move.w  (a3)+,(a1)+         ; Write Mask to Dest
    dbra    d0,.CopyDest
    
    dbra    d5,.WriteLoop       ; Repeat 'Depth' times

    ; --- Step C: Next Scanline ---
    dbra    d1,.LineLoop        ; Process next vertical line

    ; --- Cleanup ---
    add.l   d4,sp               ; Restore stack
    movem.l (sp)+,d2-d7/a2-a4
    rts

Source:
	incbin	image.raw
Dest:
	ds.b	WIDTH/8*HEIGHT*DEPTH

