;---------------------------------------------------------------------------
; Core IFF Processing Modules (Standalone-Ready Version)
;---------------------------------------------------------------------------

;===========================================================================
; DATA VARIABLES (Moved from CLI to Core)
; These are placed in the CODE section for PC-relative reading.
;===========================================================================
ImgWidth:     dc.w 0
ImgHeight:    dc.w 0
NewDepth:     dc.w 0

;===========================================================================
; CORE MODULES
;===========================================================================

Module_LoadIFF:
    movem.l d3-d7/a2-a6,-(sp)
    lea     12(a0),a3
    move.w  ImgWidth(pc),d1     ; Read from core variable
    move.w  ImgHeight(pc),d2    ; Read from core variable
    move.b  16(a3),d3
    ext.w   d3
    move.l  a0,a4
    bsr     Helper_FindBody
    move.l  a4,a0
    move.l  a1,a6
    move.w  d2,d7
    subq.w  #1,d7
    move.l  d1,d5
    add.l   #15,d5
    lsr.l   #4,d5
    lsl.l   #1,d5
.LineLoop:
    bsr     Helper_DecodeAndConvertLine
    dbra    d7,.LineLoop
    movem.l (sp)+,d3-d7/a2-a6
    rts

Helper_DecodeAndConvertLine:
    movem.l d0-d7/a2-a5,-(sp)
    lea     RowTempBuffer,a2
    move.l  a6,a1
    move.w  ImgWidth(pc),d0     
    lsr.w   #2,d0
    subq.w  #1,d0
    move.l  a1,a3
.Clear:
    clr.l   (a3)+
    dbra    d0,.Clear
    moveq   #0,d2
    move.w  d3,d7
    subq.w  #1,d7
.PlaneLoop:
    move.l  d5,d0
    move.l  a2,a5
    bsr     Helper_DecompressRaw
    move.l  a2,a3
    move.l  a1,a4
    move.w  ImgWidth(pc),d4     
    moveq   #1,d6
    lsl.b   d2,d6
.PixelLoop:
    move.b  (a3)+,d0
    moveq   #7,d1
.BitLoop:
    add.b   d0,d0
    bcc.s   .NoBit
    or.b    d6,(a4)
.NoBit:
    addq.l  #1,a4
    subq.w  #1,d4
    beq.s   .NextPlane
    dbra    d1,.BitLoop
    bra.s   .PixelLoop
.NextPlane:
    addq.w  #1,d2
    dbra    d7,.PlaneLoop
    movem.l (sp)+,d0-d7/a2-a5
    add.w   ImgWidth(pc),a6     
    rts

Module_AnalyzeColors:
    movem.l d2-d7/a2-a6,-(sp)
    move.l  a0,a4
    bsr     Helper_FindCMAP
    lea     Palette,a2
    move.l  a4,a0
    moveq   #31,d0
.CP:
    move.b  (a0)+,(a2)+
    move.b  (a0)+,(a2)+
    move.b  (a0)+,(a2)+
    dbra    d0,.CP
    lea     Histogram,a2
    moveq   #31,d0
.CH:
    clr.w   (a2)+
    dbra    d0,.CH
    lea     Histogram,a2
    move.l  a1,a0
    moveq   #0,d0
    move.w  ImgWidth(pc),d0     
    move.w  ImgHeight(pc),d1
    mulu    d1,d0
.HL:
    moveq   #0,d1
    move.b  (a0)+,d1
    add.w   d1,d1
    addq.w  #1,(a2,d1.w)
    subq.l  #1,d0
    bne.s   .HL
    lea     RemapTable,a3
    lea     Palette,a4
    lea     Histogram,a2
    moveq   #0,d6               
    moveq   #0,d0
.ML:
    move.w  d0,d1
    add.w   d1,d1
    tst.w   (a2,d1.w)
    beq     .Unused
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
    cmp.b   0(a4,d5.w),d7
    bne.s   .Next
    move.b  1(a4,d4.w),d7
    cmp.b   1(a4,d5.w),d7
    bne.s   .Next
    move.b  2(a4,d4.w),d7
    cmp.b   2(a4,d5.w),d7
    bne.s   .Next
    move.b  0(a3,d2.w),d7
    move.b  d7,0(a3,d0.w)
    bra.s   .Done
.Next:
    dbra    d2,.Check
.Unique:
    move.b  d6,0(a3,d0.w)
    addq.w  #1,d6
    bra.s   .Done
.Unused:
    move.b  #0,0(a3,d0.w)
.Done:
    addq.w  #1,d0
    cmp.w   #32,d0
    blt     .ML
    moveq   #1,d0
    cmp.w   #2,d6
    ble.s   .SD
    moveq   #2,d0
    cmp.w   #4,d6
    ble.s   .SD
    moveq   #3,d0
    cmp.w   #8,d6
    ble.s   .SD
    moveq   #4,d0
    cmp.w   #16,d6
    ble.s   .SD
    moveq   #5,d0
.SD:
    move.w  d0,NewDepth         ; Write to core variable
    movem.l (sp)+,d2-d7/a2-a6
    rts

Module_RemapPixels:
    movem.l d0-d1/a0-a3,-(sp)
    lea     RemapTable,a3
    move.l  a1,a0
    move.w  ImgWidth(pc),d0     
    move.w  ImgHeight(pc),d1
    mulu    d1,d0
.RL:
    moveq   #0,d1
    move.b  (a0),d1
    move.b  0(a3,d1.w),d1
    move.b  d1,(a0)+
    subq.l  #1,d0
    bne.s   .RL
    movem.l (sp)+,d0-d1/a0-a3
    rts

Module_SaveInterleaved:
    movem.l d0-d7/a0-a6,-(sp)
    move.w  NewDepth(pc),d5     
    move.w  ImgWidth(pc),d0
    move.w  ImgHeight(pc),d1
    subq.w  #1,d1
.LL:
    moveq   #0,d2
.PL:
    move.l  a1,a3
    move.w  d0,d3
    lsr.w   #4,d3
    subq.w  #1,d3
.WL:
    moveq   #0,d4
    moveq   #15,d6
.BL:
    move.b  (a3)+,d7
    btst    d2,d7
    beq.s   .NB
    bset    d6,d4
.NB:
    dbra    d6,.BL
    move.w  d4,(a2)+
    dbra    d3,.WL
    addq.w  #1,d2
    cmp.w   d5,d2
    blt.s   .PL
    add.w   d0,a1
    dbra    d1,.LL
    movem.l (sp)+,d0-d7/a0-a6
    rts

Helper_FindBody:
    move.l  #'BODY',d0
    bra.s   Helper_FindChunk
Helper_FindCMAP:
    move.l  #'CMAP',d0
Helper_FindChunk:
    movem.l d1-d2/a0,-(sp)
    move.l  a4,a0
    move.l  4(a0),d1
    add.l   a0,d1
    add.w   #12,a0
.SL:
    cmp.l   a0,d1
    ble.s   .NF
    cmp.l   (a0),d0
    beq.s   .F
    move.l  4(a0),d2
    addq.l  #1,d2
    andi.l  #$FFFFFFFE,d2
    addq.l  #8,a0
    add.l   d2,a0
    bra.s   .SL
.F:
    addq.l  #8,a0
    move.l  a0,a4
    moveq   #1,d0
    bra.s   .EX
.NF:
    moveq   #0,d0
.EX:
    movem.l (sp)+,d1-d2/a0
    rts

Helper_DecompressRaw:
    movem.l d1-d2,-(sp)
.DL:
    tst.l   d0
    ble.s   .DD
    moveq   #0,d1
    move.b  (a0)+,d1
    tst.b   d1
    bmi.s   .RE
    ext.w   d1
    sub.l   d1,d0
    subq.l  #1,d0
.LC:
    move.b  (a0)+,(a5)+
    dbra    d1,.LC
    bra.s   .DL
.RE:
    cmp.b   #$80,d1
    beq.s   .DL
    neg.b   d1
    ext.w   d1
    sub.l   d1,d0
    subq.l  #1,d0
    move.b  (a0)+,d2
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
Palette:       ds.b 32*3
Histogram:     ds.w 32
RemapTable:    ds.b 32
RowTempBuffer: ds.b 512
    even