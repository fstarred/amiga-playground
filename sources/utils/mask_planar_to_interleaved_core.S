*-----------------------------------------------------------
* PlanarToInterleavedMask (Core)
* A0 - Source Planar Buffer
* A1 - Destination Interleaved Buffer
* D0 - Width (in pixels, e.g., 128)
* D1 - Height (in Rows, e.g., 128)
* D2 - Depth (Number of Planes, e.g., 5)
*-----------------------------------------------------------

PlanarToInterleavedMask:
    movem.l d0-d6/a0-a2,-(sp)

    lsr.w   #4,d0             ; Width

    subq.w  #1,d1             ; Height counter for DBRA
.rowLoop:
    move.w  d2,d5             ; D5 = Number of target planes to fill
    subq.w  #1,d5             ; Depth counter for DBRA

.planeLoop:
    move.l  a0,a2             ; A2 = Pointer to start of current source row
    move.w  d0,d6             ; D6 = Width in words
    subq.w  #1,d6             ; Word counter for DBRA
    
.wordLoop:
    move.w  (a2)+,(a1)+       ; Copy mask word to interleaved destination
    dbra    d6,.wordLoop      ; Finish the word-row for this plane
    
    ; We DON't advance A0 here yet. We want the next plane to 
    ; use the SAME source data.
    dbra    d5,.planeLoop     ; Repeat same row for all interleaved planes
    
    ; Now that all planes for this row are filled, advance source
    move.w  d0,d3
    add.w   d3,d3             ; Row width in bytes
    adda.w  d3,a0             ; Move source to next row
    dbra    d1,.rowLoop       ; Next row

    movem.l (sp)+,d0-d6/a0-a2
    rts