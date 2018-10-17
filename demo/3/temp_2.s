	SECTION Code,CODE


DMASET  = %1000001111100000
;     	  %-----axbcdefghij
;   a: Blitter Nasty
;   x: Enable DMA
;   b: Bitplane DMA (if this isn't set, sprites disappear!)
;   c: Copper DMA
;   d: Blitter DMA
;   e: Sprite DMA
;   f: Disk DMA
;   g-j: Audio 3-0 DMA

INTENASET=     %1010000000000000
;              -FEDCBA9876543210

;   F   SET/CLR 0=clear, 1=set bits that are set to 1 below
;   E   INTEN   Enable interrupts below (master toggle)
;   D   EXTER   Level 6 External interrupt
;   C   DSKSYN  Level 5 Disk Sync value found
;   B   RBF Level 5 Receive Buffer Full (serial port)
;   A   AUD3    Level 4 Audio Interrupt channel 3
;   9   AUD2    Level 4 Audio Interrupt channel 2
;   8   AUD1    Level 4 Audio Interrupt channel 1
;   7   AUD0    Level 4 Audio Interrupt channel 0
;   6   BLIT    Level 3 Blitter Interrupt
;   5   VERTB   Level 3 Vertical Blank Interrupt
;   4   COPER   Level 3 Copper Interrupt
;   3   PORTS   Level 2 CIA Interrupt (I/O ports and timers)
;   2   SOFT    Level 1 Software Interrupt
;   1   DSKBLK  Level 1 Disk Block Finished Interuppt
;   0   TBE Level 1 Transmit Buffer Empty Interrupt (serial port)


	
*****************************************************************************
	incdir	"dh1:own/demo/repository/startup/borchen/"
	include	"startup.s"	; 
	incdir	"dh1:own/demo/repository/shared/"	
	include "hardware/custom.i"
*****************************************************************************


;;    ---  SCREEN_H buffer dimensions  ---

w_H	=640+320
h_H 	= 48
ScrHBpl	=w_H/8	

w_L	=320
h_L	=256-h_H
ScrLBpl	=w_L/8	

bpls_H = 2
bpls_L = 2

;wbl = $2c (for copper monitor only)
wbl = 303

WAITVB MACRO
   	move.l  VPOSR(a5),d0      ; wait
 	and.l   #$0001ff00,d0   ; for
   	cmp.l   #wbl<<8,d0      ; rasterline 303
	bne.s   \1
	ENDM

WAITVB2 MACRO
	move.l  VPOSR(a5),d0      ; wait
 	and.l   #$0001ff00,d0    for
	cmp.l   #wbl<<8,d0      ; rasterline 303
	beq.s   \1
	ENDM

BLTWAIT	MACRO
	tst DMACONR(a5)			;for compatibility
\1
	btst #6,DMACONR(a5)
	bne.s \1
	ENDM

LMOUSE	MACRO
	btst	#6,$bfe001	; check L MOUSE btn
	bne.s	\1
	ENDM

RMOUSE	MACRO
	btst	#2,$dff016	; check L MOUSE btn
	beq.s	\1
	ENDM
	
RMOUSE2	MACRO
	btst	#2,$dff016	; check L MOUSE btn
	bne.s	\1
	ENDM	

START:
    	move.l  #SCREEN_H-2,d0  ; point to bitplane
    	lea BPLPOINTERS_H,a1  ; 
   	moveq   #bpls_H-1,d1  ; 2 BITPLANE
POINTBP_H:
    	move.w  d0,6(a1)    ; copy low word of pic address to plane
    	swap    d0          ; swap the the two words
   	move.w  d0,2(a1)    ; copy the high word of pic address to plane
    	swap    d0          ; swap the the two words

	add.l   #ScrHBpl*h_H,d0      
			
	addq.w  #8,a1
                	
	dbra    d1,POINTBP_H
	
	
	move.l  #SCREEN_L,d0  ; point to bitplane
    	lea BPLPOINTERS_L,a1  ; 
   	moveq   #bpls_L-1,d1  ; 2 BITPLANE
POINTBP_L:
    	move.w  d0,6(a1)    ; copy low word of pic address to plane
    	swap    d0          ; swap the the two words
   	move.w  d0,2(a1)    ; copy the high word of pic address to plane
    	swap    d0          ; swap the the two words

	add.l   #ScrLBpl*(h_L),d0      
			
	addq.w  #8,a1
                	
	dbra    d1,POINTBP_L
    
	move.w  #DMASET,$dff096     ; enable necessary bits in DMACON
	move.w  #INTENASET,$dff09a     ; INTENA
    
	move.l  #COPPERLIST,$dff080 ; COP1LCH set custom copperlist
   	move.w  #0,$dff088      ; COPJMP1 activate copperlist
	
	moveq	#0, d0
	
	lea	TEXT_H(PC), a0	; let a0 point to text to print
	lea	SCREEN_H+(ScrHBpl*h_H), a1	; let a3 point to BITPLANE H 2	
	move.w	#ScrHBpl, d0	; ScrHBpl        
	bsr.w	print_text
	
	;lea	TEXT_L(PC), a0	; let a0 point to text to print
	;lea	SCREEN_L, a1
	;move.w	#ScrLBpl, d0	; ScrLBpl
	;moveq	#4, d1
	;bsr.w	print_text
		
	bsr.s	draw_chessboard
		
	bsr.w	init_copper_bars
		
	lea	$dff000,a5


Main:
	WAITVB  Main

	bsr.w	clear_copper_area
	bsr.w	rolling_copper_bars

	
Wait    WAITVB2 Wait

WaitRm:
	RMOUSE2 continue
	bsr.w	scroll_text
continue:	
	LMOUSE Main

	rts		; exit

	
draw_chessboard:

	moveq	#(h_H/16)-1, d6
	lea	SCREEN_H, a0

draw_cb_loop_2_lines:
	move.w	#((ScrHBpl/4)*(8))-1, d7	; (w/32px)*h/2
draw_cb_loop:
	
	move.l	#%11111111000000001111111100000000, (a0)+
	
	dbra	d7, draw_cb_loop

	move.w	#((ScrHBpl/4)*((8)))-1, d7	; (w/32px)*h/2
draw_cb_loop_alt:
	
	move.l	#%00000000111111110000000011111111, (a0)+
	
	dbra	d7, draw_cb_loop_alt

	dbra	d6, draw_cb_loop_2_lines

	rts

	
	
scroll_text:
	addq.w	#1,FRAME_COUNTER	; add 1 to FRAME_COUNTER
	cmp.w	#160,FRAME_COUNTER	; FRAME_COUNTER reached limit ?
	bne.S	do_scroll	; if Z is clear then scroll
	bchg.b	#0,DIRECTION_FLAG	; if 1 switch flag
	clr.w	FRAME_COUNTER	; reset FRAME_COUNTER
	rts

do_scroll:
	btst	#0,DIRECTION_FLAG	; check direction
	beq.s	scroll_right		; if Z is set then scroll left
	bsr.s	scroll_left		; else scroll_right
	rts

; frame scroll counter

FRAME_COUNTER:
	dc.w	0

; DIRECTION_FLAG = 1 then scroll left
; DIRECTION_FLAG = 0 then scroll right 

DIRECTION_FLAG:
	dc.b	0
	
	EVEN

scroll_left:
	cmpi.b	#$77,OWNBPLCON1	; check right edge scroll reached
	bne.s	bplcon1_add	; if Z is clear go bplcon1_add

	lea	BPLPOINTERS_H+8,a1	; let A1 point to BPLPOINTERS
	move.w	2(a1),d0	; copy hight word of pic address to plane
	swap	d0		    ; swap the two words
	move.w	6(a1),d0    ; copy low word of pic address to plane

	subq.l	#2,d0		; point 16px backward
	clr.b	OWNBPLCON1	; reset scroll hardware of BPLCON1 ($dff102)
				; By having been jumped of 16 pixel with the
				; bitplane pointer, we must reset to zero the
				; $dff102 address and scroll to right 
				; a pixel once

	move.w	d0,6(a1)  ; copy low word of pic address to plane
	swap	d0		  ; swap the two words
	move.w	d0,2(a1)  ; copy high word of pic address to plane
	rts

bplcon1_add:
	add.b	#$11,OWNBPLCON1	; scroll 1px forward
	rts

;	this routine scroll bitplane to the left by modifying BPLCON1 value

scroll_right:
	tst.b	OWNBPLCON1	; check left edge scroll reached
	bne.s	bplcon1_sub	; if Z is clear go bplcon1_sub

	lea	BPLPOINTERS_H+8,a1	; ; let A1 point to BPLPOINTERS
	move.w	2(a1),d0 	; copy low word of pic address to plane
	swap	d0		 	; swap the two words
	move.w	6(a1),d0 	; copy high word of pic address to plane

	addq.l	#2,d0		; point 16px forward
	
	move.b	#$77,OWNBPLCON1	; scroll hardware 15 - BPLCON1 ($dff102)

	move.w	d0,6(a1)	; copy low word of pic address to plane
	swap	d0			; swap the two words; 
	move.w	d0,2(a1)	; copy high word of pic address to plane 
	rts

bplcon1_sub:
	sub.b	#$11,OWNBPLCON1	; scroll 1px backward
	rts
	
	
LINE_COUNT = 2
	
***********************************
*
*	print text routine
*	<INPUT>
*	A0:	TEXT
*	A1:	SCREEN
*	D0:	bytes per line
*********************************
print_text:
	
	moveq	#LINE_COUNT-1, d6
print_row:	
	move.w	d0, d7	; number of columns for line	
	subq	#1, d7
print_char:
	moveq	#0,d2		; clean d2
	move.b	(a0)+,d2	; let d2 point to next character
	sub.b	#$20,d2		; subtract 32 ASCII chars to d2
	lsl	#3, d2		; font height is 8, chars are disposed vertically
	move.l	d2, a2		; 8px * d2 find the char to print
	add.l	#FONT,a2	; put on a2 the character to print

	move.w	d0, d1

	move.b	(a2)+,(a1)	; print line 1 font on BITPLANE	
	; d1 distance
	move.b	(a2)+,(a1,d1.w)	; print line 2 font on BITPLANE
	add.w	d0, d1
	move.b	(a2)+,(a1,d1.w)	; print line 3 font on BITPLANE
	add.w	d0, d1
	move.b	(a2)+,(a1,d1.w)	; print line 4 font on BITPLANE
	add.w	d0, d1
	move.b	(a2)+,(a1,d1.w)	; print line 5 font on BITPLANE
	add.w	d0, d1
	move.b	(a2)+,(a1,d1.w)	; print line 6 font on BITPLANE
	add.w	d0, d1
	move.b	(a2)+,(a1,d1.w)	; print line 7 font on BITPLANE
	add.w	d0, d1
	move.b	(a2)+,(a1,d1.w)	; print line 8 font on BITPLANE
	

	addq.w	#1, a1		; move on next char (8bit)

	dbra	d7, print_char	; print 80 chars each line

	move.w	d1, d2
	
	add.w	d2, a1	; go to next row
				
	dbra	d6, print_row	; cycle x LINE_COUNT

	rts

TEXT_H:		
	;tens	 0        1         2         3         4
	;units	 1234567890123456789012345678901234567890
	dc.b	'This is the                             ' ; 1a
	dc.b	'first row  hires                        ' ; 1b
	dc.b	'           BURP                        !' ; 1c
	dc.b	'...and this is the                      ' ; 2a
	dc.b	'second row hires                        ' ; 2b
	dc.b	'           DORK                        !' ; 2c

;TEXT_L:	
;	;tens	 0        1         2         3         4
;	;units	 1234567890123456789012345678901234567890
;	dc.b	'This is the first row lowres            ' ; 1
;	dc.b	'...and this is the second row lowres   !' ; 2

	
	EVEN


COPLINES = 100		; numbero of lines in copperbar
BG_COLOR = $000	
BAR_START = $6001
BAR_SIZE = 1

***************************************
*
*	init copper bar routine
*
***************************************

init_copper_bars:
	lea	BARCOPPER, a0	
	move.l	#BAR_START*$10000+$fffe, d1	; first copper bar	
	move.l	#$01800000, d2	; put color
	move.w  #COPLINES-1, d7
init_bar_loop:
	move.l	d1,(a0)+	; put wait instruction
	move.l	d2,(a0)+	; put wait color
	add.l	#BAR_SIZE*$1000000,d1	; next wait equivalent to BAR_SIZE
	dbra	d7, init_bar_loop
	rts

***************************************
*
*	clear copper area routine
*
***************************************

clear_copper_area:

	lea	BARCOPPER, a0	
	move.w	#BG_COLOR, d1	
	move.w	#COPLINES-1, d7
clear_copper_loop:
	move.w	d1, 6(a0)	
	addq.w	#8, a0
	dbra 	d7, clear_copper_loop
	rts

***************************************
*
*	rolling copper bar
*
***************************************

rolling_copper_bars:

	lea	bar1(PC),a0
	move.l	barpos1(PC),d0
	bsr.s	build_bar
	move.l 	d0,barpos1
	lea	bar2(PC),a0
	move.l	barpos2(PC),d0
	bsr.s	build_bar
	move.l 	d0,barpos2
	lea	bar3(PC),a0
	move.l	barpos3(PC),d0
	bsr.s	build_bar
	move.l 	d0,barpos3
	lea	bar4(PC),a0
	move.l	barpos4(PC),d0
	bsr.s	build_bar
	move.l 	d0,barpos4
	lea	bar5(PC),a0
	move.l	barpos5(PC),d0
	bsr.s	build_bar
	move.l 	d0,barpos5
	lea	bar6(PC),a0
	move.l	barpos6(PC),d0
	bsr.s	build_bar
	move.l 	d0,barpos6
	lea	bar7(PC),a0
	move.l	barpos7(PC),d0
	bsr.s	build_bar
	move.l 	d0,barpos7
	lea	bar8(PC),a0
	move.l	barpos8(PC),d0
	bsr.s	build_bar
	move.l 	d0,barpos8
	rts

********************************************
*
*		
*	<INPUT>
*	A0:	BARX colors address
*	D0:	BARX position (barposx)
*
********************************************

build_bar:	
	lsl.l	#1, d0		
	lea	POSLIST(PC), a1	
	add.l	d0, a1		
				
	cmp.b	#$ff,(a1)	; check bar end position
	bne.s	set_bar_position		
	moveq	#0,d0		; reset position
	lea	POSLIST(PC),a1	
set_bar_position:
	moveq	#0, d2
	move.b	(a1), d2		
	lsl.l	#3, d2		; mul 8 bar position
	lea	BARCOPPER, a2	
	add.l	d2, a2		; add position to current bar
				
	moveq	#13-1, d7	; each bar has 13 lines
build_bar_loop:
	move.w	(a0)+,6(a2)	; write color into bar
				
	addq.w	#8,a2		; point to next color
	dbra	d7, build_bar_loop	

	lsr.l	#1, d0		; revert bit shift of barpos	
	addq.l	#1, d0		; add 1 for next whole bar
	
	rts


; BAR POSITIONS

barpos1:	dc.l 0
barpos2:	dc.l 4
barpos3:	dc.l 8
barpos4:	dc.l 12
barpos5:	dc.l 16
barpos6:	dc.l 20
barpos7:	dc.l 24
barpos8:	dc.l 28


;	EACH BAR IS COMPOSED BY 13 bar colors

; COLORS:     RGB, RGB, RGB, RGB, RGB, RGB, RGB, RGB, RGB, RGB, RGB, RGB, RGB
BAR1:
	DC.W $002,$004,$006,$008,$00a,$00c,$00f,$00c,$00a,$008,$006,$004,$002
BAR2:
	DC.W $222,$444,$666,$888,$aaa,$ccc,$fff,$ccc,$aaa,$888,$666,$444,$222
BAR3:
	DC.W $200,$400,$600,$800,$a00,$c00,$f00,$c00,$a00,$800,$600,$400,$200
BAR4:
	DC.W $020,$040,$060,$080,$0a0,$0c0,$0f0,$0c0,$0a0,$080,$060,$040,$020
BAR5:
	DC.W $012,$024,$036,$048,$05a,$06c,$07f,$06c,$05a,$048,$036,$024,$012
BAR6:
	DC.W $202,$404,$606,$808,$a0a,$c0c,$f0f,$c0c,$a0a,$808,$606,$404,$202
BAR7:
	DC.W $210,$420,$630,$840,$a50,$c60,$f70,$c80,$a70,$860,$650,$440,$230
BAR8:
	DC.W $220,$440,$660,$880,$aa0,$cc0,$ff0,$cc0,$aa0,$880,$660,$440,$220


; BEG>0
; END>180
; AMOUNT>150
; AMPLITUDE>85
; YOFFSET>0
; SIZE (B/W/L)>B
; MULTIPLIER>1

POSLIST:
	DC.B	$01,$03,$04,$06,$08,$0A,$0C,$0D,$0F,$11,$13,$14,$16,$18,$19,$1B
	DC.B	$1D,$1E,$20,$22,$23,$25,$27,$28,$2A,$2B,$2D,$2E,$30,$31,$33,$34
	DC.B	$35,$37,$38,$3A,$3B,$3C,$3D,$3F,$40,$41,$42,$43,$44,$45,$46,$47
	DC.B	$48,$49,$4A,$4B,$4C,$4D,$4D,$4E,$4F,$4F,$50,$51,$51,$52,$52,$53
	DC.B	$53,$53,$54,$54,$54,$54,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55
	DC.B	$54,$54,$54,$54,$53,$53,$53,$52,$52,$51,$51,$50,$4F,$4F,$4E,$4D
	DC.B	$4D,$4C,$4B,$4A,$49,$48,$47,$46,$45,$44,$43,$42,$41,$40,$3F,$3D
	DC.B	$3C,$3B,$3A,$38,$37,$35,$34,$33,$31,$30,$2E,$2D,$2B,$2A,$28,$27
	DC.B	$25,$23,$22,$20,$1E,$1D,$1B,$19,$18,$16,$14,$13,$11,$0F,$0D,$0C
	DC.B	$0A,$08,$06,$04,$03,$01

	DC.b	$FF	; end of table marker

	even

	
;*****************************************************************************

	SECTION	GRAPHIC,DATA_C

COPPERLIST:
SPRITEPOINTERS:
	dc.w    $120,$0000,$122,$0000,$124,$0000,$126,$0000,$128,$0000  ; clear sprite pointers
	dc.w    $12a,$0000,$12c,$0000,$12e,$0000,$130,$0000,$132,$0000  ; clear sprite pointers
	dc.w    $134,$0000,$136,$0000,$138,$0000,$13a,$0000,$13c,$0000  ; clear sprite pointers
	dc.w    $13e,$0000
	
	dc.w	$8E,$2c81	; DiwStrt
	dc.w	$90,$2cc1	; DiwStop
	dc.w	$92,$3c-4	; DdfStart
	dc.w	$94,$d4		; DdfStop
	dc.w	$102		; BplCon1 register
	dc.b	0		; BplCon1 high byte value (unused)
OWNBPLCON1:
	dc.b	0		; BplCon1 low byte value (used)
	dc.w	$104,0		; BplCon2
	dc.w	$108,40-4	; Bpl1Mod
	dc.w	$10a,40-4	; Bpl2Mod

	dc.w	$100,bpls_H*$1000+$8200	; bplcon0 - bitplane hires

BPLPOINTERS_H:
	dc.w	$e0,$0000,$e2,$0000	;first bitplane
	dc.w	$e4,$0000,$e6,$0000	;second bitplane
	
	dc.w	$0180,$000f	; color0
	dc.w	$0182,$0027	; color1
	dc.w	$0184,$0ff0	; color2
	dc.w	$0186,$0ff0	; color3

START_LORES = ($2b+h_H)*$100+07

	dc.w	START_LORES,$fffe

*********** LORES **************	
	
;	dc.w	$0180,$0f00
	dc.w	START_LORES+$100,$fffe	
	
	dc.w	$92,$0038	; DdfStart
	dc.w	$94,$00d0	; DdfStop
	dc.w	$102,0	; BplCon1
	dc.w	$108,0	; Bpl1Mod
	dc.w	$10a,0	; Bpl2Mod
	
	dc.w	$100,bpls_L*$1000+$200	; bplcon0 - bitplane lores
	
BPLPOINTERS_L:
	dc.w	$e0,$0000,$e2,$0000	;first bitplane
	dc.w	$e4,$0000,$e6,$0000	;second bitplane
	
	
	dc.w	$0180,$0000	; color0
	dc.w	$0182,$00af	; color1
	dc.w	$0184,$0000	; color2
	dc.w	$0186,$0000	; color3
	
BARCOPPER:			
	dcb.w	COPLINES*4,0	; 100*4 = 400 words

	DC.W	$ffdf,$fffe
	
	dc.w	$FFFF,$FFFE	; End of copperlist

*****************************************************************************

	SECTION	Data,DATA_C


FONT:
	incdir	"dh1:own/demo/repository/resources/fonts/"
	incbin	"nice-8x8.fnt"
	
*****************************************************************************

	SECTION	SCREEN, BSS_C	

SCREEN_H:
	ds.b	ScrHBpl*h_H*bpls_H		
SCREEN_L:
	ds.b	ScrLBpl*h_L*bpls_L

	end
	
; STANDARD RAW BITPLANE (raw)
; line 0 BITPLANE 1
; line 1 BITPLANE 1
; line 2 BITPLANE 1
; ...
; line 0 BITPLANE 2
; line 1 BITPLANE 2
; line 2 BITPLANE 2
; ...
; line 0 BITPLANE 3
; line 1 BITPLANE 3
; line 2 BITPLANE 3


; INTERLEAVED BITPLANE (blitter raw)
; line 0 BITPLANE 1
; line 0 BITPLANE 2
; line 0 BITPLANE 3
; line 1 BITPLANE 1
; line 1 BITPLANE 2
; line 1 BITPLANE 3

; +--------------------------+---------------------------+
; | AREA MODE ("normal")     | LINE MODE (line draw)     |
; +------+---------+---------+------+---------+----------+
; | BIT# | BLTCON0 | BLTCON1 | BIT# | BLTCON0 | BLTCON1  |
; +------+---------+---------+------+---------+----------+
; | 15   | ASH3    | BSH3    | 15   | ASH3    | BSH3     |
; | 14   | ASH2    | BSH2    | 14   | ASH2    | BSH2     |
; | 13   | ASH1    | BSH1    | 13   | ASH1    | BSH1     |
; | 12   | ASA0    | BSH0    | 12   | ASH0    | BSH0     |
; | 11   | USEA    | 0       | 11   | 1       | 0        |
; | 10   | USEB    | 0       | 10   | 0       | 0        |
; | 09   | USEC    | 0       | 09   | 1       | 0        |
; | 08   | USED    | 0       | 08   | 1       | 0        |
; | 07   | LF7(ABC)| DOFF    | 07   | LF7(ABC)| DPFF     |
; | 06   | LF6(ABc)| 0       | 06   | LF6(ABc)| SIGN     |
; | 05   | LF5(AbC)| 0       | 05   | LF5(AbC)| OVF      |
; | 04   | LF4(Abc)| EFE     | 04   | LF4(Abc)| SUD      |
; | 03   | LF3(aBC)| IFE     | 03   | LF3(aBC)| SUL      |
; | 02   | LF2(aBc)| FCI     | 02   | LF2(aBc)| AUL      |
; | 01   | LF1(abC)| DESC    | 01   | LF1(abC)| SING     |
; | 00   | LF0(abc)| LINE(=0)| 00   | LF0(abc)| LINE(=1) |
; +------+---------+---------+------+---------+----------+

;BLITTER KEY POINTS

; - Write BLTSIZE last; writing this register starts the blit.

; - Modulos  and  pointers  are in  bytes;  width is  in  words and  height is  in pixels.  
;	The least  significant bit of all pointers and  modules is ignored.

; - The order of operations in the blitter is masking, shifting, logical
;   combination of sources, area fill, and zero nag setting.

; - In ascending mode, the blitter increments the pointers, adds the
;	modules, and shifts to the right.

; - In  descending  mode,  the  blitter  decrements  the  pointers,  subtracts  the
; 	modules and  shifts to the left.

; - Area fill only works correctly in descending mode.

; - Check BLTDONE before writing blitter registers or using the results of a blit.

; - Shifts are done on immediate data as soon as it is loaded
