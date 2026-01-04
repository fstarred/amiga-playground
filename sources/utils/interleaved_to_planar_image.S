;---------------------------------------------------------------------------
; Interleaved To Planar Image Converter
;
; Inputs:
;   A0 = Source Buffer (Interleaved Bitplanes)
;   A1 = Destination Buffer (Sequential/Planar Bitplanes)
;   D0 = Width in Pixels
;   D1 = Height in Lines
;   D2 = Number of Bitplanes
;
;   After running the executable, WB <filename>/Dest/Dest+WITH/40*HEIGHT*2
;
;---------------------------------------------------------------------------

WIDTH=320
HEIGHT=256
DEPTH=2

Main:
	LEA	Source(PC),A0
	LEA	Dest(PC),A1
	MOVE.L	#WIDTH,D0
	MOVE.L	#HEIGHT,D1
	MOVEQ	#DEPTH,D2
	BSR	Convert_To_Planar	
	RTS


Convert_To_Planar:
    movem.l d2-d6/a2-a3,-(sp)

    ; --- 1. Calculate Widths ---
    ; RowWidth (D3) = ((Width + 15) >> 4) << 1
    move.l  d0,d3
    add.l   #15,d3
    lsr.l   #4,d3
    lsl.l   #1,d3               ; D3 = Bytes per row (padded for Amiga)

    ; PlaneSize (D4) = RowWidth * Height
    move.l  d3,d4
    mulu    d1,d4               ; D4 = Size of one full plane in bytes

    move.l  a1,a3               ; A3 = Base address of Plane 0 in Destination
    subq.w  #1,d1               ; Height Loop Counter

.RowLoop:
    move.l  a3,a2               ; A2 points to the current row in the current plane
    move.w  d2,d5               ; Reset Plane Counter
    subq.w  #1,d5               ; Plane Loop Counter

.PlaneLoop:
    ; Copy one row from Source to current Plane in Destination
    move.w  d3,d6               ; D6 = Bytes to copy
    lsr.w   #1,d6               ; Convert to Words for faster copying
    subq.w  #1,d6               ; DBRA adjustment
.CopyRow:
    move.w  (a0)+,(a2)+         ; Copy word from Source to current Plane
    dbra    d6,.CopyRow

    ; After copying one row, we are at the end of that row in the source.
    ; But in the DESTINATION, we need to jump to the start of the next plane.
    ; However, since (A2) already advanced by D3, we jump by (PlaneSize - RowWidth)
    move.l  d4,d0
    sub.l   d3,d0
    add.l   d0,a2               ; A2 now points to the same Row Y in Plane P+1
    
    dbra    d5,.PlaneLoop       ; Repeat for all bitplanes

    ; Once all planes for Row Y are done, move Destination Base (A3) to next Row
    add.l   d3,a3               ; A3 moves to Row Y+1 in Plane 0
    dbra    d1,.RowLoop         ; Repeat for all lines of height

    movem.l (sp)+,d2-d6/a2-a3
    rts


Source
	incbin	image.raw
Dest
	ds.b	40*256*5
