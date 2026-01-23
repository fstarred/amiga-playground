;---------------------------------------------------------------------------
; Interleaved To Planar Image Converter (Core)
;
; Inputs:
;   A0 = Source Buffer (Interleaved Bitplanes)
;   A1 = Destination Buffer (Sequential/Planar Bitplanes)
;   D0 = Width in Pixels
;   D1 = Height in Lines
;   D2 = Number of Bitplanes
;
;
;---------------------------------------------------------------------------

InterleavedToPlanar:
    movem.l d2-d7/a2-a3,-(sp)

    ; --- 1. Calculate BytesPerRow (D3) ---
    ; (Width + 15) >> 4 << 1
    move.w  d0,d3
    add.w   #15,d3
    lsr.w   #4,d3
    lsl.w   #1,d3               ; D3 = Bytes per row (e.g., 16 for 128px)

    ; --- 2. Calculate PlaneSize (D4) ---
    move.w  d3,d4
    mulu.w  d1,d4               ; D4 = Size of one plane (e.g., 2048)

    subq.w  #1,d1               ; D1 = Height loop (y)
    move.w  d2,d7               ; D7 = Total planes
    subq.w  #1,d7               ; D7 = Plane loop (p)

.RowLoop:
    move.l  a1,a2               ; Start A2 at current row of Plane 0
    move.w  d7,d5               ; Reset plane counter

.PlaneLoop:
    move.w  d3,d6               ; Bytes to copy
    lsr.w   #1,d6               ; Words to copy
    subq.w  #1,d6               ; DBRA check
.CopyRow:
    move.w  (a0)+,(a2)+         ; Copy from interleaved source to destination
    dbra    d6,.CopyRow

    ; After 1 row, A2 has moved D3 bytes. 
    ; Jump to the same row in the NEXT plane:
    ; Offset = PlaneSize - RowWidth
    move.l  d4,d0
    sub.l   d3,d0
    add.l   d0,a2               
    dbra    d5,.PlaneLoop

    ; Finished all planes for this row.
    ; Advance A1 to the next row in Plane 0
    add.l   d3,a1               
    dbra    d1,.RowLoop

    movem.l (sp)+,d2-d7/a2-a3
    rts
