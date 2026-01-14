;---------------------------------------------------------------------------
; IFF Interleaved Saver (core)
; input: A0 (Source)
;---------------------------------------------------------------------------
ImgWidth:    dc.w 0
ImgHeight:   dc.w 0
ImgDepth:    dc.b 0
Compression: dc.b 0
ImgSize:     dc.l 0

Module_LoadIFF:
    move.l  a0,a4
    bsr     FindBmhd        ; A0 points to BMHD data (after Size)
    
    bsr     GetImageSize    ; D0 = Total Buffer Size
    move.l  d0,ImgSize
	
    rts


;---------------------------------------------------------------------------
; Extract_Raw
;
; Inputs:
;   A0 = Source Address (Compressed IFF BODY data)
;   A1 = Dest   Address
;---------------------------------------------------------------------------
Extract_Raw:
    bsr     FindBody        ; A0 points to actual BODY data
    
    move.l  ImgSize(pc),d0  ; Restore size to D0 for decompressor 
    
    tst.b  Compression      ; compression type (0=None, 1=ByteRun1)
    beq.s   .RawCopy        ; If 0, do a simple copy
    	
    bsr     DecompressILBM  ; Else, decompress
    rts	
	
.RawCopy:
    lsr.l   #2,d0           ; Divide size by 4 for longword copy
    subq.l  #1,d0           ; Adjust for DBRA
.CopyLoop:
    move.l  (a0)+,(a1)+     ; Copy 4 bytes at a time
    dbra    d0,.CopyLoop    ; Loop until done
    rts
;---------------------------------------------------------------------------
; FindBody
; Ensures we skip both the TAG (4 bytes) and SIZE (4 bytes).
; Modified registers:
; a0,d0,d1,d2
;---------------------------------------------------------------------------
FindBody:
    move.l  #'BODY',d0
    bsr     FindSection
    ; A0 now points to 'BODY' tag.
    ; We must skip 'BODY' (4) + Size (4) = 8 bytes.
    addq.l  #8,a0           
    rts

;---------------------------------------------------------------------------
; FindBmhd
; Ensures we skip both the TAG (4 bytes) and SIZE (4 bytes).
; a0,d0,d1,d2
;---------------------------------------------------------------------------
FindBmhd:
    move.l  #'BMHD',d0
    bsr     FindSection
    ; A0 points to 'BMHD'.
    ; We skip 'BMHD' (4) + Size (4) = 8 bytes    
    addq.l  #8,a0           
    rts

;---------------------------------------------------------------------------
; ByteRun1 Decompressor
;
; Inputs:
;   A0 = Source Address (Compressed IFF BODY data)
;   A1 = Destination Address (Where raw bitplanes will go)
;   D0 = Size of Destination Buffer in bytes (How much to decode)
;
; Registers Modified:
;   A0, A1, D0, D1, D2
;---------------------------------------------------------------------------
DecompressILBM:
    tst.l   d0              ; Safety check
    beq.s   .Done

.Loop:
    moveq   #0,d1           ; Clear D1
    move.b  (a0)+,d1        ; Read Command Byte
    
    tst.b   d1
    bmi.s   .RunEncoded     ; If negative, it's a Run or NOP

    ; --- LITERAL RUN (0 to 127) ---
    ; Copy next N+1 bytes
    sub.l   d1,d0
    subq.l  #1,d0
.LitCopy:
    move.b  (a0)+,(a1)+
    dbra    d1,.LitCopy
    bra.s   .CheckDone

.RunEncoded:
    ; --- REPLICATE RUN (-1 to -127) ---
    ; Explicitly check for NOP (-128 / $80)
    cmp.b   #$80,d1         ; Use Hex $80 to avoid assembler sign ambiguity
    beq.s   .CheckDone      ; If NOP, just check D0 and continue

    neg.b   d1              ; Negate (-x becomes x)
    
    ; Safety catch: If neg.b failed to handle -128 (rare cpu edge case),
    ; d1 would be 128 here. We ignore it or treat as 0.
    bmi.s   .CheckDone      

    sub.l   d1,d0
    subq.l  #1,d0

    move.b  (a0)+,d2        ; Read byte to replicate
.RepCopy:
    move.b  d2,(a1)+
    dbra    d1,.RepCopy

.CheckDone:
    tst.l   d0              ; Check remaining bytes
    bgt.s   .Loop

.Done:
    rts

;---------------------------------------------------------------------------
; FindSection
; Inputs:
;   A0 = Source Address (IFF data)
; Modified registers:
;   A0,D1,D2
;---------------------------------------------------------------------------
FindSection:
    move.l  4(a0),d1        ; File Size
    add.l   a0,d1           ; End Address
    addq.l  #8,a0           ; Skip FORM+Size
    addq.l  #4,a0           ; Skip ILBM
.Loop:
    cmp.l   (a0),d0         ; Check Tag
    beq.s   .Found
    move.l  4(a0),d2        ; Size
    addq.l  #1,d2
    and.b   #$FE,d2         ; Word Align
    addq.l  #8,a0           ; Skip Tag+Size
    add.l   d2,a0           ; Skip Data
    cmp.l   d1,a0
    blt.s   .Loop
    ; If not found, A0 is garbage/EOF. You might want to handle this!
.Found:
    rts

;---------------------------------------------------------------------------
; GetImageSize
; Inputs:
;   A0 = Source Address (points to BMHD data after size)
; Output
;   D0 = Total size
;---------------------------------------------------------------------------
GetImageSize:
    move.w  (a0),d0           ; Width
    move.w  d0,ImgWidth
    move.w  2(a0),d1          ; Height
    move.w  d1,ImgHeight
    moveq   #0,d2
    move.b  8(a0),d2           ; Depth
    move.w  d2,ImgDepth
    move.b  10(a0),Compression ; Compression

    add.w   #15,d0
    lsr.w   #4,d0
    lsl.w   #1,d0           ; RowBytes (Word Aligned)

    mulu.w  d1,d0           ; PlaneSize
    mulu.w  d2,d0           ; Total Size
    rts	
