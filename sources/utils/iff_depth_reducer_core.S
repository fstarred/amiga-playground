;---------------------------------------------------------------------------
; IFF Optimizer & Interleaved Saver (Core)
;---------------------------------------------------------------------------

;===========================================================================
; Global image variables (stored in the CODE section)
;===========================================================================
ImgWidth:     dc.w 0
ImgHeight:    dc.w 0
NewDepth:     dc.w 0

;===========================================================================
; CORE MODULES
;===========================================================================

;---------------------------------------------------------------------------
; Module_LoadIFF: Converts planar IFF data into a 1-byte-per-pixel buffer
;---------------------------------------------------------------------------
Module_LoadIFF:
    movem.l d3-d7/a2-a6,-(sp)   ; Preserve registers for the caller
    lea     12(a0),a3           ; Skip 'FORMxxxxILBM' header
    move.w  ImgWidth(pc),d1     ; Load cached width using PC-relative addressing
    move.w  ImgHeight(pc),d2    ; Load cached height using PC-relative addressing
    move.b  16(a3),d3           ; Extract bitplane depth from the BMHD chunk
    ext.w   d3                  ; Extend byte to word for calculations
    move.l  a0,a4               ; Store file start pointer for chunk searching
    bsr     Helper_FindBody     ; Locate the start of the 'BODY' pixel data
    move.l  a4,a0               ; A0 = Start of compressed image data
    move.l  a1,a6               ; A6 = Pointer to the Chunky Work Buffer
    move.w  d2,d7               ; D7 = Scanline counter (Height)
    subq.w  #1,d7               ; Adjust for DBRA loop (0 to N-1)
    
    ; Calculate RowBytes: (Width + 15) / 16 * 2 (Standard Amiga row padding)
    move.l  d1,d5
    add.l   #15,d5
    lsr.l   #4,d5
    lsl.l   #1,d5               ; D5 = Number of bytes per plane per row

.LineLoop:
    bsr     Helper_DecodeAndConvertLine ; Process a single scanline
    dbra    d7,.LineLoop        ; Repeat for every line in the image
    movem.l (sp)+,d3-d7/a2-a6   ; Restore registers
    rts

;---------------------------------------------------------------------------
; Helper: Processes one scanline from bitplanes to chunky bytes
;---------------------------------------------------------------------------
Helper_DecodeAndConvertLine:
    movem.l d0-d7/a2-a5,-(sp)
    lea     RowTempBuffer,a2    ; Destination for decompressed plane data
    move.l  a6,a1               ; A1 = Destination chunky line
    move.w  ImgWidth(pc),d0     
    lsr.w   #2,d0               ; Prepare to clear destination line 4 bytes at a time
    subq.w  #1,d0
    move.l  a1,a3
.Clear:
    clr.l   (a3)+               ; Initialize chunky pixels to 0
    dbra    d0,.Clear
    
    moveq   #0,d2               ; Current bitplane index
    move.w  d3,d7               ; Total bitplane depth
    subq.w  #1,d7
.PlaneLoop:
    move.l  d5,d0               ; Number of bytes to decompress
    move.l  a2,a5               ; Temp buffer for this plane's row
    bsr     Helper_DecompressRaw ; Expand ByteRun1 compression
    
    move.l  a2,a3               ; A3 = Decompressed plane data
    move.l  a1,a4               ; A4 = Chunky line buffer
    move.w  ImgWidth(pc),d4     ; Horizontal pixel counter
    moveq   #1,d6
    lsl.b   d2,d6                ; D6 = Bit value (1, 2, 4, 8, etc.) based on plane index
.PixelLoop:
    move.b  (a3)+,d0            ; Get 8 bits from the plane
    moveq   #7,d1               ; Loop for 8 pixels
.BitLoop:
    add.b   d0,d0               ; Shift highest bit into Carry
    bcc.s   .NoBit              ; If bit was 0, skip
    or.b    d6,(a4)             ; If bit was 1, OR the bit value into the chunky byte
.NoBit:
    addq.l  #1,a4               ; Move to next chunky pixel
    subq.w  #1,d4               ; Check if we finished the row
    beq.s   .NextPlane
    dbra    d1,.BitLoop
    bra.s   .PixelLoop          ; Get next byte from plane
.NextPlane:
    addq.w  #1,d2               ; Move to the next bitplane
    dbra    d7,.PlaneLoop
    
    movem.l (sp)+,d0-d7/a2-a5
    add.w   ImgWidth(pc),a6     ; Advance chunky pointer to the next scanline
    rts

;---------------------------------------------------------------------------
; Module_AnalyzeColors: Creates a Histogram and a Remap Table
;---------------------------------------------------------------------------
Module_AnalyzeColors:
    movem.l d2-d7/a2-a6,-(sp)
    move.l  a0,a4               ; Save file start address
    bsr     Helper_FindCMAP     ; Locate 'CMAP' (Palette) chunk
    lea     Palette,a2          ; Internal palette storage
    move.l  a4,a0               ; A0 = Start of RGB data in file
    moveq   #31,d0              ; Process 32 colors
.CP:
    move.b  (a0)+,(a2)+         ; Copy Red
    move.b  (a0)+,(a2)+         ; Copy Green
    move.b  (a0)+,(a2)+         ; Copy Blue
    dbra    d0,.CP
    
    lea     Histogram,a2        ; Reset the color usage counters
    moveq   #31,d0
.CH:
    clr.w   (a2)+
    dbra    d0,.CH
    
    ; Scan chunky buffer to count occurrences of each color index
    lea     Histogram,a2
    move.l  a1,a0               ; A0 = Chunky data buffer
    moveq   #0,d0
    move.w  ImgWidth(pc),d0     
    move.w  ImgHeight(pc),d1
    mulu    d1,d0               ; D0 = Total number of pixels
.HL:
    moveq   #0,d1
    move.b  (a0)+,d1            ; Get pixel index
    add.w   d1,d1               ; Word offset (index * 2)
    addq.w  #1,(a2,d1.w)        ; Increment histogram for this color
    subq.l  #1,d0               ; Next pixel
    bne.s   .HL

    ; Create RemapTable: Identifies unused or duplicate colors
    lea     RemapTable,a3
    lea     Palette,a4
    lea     Histogram,a2
    moveq   #0,d6               ; Counter for new unique color indices
    moveq   #0,d0               ; Index of original color being checked
.ML:
    move.w  d0,d1
    add.w   d1,d1
    tst.w   (a2,d1.w)           ; Is this color index actually used in the image?
    beq     .Unused
    
    ; Compare current color with all previous unique colors to find duplicates
    move.w  d0,d2
    subq.w  #1,d2
    bmi.s   .Unique
.Check:
    move.w  d2,d3
    add.w   d3,d3
    tst.w   (a2,d3.w)
    beq.s   .Next
    move.w  d0,d4
    mulu    #3,d4
    move.w  d2,d5
    mulu    #3,d5
    move.b  0(a4,d4.w),d7
    cmp.b   0(a4,d5.w),d7       ; Compare Red
    bne.s   .Next
    move.b  1(a4,d4.w),d7
    cmp.b   1(a4,d5.w),d7       ; Compare Green
    bne.s   .Next
    move.b  2(a4,d4.w),d7
    cmp.b   2(a4,d5.w),d7       ; Compare Blue
    bne.s   .Next
    
    ; Exact RGB match found: map current index to the previous index's new home
    move.b  0(a3,d2.w),d7
    move.b  d7,0(a3,d0.w)
    bra.s   .Done
.Next:
    dbra    d2,.Check
.Unique:
    move.b  d6,0(a3,d0.w)       ; Assign next available bitplane index
    addq.w  #1,d6
    bra.s   .Done
.Unused:
    move.b  #0,0(a3,d0.w)       ; Map unused colors to 0
.Done:
    addq.w  #1,d0
    cmp.w   #32,d0
    blt     .ML

    ; Determine required Bitplane Depth for the unique color count (d6)
    moveq   #1,d0               ; Default 1 bitplane (2 colors)
    cmp.w   #2,d6
    ble.s   .SD
    moveq   #2,d0               ; 2 bitplanes (4 colors)
    cmp.w   #4,d6
    ble.s   .SD
    moveq   #3,d0               ; 3 bitplanes (8 colors)
    cmp.w   #8,d6
    ble.s   .SD
    moveq   #4,d0               ; 4 bitplanes (16 colors)
    cmp.w   #16,d6
    ble.s   .SD
    moveq   #5,d0               ; 5 bitplanes (32 colors)
.SD:
    move.w  d0,NewDepth         ; Update Global variable
    movem.l (sp)+,d2-d7/a2-a6
    rts

;---------------------------------------------------------------------------
; Module_RemapPixels: Applies the RemapTable to all chunky pixels
;---------------------------------------------------------------------------
Module_RemapPixels:
    movem.l d0-d1/a0-a3,-(sp)
    lea     RemapTable,a3
    move.l  a1,a0               ; A0 = Start of chunky pixels
    move.w  ImgWidth(pc),d0     
    move.w  ImgHeight(pc),d1
    mulu    d1,d0               ; D0 = Pixel count
.RL:
    moveq   #0,d1
    move.b  (a0),d1             ; Read pixel value
    move.b  0(a3,d1.w),d1       ; Translate via Remap Table
    move.b  d1,(a0)+            ; Save back and move to next
    subq.l  #1,d0
    bne.s   .RL
    movem.l (sp)+,d0-d1/a0-a3
    rts

;---------------------------------------------------------------------------
; Module_SaveInterleaved: Converts chunky pixels back to bitplanes
;---------------------------------------------------------------------------
Module_SaveInterleaved:
    movem.l d0-d7/a0-a6,-(sp)
    move.w  NewDepth(pc),d5     ; Use the newly calculated depth
    move.w  ImgWidth(pc),d0
    move.w  ImgHeight(pc),d1
    subq.w  #1,d1
.LL:
    moveq   #0,d2               ; Current plane counter
.PL:
    move.l  a1,a3               ; Reset source pointer to start of chunky line
    move.w  d0,d3
    lsr.w   #4,d3               ; Number of words per row
    subq.w  #1,d3
.WL:
    moveq   #0,d4               ; Reset bitplane word accumulator
    moveq   #15,d6              ; Bit counter (left to right)
.BL:
    move.b  (a3)+,d7            ; Get chunky pixel
    btst    d2,d7               ; Is the bit for the current plane set?
    beq.s   .NB
    bset    d6,d4               ; Set the bit in the bitplane word
.NB:
    dbra    d6,.BL              ; Process next bit in the word
    move.w  d4,(a2)+            ; Store finished word in destination buffer
    dbra    d3,.WL              ; Process next word in the row
    
    addq.w  #1,d2               ; Move to next bitplane for this line
    cmp.w   d5,d2
    blt.s   .PL
    
    add.w   d0,a1               ; Advance chunky source to next scanline
    dbra    d1,.LL
    movem.l (sp)+,d0-d7/a0-a6
    rts

;---------------------------------------------------------------------------
; Helper: IFF Chunk Finders
;---------------------------------------------------------------------------
Helper_FindBody:
    move.l  #'BODY',d0          ; Looking for pixel data
    bra.s   Helper_FindChunk
Helper_FindCMAP:
    move.l  #'CMAP',d0          ; Looking for palette data
Helper_FindChunk:
    movem.l d1-d2/a0,-(sp)
    move.l  a4,a0               ; File start
    move.l  4(a0),d1            ; Total file size from FORM header
    add.l   a0,d1               ; D1 = Address of EOF
    add.w   #12,a0              ; Skip 'FORMxxxxILBM'
.SL:
    cmp.l   a0,d1               ; Check for EOF
    ble.s   .NF
    cmp.l   (a0),d0             ; Match found?
    beq.s   .F
    move.l  4(a0),d2            ; Read chunk size
    addq.l  #1,d2               ; Chunks are word-aligned
    andi.l  #$FFFFFFFE,d2
    addq.l  #8,a0               ; Skip Chunk ID and Size fields
    add.l   d2,a0               ; Skip Chunk Data
    bra.s   .SL
.F:
    addq.l  #8,a0               ; Point A0 to the start of the data
    move.l  a0,a4               ; Return address in A4
    moveq   #1,d0
    bra.s   .EX
.NF:
    moveq   #0,d0
.EX:
    movem.l (sp)+,d1-d2/a0
    rts

;---------------------------------------------------------------------------
; Helper: IFF ByteRun1 RLE Decompressor
;---------------------------------------------------------------------------
Helper_DecompressRaw:
    movem.l d1-d2,-(sp)
.DL:
    tst.l   d0                  ; D0 = target decompressed byte count
    ble.s   .DD
    moveq   #0,d1
    move.b  (a0)+,d1            ; Get Control Byte
    tst.b   d1
    bmi.s   .RE                 ; If negative, it's a repeat run
    
    ; Literal Copy (0 to 127)
    ext.w   d1
    sub.l   d1,d0
    subq.l  #1,d0
.LC:
    move.b  (a0)+,(a5)+
    dbra    d1,.LC
    bra.s   .DL
.RE:
    cmp.b   #$80,d1             ; Check for No-Op (-128)
    beq.s   .DL
    
    ; Replicate Run (-1 to -127)
    neg.b   d1
    ext.w   d1
    sub.l   d1,d0
    subq.l  #1,d0
    move.b  (a0)+,d2            ; Byte to repeat
.RC:
    move.b  d2,(a5)+
    dbra    d1,.RC
    bra.s   .DL
.DD:
    movem.l (sp)+,d1-d2
    rts

;===========================================================================
; BSS SECTION (Internal buffers only)
;===========================================================================
    SECTION DATABSS, BSS_C
    even
Palette:       ds.b 32*3        ; Storage for extracted palette
Histogram:     ds.w 32          ; Storage for color usage counts
RemapTable:    ds.b 32          ; Mapping of old indices to optimized indices
RowTempBuffer: ds.b 512         ; Decompression workspace for one bitplane row
    even