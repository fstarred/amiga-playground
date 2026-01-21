; Amiga 68000 Interleaved Crop (Word-Aligned Width/Height)
; Inputs:
; A0 - Source Address
; A1 - Destination Address
; D0 - X start (0-319, non-aligned)
; D1 - Y start
; D2 - Width (Pixels, must be multiple of 16)
; D3 - Height (Lines)
; D4 - Depth (Number of bitplanes)

; Amiga 68000 Interleaved Crop (Fully 68000 Compliant)
; A0: Source | A1: Dest | D0:X | D1:Y | D2:W | D3:H | D4:Depth

SOURCE_W      EQU 320
SOURCE_BPR    EQU (SOURCE_W/8)      ; Bytes per row for ONE plane

x:      dc.w 0
xDelta: dc.w 0
y:      dc.w 0
w:      dc.w 0
h:      dc.w 0       

Crop:
    lea     $dff000, a6
	
    move.l  a0,a2	    ; backup Source/Dest address
    move.l  a1,a3

    move.w  d0,x
    move.w  d1,y
    move.w  d2,w
    move.w  d3,h

    ; --- 1. Calculate Shift & BLTCON0 ---
    move.w  d0, d5
    and.w   #$f,d5          ; X mod 16 (The bit-shift)
    moveq   #16,d7
    sub.w   d5, d7
    andi.w  #$f,d7
    move.w  d7, xDelta
    ror.w   #4, d7          ; Shift value to bits 12-15
    or.w    #$09f0, d7      ; Shift + A->D copy, LF=$F0
    move.w  d7,d5
    ; D5 = BLTCON0

    ; --- 2. Calculate BLTAPT (Start Address) ---
    ; Step A: Find size of one interleaved scanline (SOURCE_BPR * Depth)
    move.w  #SOURCE_BPR, d7
    mulu.w  d4, d7          ; D7 = Total bytes in one interleaved scanline
    
    ; Step B: Y Offset = Y * Row Size
    ; We use d1 (Y input) for the multiplication
    mulu.w  d7, d1          ; D1 = Byte offset for Y lines
    
    ; Step C: X Offset = (X/16) * 2 * Depth
    ; This skips the starting words for ALL planes in the current row
    move.w  d0, d7
    lsr.w   #3, d7
   
    add.l   d1, a0          ; Add Y offset to Base Address
    add.l   d7, a0          ; Add X offset to Base Address
    ; A0 now points to the correct starting word in the interleaved source

    ; --- 3. Calculate Modulo ---
    ; Modulo = Source Plane Width - Crop Width (in bytes)
    move.w  #SOURCE_BPR, d0
    move.w  d2, d1          ; Width in pixels
    move.w  d2, d6
    bsr     NextWordAlign
    move.w  d6, d2
    lsr.w   #3, d1          ; Width in bytes
    subq.w  #2, d0    
    sub.w   d1, d0          ; D0 = BLTAMOD

    ; --- 4. Blitter Setup ---
    bsr.w   WaitBlit

    moveq   #-1,d6
    
    move.w  d6, $44(a6)     ; BLTAFWM

    move.w  d6, $46(a6)     ; BLTALWM
    
    move.w  d5, $40(a6)     ; BLTCON0
    clr.w   $42(a6)         ; BLTCON1

    move.w  d0, $64(a6)     ; BLTAMOD
    clr.w   $66(a6)         ; BLTDMOD (0 = tightly packed destination)

    move.l  a0, $50(a6)     ; BLTAPT (Source)
    move.l  a1, $54(a6)     ; BLTDPT (Dest)

    ; --- 5. BLTSIZE ---
    ; Width = (Width / 16) words
    ; Height = Height * Depth
    lsr.w   #4, d2          ; Width in words
    addq.w  #1, d2          ; Add 1 word to blitter width
    mulu.w  d4, d3          ; Total planes/lines to blit
    
    lsl.w   #6, d3          ; Shift height into bits 6-15
    add.w   d2, d3          ; Add width bits
    move.w  d3, $58(a6)     ; START BLITTER

.CopyDestToSource:

    move.l  a3,a0	    ; Dest is now Source
    move.l  a2,a1    	    ; Source is now Dest
    
    bsr.w   WaitBlit
	
    move.w  d6, $44(a6)     ; BLTAFWM

    move.w  d6, $46(a6)     ; BLTALWM
	
    move.w  #$09f0, $40(a6) ; BLTCON0
    clr.w   $42(a6)         ; BLTCON1
	
    clr.w   $64(a6)         ; BLTAMOD
    clr.w   $66(a6)         ; BLTDMOD
	
    move.l  a0, $50(a6)     ; BLTAPT (Source)
    move.l  a1, $54(a6)     ; BLTDPT (Dest)
	
	; --- 5. BLTSIZE ---
    ; Width = (Width / 16) words
    ; Height = Height * Depth
    move.w  d3, $58(a6)     ; START BLITTER    

.FinalCrop:

    move.l  a2,a0		; switch Source/Dest again
    move.l  a3,a1

    moveq   #-1,d5		; initial BLTALWM

    move.w  xDelta(pc),d6
    beq     .noDelta
    addq.l  #2,a0    
    move.w  x(pc),d6
    bsr     NextWordAlign	; align x
    move.w  d6,d0		; x
    bra.b   .setWidth
.noDelta
    move.w  x(pc),d0		; x

.setWidth
    move.w  w(pc),d6	
    bsr     NextWordAlign	; align width
    move.w  d6,d2
    cmp.w   w(pc),d2
    beq.b   .blitSetup
    sub.w   w(pc),d6
    lsl.w   d6,d5		; set mask on width
.blitSetup	
    ; --- 4. Blitter Setup ---
    bsr.w   WaitBlit
    
    move.w  #$ffff, $44(a6) ; BLTAFWM

    move.w  d5, $46(a6) ; BLTALWM
    
    move.w  #$09f0, $40(a6)     ; BLTCON0
    clr.w   $42(a6)             ; BLTCON1
    
    move.w  #2, $64(a6)     ; BLTAMOD
    clr.w   $66(a6)         ; BLTDMOD (0 = tightly packed destination)

    move.l  a0, $50(a6)     ; BLTAPT (Source)
    move.l  a1, $54(a6)     ; BLTDPT (Dest)

    ; --- 5. BLTSIZE ---
    subq.w  #1,d3	    ; subtract a word added on the first crop operation
    move.w  d3, $58(a6)     ; START BLITTER

    bsr.w   WaitBlit
	
    rts

NextWordAlign:
    addi.w	#15,d6
    andi.w	#$fff0,d6
    rts

WordAlign:
    andi.w	#$fff0,d6
    rts

WaitBlit:
    btst    #6, $2(a6)
.loop:
    btst    #6, $2(a6)
    bne.s   .loop
    rts	
