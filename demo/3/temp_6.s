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
h_H 	=48
ScrHBpl	=w_H/8	

w_L	=320
h_L	=256-h_H
ScrLBpl	=w_L/8	

bpls_H = 4
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

	add.l   #ScrLBpl,d0      
			
	addq.w  #8,a1
                	
	dbra    d1,POINTBP_L
    
	move.w  #DMASET,$dff096     ; enable necessary bits in DMACON
	move.w  #INTENASET,$dff09a     ; INTENA
    
	move.l  #COPPERLIST,$dff080 ; COP1LCH set custom copperlist
   	move.w  #0,$dff088      ; COPJMP1 activate copperlist
	
	moveq	#0, d0
	
	bsr.w	draw_chessboard
		
	bsr.w	init_copper_bars
		
	lea	$dff000,a5
	
	bsr	print_text_header
	

Main:
	WAITVB  Main

	bsr.w	clear_copper_area
	bsr.w	rolling_copper_bars

	bsr.w	scroll_screen
	
	bsr.w   sprite_animation
	bsr.w   sprite_move

	
	bsr.w	print_char_scrolling_text
	bsr.w	scroll_text
	bsr.w	copy_text_buffer_to_screen
	bsr.w	compute_offset
	bsr.w	clear_scrtxt_area		
	bsr.w	make_camel
		
	
Wait    WAITVB2 Wait

WaitRm:
	;RMOUSE2 continue
	RMOUSE WaitRm
	
continue:	
	LMOUSE Main

	rts		; exit

FONTSET_HEADER_WIDTH   = 320   ; pixel
FONTSET_HEADER_HEIGHT  = 256    ; pixel

FONT_HEADER_WIDTH  = 32 ; pixel
FONT_HEADER_HEIGHT = 32 ; pixel

TEXT_HEADER_HOFFSET_W = 30
TEXT_HEADER_VOFFSET = ScrHBpl*10

***********************************
*
*	plot char routine
*	
*	
*	
***********************************
print_text_header:
	
	lea	TEXT_HEADER(PC), a0
	moveq	#0,d2		; clear D2

	BLTWAIT BWT1
	
	move.l	#$ffffffff,BLTAFWM(a5)	 ; BLTALWM, BLTAFWM
	move.l	#$09F00000,BLTCON0(a5)	; BLTCON0/1
	move.l	#$00240074,BLTAMOD(a5)	; BLTAMOD = 36, BLTDMOD = 116
			
	lea	SCREEN_H+TEXT_HEADER_HOFFSET_W+TEXT_HEADER_VOFFSET, a1
	
plot_char:
	move.b	(a0)+,d2	; go next char 
	beq.s	end_text	; if D2 != 0 print char
	subi.b	#$20, d2	; get font position
	lsl.w	#2,d2		; in charset by multipling
				; 4 bytes (font is 32 pixel)
	
	move.l	a1, a3
	
	lea	FONT_ADDRESS_LIST(PC),a2
	move.l	0(a2,d2.w),a2			
	
	moveq	#3-1,d7		; bitplanes
copy_char:

	BLTWAIT BWT2

	move.l	a2,BLTAPT(a5)		; BLTAPT (FONTSET)
	move.l	a3,BLTDPT(a5)		; BLTDPT (BITPLANE)
	move.w	#FONT_HEADER_HEIGHT*64+(FONT_HEADER_WIDTH/16),BLTSIZE(a5)	; BLTSIZE
	
	lea	40*FONTSET_HEADER_HEIGHT(a2),a2	; NEXT BITPLANE FONTSET
	lea	ScrHBpl*h_H(a3),a3	; NEXT BITPLANE SCREEN
	
	dbra	d7, copy_char
	
	lea	4(a1), a1 ; point to next char space
	
	bra.s	plot_char

end_text:
	rts

***********************************
*
*	draw chessboard routine
*	
*	
***********************************
draw_chessboard:

	moveq	#(h_H/16)-1, d6
	lea	SCREEN_H+(ScrHBpl*h_H*3), a0

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

	

scroll_screen:
	lea	BPLPOINTERS_H, a1	
	subq.w	#1,FRAME_COUNTER	; add 1 to FRAME_COUNTER
	tst.w	FRAME_COUNTER	; FRAME_COUNTER reached limit ?
	bne.S	do_scroll	; if Z is clear then scroll
	bchg.b	#0, DIRECTION_FLAG	; if 1 switch flag
	move.w	#160, FRAME_COUNTER	; reset FRAME_COUNTER
	rts

******************************
*
*	scroll	bitplane left/right
*	<INPUT>
*	A1:	BPLPOINTERS
*
******************************
do_scroll:	
	btst	#0,DIRECTION_FLAG	; check direction
	beq.s	scroll_right			; if Z is set then scroll left
	bsr.s	scroll_left		; else scroll_right
	rts

; frame scroll counter

FRAME_COUNTER:	dc.w	160

; DIRECTION_FLAG = 1 then scroll left
; DIRECTION_FLAG = 0 then scroll right

DIRECTION_FLAG:	dc.b	0

; this routine scroll bitplane to the right by modifying BPLCON1 value

	EVEN

scroll_left:
	cmpi.b	#$77,OWNBPLCON1	; check right edge scroll reached
	beq.s	set_bpl_left	; if Z is clear go bplcon1_add

	add.b	#$11,OWNBPLCON1	; scroll 1px forward
	rts

set_bpl_left:	
	moveq	#-2, d1
	bsr.s	advance_bpl
	
	move.b	#0, OWNBPLCON1	; scroll hardware 15 - BPLCON1 ($dff102)

	rts

******************************
*
*	<INPUT>
*	A1:	BPLPOINTERS
*	D1:	delta
*
******************************
advance_bpl:
	
	moveq	#bpls_h-1, d7
advance_bpl_loop:

	move.w	2(a1),d0 	; copy low word of pic address to plane
	swap	d0		; swap the two words
	move.w	6(a1),d0 	; copy high word of pic address to plane

	add.l	d1,d0		; point 16px forward

	move.w	d0,6(a1)	; copy low word of pic address to plane
	swap	d0		; swap the two words; 
	move.w	d0,2(a1)	; copy high word of pic address to plane 

	lea	8(a1),a1

	dbra	d7, advance_bpl_loop

	rts	

scroll_right:
	tst.b	OWNBPLCON1	; check left edge scroll reached	
	beq.s	set_bpl_right	; if Z is clear go bplcon1_sub
	
	sub.b	#$11,OWNBPLCON1	; scroll 1px backward	
	rts

set_bpl_right:	
	moveq	#2, d1
	bsr.s	advance_bpl
	
	move.b	#$77,OWNBPLCON1	; scroll hardware 15 - BPLCON1 ($dff102)

	rts
	
LINE_COUNT = 2


	

FONT_ADDRESS_LIST:
	dc.l FONT_HEADER	
	dc.l FONT_HEADER+4	
	dc.l FONT_HEADER+8
	dc.l FONT_HEADER+12,FONT_HEADER+16,FONT_HEADER+20,FONT_HEADER+24,FONT_HEADER+28,FONT_HEADER+32,FONT_HEADER+36

	; 2nd COLUMN (40 bytes*32)
	dc.l FONT_HEADER+1280		
	dc.l FONT_HEADER+1284
	dc.l FONT_HEADER+1288
	dc.l FONT_HEADER+1292
	dc.l FONT_HEADER+1296,FONT_HEADER+1300,FONT_HEADER+1304,FONT_HEADER+1308,FONT_HEADER+1312,FONT_HEADER+1316

	; 3rd COLUMN (40 bytes*32*2)
	dc.l FONT_HEADER+2560,FONT_HEADER+2564,FONT_HEADER+2568,FONT_HEADER+2572,FONT_HEADER+2576,FONT_HEADER+2580
	dc.l FONT_HEADER+2584,FONT_HEADER+2588,FONT_HEADER+2592,FONT_HEADER+2596

	; 4th COLUMN (40 bytes*32*3)
	dc.l FONT_HEADER+3840,FONT_HEADER+3844,FONT_HEADER+3848,FONT_HEADER+3852,FONT_HEADER+3856,FONT_HEADER+3860
	dc.l FONT_HEADER+3864,FONT_HEADER+3868,FONT_HEADER+3872,FONT_HEADER+3876

	; 5th COLUMN (40 bytes*32*4)
	dc.l FONT_HEADER+5120,FONT_HEADER+5124,FONT_HEADER+5128,FONT_HEADER+5132,FONT_HEADER+5136,FONT_HEADER+5140
	dc.l FONT_HEADER+5144,FONT_HEADER+5148,FONT_HEADER+5152,FONT_HEADER+5156
	
	; 6th COLUMN (40 bytes*32*5)
	dc.l FONT_HEADER+6400,FONT_HEADER+6404,FONT_HEADER+6408,FONT_HEADER+6412,FONT_HEADER+6416,FONT_HEADER+6420
	dc.l FONT_HEADER+6424,FONT_HEADER+6428,FONT_HEADER+6432,FONT_HEADER+6436

	
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

TEXT_HEADER:
	dc.b	'STARRED MEDIASOFT',0
	

	
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


	
	
	
	
	
text_offset_pointer dc.l    TEXT

*****************************************************************************
* 
* 	Print char over the right screen margin
*
*
*****************************************************************************

SCROLL_COUNT = 8	; (FONT_WIDTH / pixel shift)
counter:	dc.w	SCROLL_COUNT	;

FONTSET_SCRTXT_WIDTH   = 944   ; pixel
FONTSET_SCRTXT_HEIGHT  = 16    ; pixel

FONT_SCRTXT_WIDTH  = 16 ; pixel
FONT_SCRTXT_HEIGHT = 16 ; pixel

SCRTEXT_V_OFFSET = 110
SCREEN_VOFFSET = SCRTEXT_V_OFFSET*ScrLBpl*bpls_L

	
print_char_scrolling_text:
	
	subq.w	#1,counter	; decrease counter 
	bne.s	no_print	; if counter != 0 do nothing
	move.w	#SCROLL_COUNT,counter	; if counter = 0 reset counter

	move.l  text_offset_pointer(PC), a0
	
	moveq	#0,d2		; clear D2
	move.b	(a0)+,d2	; go next char 
	bne.s	noreset		; if D2 != 0 print char
	lea	TEXT(PC),a0	; if D2 == 0 restart TEXT
	move.b	(a0)+,d2	; first char in D2
noreset
	sub.b	#$20,d2		; subtract 32 to ASCII value
	add.l	d2,d2		; multiply by 2 because font
				; is 16 pixel width
	move.l	d2,a2

	add.l	#FONT,a2	; get FONT...

	move.l  a0, text_offset_pointer
	
	BLTWAIT BWT7

	move.l	#$09f00000,BLTCON0(a5)	; BLTCON0: A-D
	move.l	#$ffffffff,BLTAFWM(a5)	; BLTAFWM + BLTALWM 

	move.l	a2,BLTAPT(a5)	; BLTAPT: font address

	move.l	#BUFFER+40,BLTDPT(a5) 
			; print to not visible screen area
	move.w	#(FONTSET_SCRTXT_WIDTH-FONT_SCRTXT_WIDTH)/8,BLTAMOD(a5) ; BLTAMOD: modulo font
	move.w	#ScrLBpl+2-FONT_SCRTXT_WIDTH/8,BLTDMOD(a5)	  ; BLTDMOD: modulo bit planes
	move.w	#(bpls_L*FONTSET_SCRTXT_HEIGHT*64)+FONT_SCRTXT_WIDTH/16,BLTSIZE(a5) 	; BLTSIZE	
no_print:
	rts

*****************************************************************************
*	Scroll text routine
* 
*	Use BLITTER in DESC mode
*	basically copies the whole screen with
*	full screen width * FONT HEIGHT
*	and shift it by x pixels
*
*****************************************************************************

scroll_text:

; source and dest are the same (point to BUFFER)
; we shift by left so we use DESC mode 
; therefore blitter starts copying
; from right word and ends to left word

	move.l	#BUFFER+(FONT_SCRTXT_HEIGHT*42*bpls_L)-2,d0 ; source and dest address

	BLTWAIT BWT8

	move.w	#$29f0,BLTCON0(a5)	; BLTCON0 copy from A to D ($F) 
					; 1 pixel shift, LF = F0
	move.w	#$0002,BLTCON1(a5)	; BLTCON1 use blitter DESC mode
					

	move.l	#$ffff7fff,BLTAFWM(a5)	; BLTAFWM / BLTALWM
					; BLTAFWM = $ffff - 
					; BLTALWM = $7fff = %0111111111111111
					; mask the left bit


	move.l	d0,BLTAPT(a5)			; BLTAPT - source
	move.l	d0,BLTDPT(a5)			; BLTDPT - dest

	; scroll an image of the full screen width * FONT_SCRTXT_HEIGHT

	move.l	#$00000000,BLTAMOD(a5)	; BLTAMOD + BLTDMOD 
	move.w	#(FONT_SCRTXT_HEIGHT*bpls_L*64)+21,BLTSIZE(a5)	; BLTSIZE
	rts					


copy_text_buffer_to_screen:
	
	BLTWAIT BWT3

	move.w	#$09f0,BLTCON0(a5)	; BLTCON0 copy from A to D ($F) 
	move.w	#$0000,BLTCON1(a5)	; BLTCON1 use blitter ASC mode
					

	move.l	#$ffffffff,BLTAFWM(a5)	; BLTAFWM / BLTALWM
					; BLTAFWM = $ffff  
					; BLTALWM = $ffff 
					

	move.l	#BUFFER,BLTAPT(a5)			; BLTAPT - source
	move.l	#SCREEN_L+SCREEN_VOFFSET,BLTDPT(a5)	; BLTDPT - dest

	; scroll an image of the full screen width * FONT_SCRTXT_HEIGHT

	move.l	#$00020000,BLTAMOD(a5)	; BLTAMOD + BLTDMOD 
	move.w	#(FONT_SCRTXT_HEIGHT*bpls_L*64)+20,BLTSIZE(a5)	; BLTSIZE
	rts			


	
	
	
	
****************************************************
*
*
*	-----------------------------------
*	x0/xd0		x1		 x2
*			 |
*		  	 |
*			 |
*			y1
*
****************************************************
	
	
x0:	dc.w	0
x1:	dc.w	0	; pixel between left margin and x1
;x2:	dc.w	0
xd0:	dc.w	0	; delta x (xe = x0 >= 0 ? 0 : abs(x)/2)
y1:	dc.w	0	; vertical distance between y1 and x1 in pixel

w_x0:	dc.w	0	; x0 in word


s_x0:	dc.w	0	; x point where sine starts
s_x1:	dc.w	0	; x point where delta change
s_x2:	dc.w	0	; x point where sine ends

w_sine_length:	dc.w	0	; sine length in word

sprite_x:	dc.w	0
sprite_y:	dc.w	0
SPRITE_WIDTH	= 30
SPRITE_HEIGHT	= 30

MOUSEX_SPRITE_POINTER = SPRITE_WIDTH/2
MOUSEY_SPRITE_POINTER = SPRITE_HEIGHT+1

compute_offset:

	move.w	sprite_x(pc), x1
	add.w	#MOUSEX_SPRITE_POINTER, x1
	move.w	sprite_y(pc), d0
	add.w	#MOUSEY_SPRITE_POINTER, d0
	sub.w	#SCRTEXT_V_OFFSET+h_H, d0	; SCREEN_L starts when h_H ends
	tst	d0
	bge	compute_all_offset
	moveq	#0, d0

compute_all_offset:
	move.w	d0, y1
	
get_w_x1:
	move.w	y1(pc), d2
	add.w	d2, d2		; y1 * 2 (sine projection)
	
	move.w	x1(pc), d0
	sub.w	d2, d0		
	
	move.w	d0, x0		; x0
	tst.w	d0
	bge.s	save_w_x0
	moveq	#0, d0
save_w_x0:
	lsr	#4, d0
	move.w	d0, w_x0	; w_x0
	
	move.w	x1(pc), d0
	add.w	d2, d0
	move.w	d0, d1
	lsr	#4, d0
	and.w	#%1111, d1	; check if mod 16 > 0
	tst	d1
	beq.s	check_w_x0_pos
	addq	#1, d0
check_w_x0_pos:
	
	move.w	w_x0(pc), d3	; w_x0 to d3
	
	sub.w	d3, d0
	tst	d0
	bne.s	w_x0_not_negative
	moveq	#1, d0			; w_sine_length is at least 1
w_x0_not_negative:
	move.w	d0, d1			; w_x2 - w_x0
	move.w	d1, d2
	add.w	d3, d1
	cmpi.w	#20, d1			; check if w_x0 + sine_length 
	ble.s	set_word_loop_cnt	; goes beyond screen right margin
	move.w	#20, d2
	sub.w	d3, d2		; force sine_length to 20 - w_x0
set_word_loop_cnt:
	move.w	d2, d0
	move.w	d0, w_sine_length	; w_sine_length
		
	move.w	#ScrLBpl*bpls_L, d1	; const delta y	
	
	move.w	y1(pc), d3
	add.w	d3, d3		; y1 * 2 (sine projection)	
	
	move.w	x0(pc), d2
	tst	d2
	bge.s	s_x0_not_negative	; check if x0 > 0

s_x0_negative:
	clr.w	s_x0	; s_x0
	move.w	x1(pc), d0
	move.w	d0, s_x1	; s_x1
	add.w	d3, d0	
	move.w	d0, s_x2	; s_x2

	move.w	x0(pc), d0
	neg.w	d0
	lsr	#1, d0
	mulu	d1, d0		
	move.w	d0, xd0		; set delta x
	
	bra.s	init_loop
	
s_x0_not_negative:
	clr.w	xd0
	and.w	#%1111, d2	; modulo 16 of x0
	
	move.w	d2, s_x0	; s_x0	
	add.w	d3, d2
	move.w	d2, s_x1	; s_x1
	add.w	d3, d2	
	move.w	d2, s_x2	; s_x2

init_loop:

	move.w	s_x1(pc), d2	
	btst	#0, d2		; add 1 if s_x1 is odd
	beq.s	init_counter
	addq.w	#1, d2
init_counter:

	move.w	d2, s_x1	
	
	rts


********************************************
*
*	clear scrolling text area routine
*	
*     	clear possible dirty area
*
********************************************

clear_scrtxt_area:

	BLTWAIT BWT4
	
	; clear under text area
	
	move.w	#$0100,BLTCON0(a5)	; BLTCON0 delete (only D)
	move.w	#$0000,BLTCON1(a5)	; BLTCON1 use blitter ASC mode
	move.l	#$ffffffff,BLTAFWM(a5)	; BLTAFWM / BLTALWM
	move.l	#0,BLTAPT(a5)		; BLTAPT - source	
	move.l	#SCREEN_L+SCREEN_VOFFSET+(FONT_SCRTXT_HEIGHT*ScrLBpl*bpls_L),BLTDPT(a5)	; BLTDPT - dest
	move.w	#0, BLTAMOD(a5)	; BLTAMOD
	move.w	#ScrLBpl-40, BLTDMOD(a5)	; BLTDMOD
	move.w	#((h_L-SCRTEXT_V_OFFSET-FONT_SCRTXT_HEIGHT)*bpls_L*64)+20, BLTSIZE(a5)	; BLTSIZE
	
	BLTWAIT BWT5
	
	; clear text where sine is involved
		
	lea	SCREEN_L+SCREEN_VOFFSET, a0	
	move.w	w_x0(pc), d0
	add.w	d0, d0			; in bytes
	lea	(a0,d0.w), a0	
	move.l	a0, BLTDPT(a5)		; BLTDPT
	
	move.w	w_sine_length(pc), d1
	
	move.w	#ScrLBpl, d0
	sub.w	d1, d0
	sub.w	d1, d0
	move.w	d0, BLTDMOD(a5)		; BLTDMOD
	
	move.w	w_sine_length(pc), d2
	move.w	#(FONT_SCRTXT_HEIGHT*bpls_L*64), d0
	add.w	d2, d0			; BLTAMOD
	move.w	d0, BLTSIZE(a5)		; BLTSIZE
	
	rts

	
	
	
	
make_camel:
	
	lea	BUFFER, a1
	move.w	w_x0(pc), d0
	add.w	d0, d0
	lea	(a1,d0.w), a1
	
	lea	SCREEN_L+SCREEN_VOFFSET, a2
	lea	(a2,d0.w), a2
	
	move.w	xd0(pc), d0	
	move.w	#ScrLBpl*bpls_L, d1	; const delta y		
	moveq	#0, d2		; sine counter
	move.w	s_x0(pc), d3	; move s_x0 to d3
	move.w	s_x2(pc), d4	; move s_x2 to d4		
	move.w	#$C000, d5
	
	move.w	w_sine_length(pc), d6	; word loop cnt	
	subq	#1, d6
	
word_loop:
	moveq	#8-1, d7		; slice loop cnt
slice_loop:	
	cmp.w	d3, d2		; check if x0 is reached	
	blt.s	start_slice	
	cmp.w	s_x1(pc), d2	; check if x1 is reached	
	bne.s	add_delta
	neg.w	d1		; y1 is reached, set direction up
add_delta:
	cmp.w	d4, d2		; check if x2 is reached	
	bge.s	start_slice
	add.w	d1, d0
start_slice:
	addq	#2, d2	
	move.l	a2, a3
	add.w	d0, a3
	
	BLTWAIT BWT6

	move.w	#$ffff, BLTAFWM(a5)	; BLTAFWM
	move.w	d5, BLTALWM(a5)		; BLTALWM 

	move.l	#$0bfa0000, BLTCON0(a5)	; BLTCON0/BLTCON1 - A,C,D
					; D=A OR C

	move.w	#$0026, BLTCMOD(a5)	; BLTCMOD=40-2=$26
	move.l	#$00280026, BLTAMOD(a5)	; BLTAMOD=42-2=$28
					; BLTDMOD=40-2=$26

	move.l	a1, BLTAPT(a5)		; BLTAPT  
	move.l	a3, BLTCPT(a5)		; BLTCPT
	move.l	a3, BLTDPT(a5)		; BLTDPT
	move.w	#(FONT_SCRTXT_HEIGHT*bpls_L*64)+1, BLTSIZE(a5)	; BLTSIZE
	
	ror.w	#2, d5			; right shift mask of 2 pixel

	dbra	d7, slice_loop

	addq.w	#2, a1			; point to next word
	addq.w	#2, a2			; point to next word
	
	dbra	d6, word_loop

exit_sine_loop:
	
	rts
	
TEXT:
	dc.b	"THIS IS A SCROLLING TEXT EXAMPLE..."
	dc.b	"HOPE YOU LIKE IT !!!    "
	EVEN

	
	
	

    


******************************************************
*
*	sprite_animation routine
*
*	this routine animate the sprite
*       by scrolling each frame on top, 
*       then placing the first frame on last position
*       doing a continue rotation cycle
*
*
******************************************************

ANIMATION_SLOW = 4
ANIMATION_FAST = 2

animation_frame_delay:	dc.w	ANIMATION_SLOW

animation_counter:	dc.w    0


SPRITE_FRAME_OFFSET = $80 ; distance between frames

sprite_animation:
	move.w	animation_counter(pc), d0
	addq	#1, d0 ; increase animation_counter
	move.w	d0, animation_counter
	cmp.w   animation_frame_delay, d0
	bne.w   do_nothing     ; do not cycle next animation frame
	clr.w   animation_counter

	move.w	#ANIMATION_FAST, animation_frame_delay
check_bottom_0:	; if ball is above scrolling text, slow down
	move.w	sprite_y(pc), d0
	cmpi.w	#SCRTEXT_V_OFFSET, d0
	bgt.s	roll_frame
	move.w	#ANIMATION_SLOW, animation_frame_delay

roll_frame:
	lea FRAMETAB(PC),a0 ; 
	move.l  (a0),d0     ; save current first frame address to d0
	move.l  4(a0),(a0)  ; scroll frame to 1st position
	move.l  4*2(a0),4(a0)   ; scroll frame to 2nd position
	move.l  4*3(a0),4*2(a0) ; scroll frame to 3rd position
	move.l  4*4(a0),4*3(a0) ; scroll frame to 4th position
	move.l  4*5(a0),4*4(a0) ; scroll frame to 5th position
	move.l  4*6(a0),4*5(a0) ; scroll frame to 6th position
	move.l  4*7(a0),4*6(a0) ; scroll frame to 7th position
	move.l  d0,4*7(a0)  ; put saved frame to last position

	move.l  FRAMETAB(PC),d0 ; SPRITE_1 address
	lea SPRITEPOINTERS,a1 ; SPRITE pointer
	move.w  d0,6(a1) ; copy L word of sprite address to pointer
	swap    d0       ; swap the the two words
	move.w  d0,2(a1) ; copy the H word of sprite address to pointer
	swap    d0

	add.l   #sprite_frame_offset,d0  ; the sprite is $44 bytes ahead    
	addq    #8,a1    ; move SPRITE_POINTERS pointer to next sprite
	move.w  d0,6(a1) ; copy L word of sprite address to pointer
	swap    d0       ; swap the the two words
	move.w  d0,2(a1) ; copy the H word of sprite address to pointer 
	swap    d0

	add.l   #sprite_frame_offset,d0  ; the sprite is $44 bytes ahead    
	addq    #8,a1    ; move SPRITE_POINTERS pointer to next sprite
	move.w  d0,6(a1) ; copy L word of sprite address to pointer
	swap    d0       ; swap the the two words
	move.w  d0,2(a1) ; copy the H word of sprite address to pointer 
	swap    d0

	add.l   #sprite_frame_offset,d0  ; the sprite is $44 bytes ahead    
	addq    #8,a1    ; move SPRITE_POINTERS pointer to next sprite
	move.w  d0,6(a1) ; copy L word of sprite address to pointer
	swap    d0       ; swap the the two words
	move.w  d0,2(a1) ; copy the H word of sprite address to pointer 
	
do_nothing:
	rts


; This is the tab of frames which create the sprite animation
; Every time the framex is loaded, it scroll to the end of the tab
; so that the others frames scroll up

FRAMETAB:
	dc.l    frame1
	dc.l    frame2
	dc.l    frame3
	dc.l    frame4
	dc.l    frame5
	dc.l    frame6
	dc.l    frame7
	dc.l    frame8
    

BALL_HEIGHT = 30
BALL_WIDTH = 30


sprite_move:
	addq.l  #1,tab_y_pointer     ; point to next TAB Y
	move.l  tab_y_pointer(PC),a0 ; copy pointer y to A0
	cmp.l   #ENDTABY-1,a0  ; check if Y end is reached
	bne.s   move_y_tab  ; 
	move.l  #TABY-1,tab_y_pointer ; reset to first tab Y
move_y_tab:
	moveq   #0,d4       ; clean D4
	move.b  (a0),d4     ; copy Y value to D4

	addq.l  #2,tab_x_pointer ; point to next TAB X
	move.l  tab_x_pointer(PC),a0 ; copy pointer x to a0
	cmp.l   #ENDTABX-2,a0 ; check if X end is reached
	bne.s   move_x_tab
	move.l  #TABX-2,tab_x_pointer ; reset to first tab X
move_x_tab:
	moveq   #0,d3       ; clean D3
	move.w  (a0),d3 ; copy X value to D3

	moveq   #0,d2	; clean D2

	move.l  FRAMETAB(PC),a1 ; indirizzo sprite 0
	move.w  d4,d0       ; copy Y to D0
	move.w  d3,d1       ; copy X to D1
	
	move.w	d1, sprite_x
	move.w	d0, sprite_y
	
	move.b  #BALL_HEIGHT,d2     ; copy Height to D2
	bsr.s   generic_sprite_move ; 

	lea sprite_frame_offset(a1),a1  ; move to next sprite
	move.w  d4,d0       ; prepare variables
	move.w  d3,d1
	bsr.s   generic_sprite_move 

	lea sprite_frame_offset(a1),a1  ; move to next sprite
	add.w   #BALL_WIDTH/2,d3    ; the last half of the ball
	move.w  d4,d0       
	move.w  d3,d1
	bsr.s   generic_sprite_move 

	lea sprite_frame_offset(a1),a1  ; move to next sprite
	move.w  d4,d0       
	move.w  d3,d1
	bsr.s   generic_sprite_move 

check_bottom_1:
	move.l	tab_y_pointer, d1
	lea	TABY+220, a0
	cmp.l	a0, d1
	bne.s	check_bottom_2
	move.w	#$0012, SPRITE_PRIORITY
check_bottom_2:
	lea	TABY+320, a0
	cmp.l	a0, d1
	bne.s	exit_sprite_move
	move.w	#0, SPRITE_PRIORITY

exit_sprite_move:   
	rts

burp:	dc.l	0,0,0,0
    

*************************************
*   generic_sprite_move             *
*                                   *
*   <INPUT>                         *
*   A1: SPRITE DATA                 *
*   D0: Y SPRITE COORD              *
*   D1: X SPRITE COORD              *
*   D2: H SPRITE COORD              *
*                                   *
*************************************
generic_sprite_move: 
; vertical position section
	add.w   #$2c,d0     ; add vertical offset to y 

	move.b  d0,(a1)     ; copy Y to VSTART
	btst.l  #8,d0       ; check if Y > $FF
	beq.s   no_vstart_set
	bset.b  #2,3(a1)    ; if Y > $FF, set VSTART bit
	bra.s   check_vstop
no_vstart_set:
	bclr.b  #2,3(a1)    ; if Y <= $FF, clear VSTART bit
check_vstop:
    
	add.w   d2,d0       ; add HEIGHT to Y 
			; in order to check final position
	move.b  d0,2(a1)    ; add Y+H to VSTOP
	btst.l  #8,d0       ; check if Y+H > $FF
	beq.s   no_vstop_set
	bset.b  #1,3(a1)    ; set VSTOP bit (Y+H > $FF)
	bra.s   check_x_coord
no_vstop_set:
	bclr.b  #1,3(a1)    ; clear VSTOP bit (Y+H <= $FF)
check_x_coord:

; horizontal position section
	add.w   #128,d1     ; 128 - sprite center
	btst    #0,d1       ; is odd x position ?
	beq.s   clear_hstart_bit
	bset    #0,3(a1)    ; set HSTART bit (odd position)
	bra.s   translate_hstart_coord

clear_hstart_bit:
	bclr    #0,3(a1)    ; clear HSTART bit (even pos)
translate_hstart_coord:
	lsr.w   #1,d1       ; shift x position to right, translate x
	move.b  d1,1(a1)    ; set x to HSTART byte
	rts

tab_x_pointer:
	dc.l TABX-2
    
tab_y_pointer
	dc.l TABY-1

****************
*
*	TABX
*
****************


TABX:

	incdir	"dh1:own/demo/repository/demo/3/"
	incbin	"coord_X"	


ENDTABX


****************
*
*	TABY
*
****************

    
TABY:

	incdir	"dh1:own/demo/repository/demo/3/"
	incbin	"coord_Y"

ENDTABY
	
	
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
	dc.w	$e8,$0000,$ea,$0000	;third bitplane
	dc.w	$ec,$0000,$ee,$0000	;fourth bitplane
	
	dc.w	$0104
SPRITE_PRIORITY:
	dc.w	$0000
	
	dc.w	$0180,$0000	; color0

	
	
;180-182 -> depth 1
;184-186 -> depth 2
;188-18e -> depth 3
;190-19e -> depth 4
	
CLR_STRT = $182
PALETTE:	

	dc.w CLR_STRT+00,$0cb2,CLR_STRT+02,$0ee3,CLR_STRT+04,$0ffd
	dc.w CLR_STRT+06,$0a81,CLR_STRT+08,$0860,CLR_STRT+10,$0640
	dc.w CLR_STRT+12,$0420

	dc.w CLR_STRT+14,$000a,CLR_STRT+16,$0cb2,CLR_STRT+18,$0ee3
	dc.w CLR_STRT+20,$0ffd,CLR_STRT+22,$0a81,CLR_STRT+24,$0860
	dc.w CLR_STRT+26,$0000





START_LORES = ($2c+h_H)*$100+07

	dc.w	START_LORES,$fffe

*********** LORES **************	
	
	dc.w	$92,$0038	; DdfStart
	dc.w	$94,$00d0	; DdfStop
	dc.w	$102,0	; BplCon1
	dc.w	$108,(ScrLBpl*(bpls_L-1))	; Bpl1Mod
	dc.w	$10a,(ScrLBpl*(bpls_L-1))	; Bpl2Mod
	
	dc.w	$100,bpls_L*$1000+$200	; bplcon0 - bitplane lores
	
BPLPOINTERS_L:
	dc.w	$e0,$0000,$e2,$0000	;first bitplane
	dc.w	$e4,$0000,$e6,$0000	;second bitplane


	; ball sprite color palette (from 17 to 31)

	dc.w	$01a2,$0fc8,$01a4,$0c11,$01a6,$0ff5
	dc.w	$01a8,$0c87,$01aa,$0a99,$01ac,$0d9c,$01ae,$0fff
	dc.w	$01b0,$0ccc,$01b2,$0b4b,$01b4,$0f30,$01b6,$0fcd
	dc.w	$01b8,$0a11,$01ba,$0f96,$01bc,$0f5e,$01be,$0f9e
	
	
	dc.w	$0180,$0000	; color0
	dc.w	$0182,$00af	; color1
	dc.w	$0184,$0000	; color2
	dc.w	$0186,$0000	; color3

BEGIN_LORES_COPPER:
	dc.w	START_LORES+$100,$fffe
	dc.w	$0180, $0f00
	dc.w	START_LORES+$200,$fffe
	dc.w	$0180, $0000
	
BARCOPPER:			
	dcb.w	COPLINES*4,0	; 100*4 = 400 words
	
	dc.w	$0180,$0000	; color0
	dc.w	$0182,$08f6	; color1
	dc.w	$0184,$04b2	; color2
	dc.w	$0186,$0270	; color3

	DC.W	$ffdf,$fffe
	
	dc.w	$FFFF,$FFFE	; End of copperlist


*****************************************
*             BALL SPRITE               *
*                                       *
*        4 sprites, 8 anim frames       *
*                                       *
*****************************************
    
frame1:

	dc.w $0000,$0000
	dc.w $0002,$001e,$001c,$00ee,$017c,$02be,$0478,$07fe
	dc.w $0df8,$0efe,$1ff8,$1ffe,$3ff0,$3ffe,$3dfe,$3efe
	dc.w $781e,$7ffe,$703e,$7fde,$703e,$7ffe,$e03e,$fffe
	dc.w $e07e,$ffbe,$c07e,$ffbe,$c07e,$ffbe,$407e,$fffe
	dc.w $607e,$fffe,$787e,$f7fe,$7f7e,$fcfe,$7ffe,$7ffe
	dc.w $7fde,$7fa0,$7fc0,$3ffe,$3f80,$3ffe,$3f80,$1ffe
	dc.w $0a40,$0a38,$0840,$0000,$0380,$0000,$00c0,$0000
	dc.w $0028,$0000,$001e,$0000
	dc.w 0,0



frame1a:
	dc.w $0000,$0080
	dc.w $0002,$001c,$0014,$00f2,$017c,$03c2,$0478,$0386
	dc.w $0df8,$0306,$1df0,$000e,$3ff0,$000e,$3df8,$0706
	dc.w $781e,$07e0,$701e,$0fc0,$601e,$1fc0,$e01e,$1fc0
	dc.w $e07e,$1fc0,$c07e,$3fc0,$c03e,$3f80,$403e,$bf80
	dc.w $603e,$9fc0,$703e,$8780,$7d7e,$8180,$7f1c,$00a2
	dc.w $3f9e,$003e,$7fc0,$4078,$3fc0,$0060,$1f40,$0080
	dc.w $0806,$17c6,$083e,$07fe,$07fe,$043e,$03be,$037e
	dc.w $00f6,$00de,$001e,$0000
	dc.w 0,0

    
frame1b:

	dc.w $0000,$0000
	dc.w $8000,$f000,$6000,$fe00,$7800,$ff80,$3c40,$ff80
	dc.w $3e60,$ffa0,$3ff0,$dff0,$1ff0,$ff70,$fe30,$fdf0
	dc.w $f034,$ffd0,$f804,$ffe0,$f804,$fff0,$f806,$fff0
	dc.w $f806,$fff0,$f806,$ffe0,$fc04,$ffe0,$fc00,$ffc0
	dc.w $f804,$ff80,$f01c,$f700,$ee7c,$e800,$83fc,$8800
	dc.w $d3fc,$2000,$03f8,$c000,$03f8,$8000,$03f8,$0000
	dc.w $03f0,$0000,$03e0,$0000,$0380,$0000,$0600,$0000
	dc.w $1800,$0000,$f000,$0000
	dc.w 0,0



frame1c:
	dc.w $0000,$0080
	dc.w $8000,$7000,$6000,$9e00,$7800,$8780,$3c00,$c380
	dc.w $3f60,$c1c0,$1ff0,$c080,$1f70,$e008,$0830,$e5c8
	dc.w $f034,$0fe8,$f804,$0ff8,$f004,$0fd8,$f80e,$07c0
	dc.w $fc0e,$0788,$fc1e,$0718,$fc1e,$061a,$fc3e,$043e
	dc.w $fc7e,$007a,$f4ee,$08f2,$c5be,$3bc2,$8dfc,$7200
	dc.w $4ffc,$dc00,$3ffc,$3c04,$7ff8,$7c00,$fff8,$fc00
	dc.w $fff0,$fc00,$ffe0,$fc00,$ffc0,$fc40,$ff80,$f980
	dc.w $f600,$ee00,$f000,$0000
	dc.w 0,0

frame2:


	dc.w $0000,$0000
	dc.w $0000,$001e,$0088,$00f6,$03c2,$03fc,$05ea,$07f4
	dc.w $0bee,$0ff6,$17fe,$1bfe,$2ffe,$33ee,$278e,$3ffe
	dc.w $7e0e,$7df6,$7c06,$7ffe,$7c06,$7ffa,$7c02,$fffe
	dc.w $fc02,$7ffc,$fc00,$fffe,$fc00,$fffe,$fc00,$fffe
	dc.w $fc02,$fffc,$fe1e,$ffe6,$fffe,$fe7e,$7ffe,$7ffe
	dc.w $03fe,$7dfe,$41f8,$7ff8,$01e8,$3ee8,$20a0,$3fa0
	dc.w $0006,$1f00,$003e,$0f80,$003e,$0000,$021e,$0000
	dc.w $00e0,$0000,$0018,$0000
	dc.w 0,0


frame2a:
	dc.w $0000,$0080
	dc.w $0000,$001e,$0088,$007e,$00c2,$003e,$05e8,$021c
	dc.w $09fe,$0418,$17fe,$0c00,$2ff6,$1c10,$230e,$18f0
	dc.w $7e0e,$03f8,$3c04,$03f8,$7806,$07fc,$7c00,$83fc
	dc.w $f802,$87fe,$7c00,$03fe,$fc00,$03fe,$fc00,$03fe
	dc.w $7c02,$03fe,$fe12,$03f4,$7d9e,$03e0,$3dfe,$4200
	dc.w $00fc,$7c02,$40f8,$7e06,$00e0,$3e1e,$2000,$3ffe
	dc.w $0086,$0478,$007e,$0000,$07fe,$07c0,$01fe,$03c0
	dc.w $00fe,$001e,$001e,$0006
	dc.w 0,0

    
frame2b:

	dc.w $0000,$0000
	dc.w $1000,$f000,$3e00,$de00,$7f00,$ff80,$ffc0,$ffc0
	dc.w $ffe0,$ffe0,$fff0,$fff0,$fff8,$fff0,$fff0,$fff8
	dc.w $fff0,$ffe8,$fff0,$ffe8,$ffe0,$ffd8,$ffc0,$ffb0
	dc.w $ff80,$fe70,$fe00,$7de0,$fc00,$7be0,$7000,$8fc0
	dc.w $e000,$df80,$e000,$ff00,$e002,$ee00,$a000,$b800
	dc.w $9804,$8000,$180c,$0000,$7818,$0000,$fc78,$0000
	dc.w $fcf0,$0000,$ffe0,$0000,$f1c0,$0000,$8180,$0000
	dc.w $0000,$0000,$0000,$0000
	dc.w 0,0


frame2c:
	dc.w $0000,$0080
	dc.w $0000,$e000,$1c00,$c200,$7f00,$8080,$ffc0,$0000
	dc.w $ffe0,$0000,$fff0,$0000,$fff0,$0008,$fff0,$0000
	dc.w $ffe4,$0004,$ffc4,$0034,$ffa4,$0064,$7f4e,$00ce
	dc.w $fe8e,$008e,$381e,$051e,$f41e,$8e1e,$103e,$9c3e
	dc.w $007e,$d87e,$d0fe,$30fe,$d1fe,$21fc,$97fc,$67fc
	dc.w $97fc,$6ff8,$17fc,$eff0,$7ff8,$87e0,$fbb8,$07c0
	dc.w $fff0,$0300,$fbe0,$0400,$ffc0,$0e00,$ff80,$7e00
	dc.w $fe00,$fe00,$f000,$f000
	dc.w 0,0



frame3:


	dc.w $0000,$0000
	dc.w $001c,$001e,$003e,$00fe,$00fe,$03fe,$03fe,$07fe
	dc.w $07fe,$0ffe,$0ffe,$1ffe,$3ffe,$3ffe,$3ffe,$3ffe
	dc.w $7ffe,$3ffe,$3ffc,$7ffa,$3ff0,$7ffe,$3fe0,$ffde
	dc.w $3f80,$fffe,$3f00,$fefe,$3c00,$dffe,$3800,$d7fe
	dc.w $7000,$bffe,$f000,$7ffe,$f800,$fffe,$7800,$7ffe
	dc.w $7c00,$7ffe,$7e00,$7dfe,$3e00,$3ffc,$3f02,$3ff0
	dc.w $0a06,$0ae0,$003e,$0000,$061e,$0000,$000e,$0000
	dc.w $0002,$0000,$0000,$0000
	dc.w 0,0


frame3a:
	dc.w $0000,$0080
	dc.w $001c,$0002,$003e,$00c0,$00fe,$0300,$01fe,$0600
	dc.w $07fe,$0800,$0ffe,$1000,$3ffe,$0000,$1ffe,$0000
	dc.w $5ffc,$4002,$3ffc,$4006,$3fe0,$401e,$1fe0,$c03e
	dc.w $3f00,$c0fe,$1f00,$c1fe,$1800,$c7fe,$2000,$e7fe
	dc.w $3000,$8ffe,$f800,$8ffe,$f000,$0ffe,$7c00,$07fe
	dc.w $7800,$07fc,$7e00,$03f8,$3d02,$03e4,$1f0e,$2100
	dc.w $0a9e,$1500,$00fe,$0f00,$07fe,$01e0,$03fe,$03f0
	dc.w $00fe,$00fc,$001e,$001e
	dc.w 0,0



frame3b:

	dc.w $0000,$0000
	dc.w $0000,$f000,$c000,$fe00,$f000,$ff80,$fbc0,$fdc0
	dc.w $ffe0,$ffe0,$fff0,$fbf0,$f1f0,$eff0,$c0f0,$bff0
	dc.w $00f4,$ff70,$0074,$ffb0,$0024,$ffc0,$002c,$ffc0
	dc.w $000c,$ffe0,$0008,$ffe0,$0010,$ffe0,$0030,$ffc0
	dc.w $00f0,$ff00,$00f8,$fe00,$01f8,$f800,$03f8,$f000
	dc.w $0ff8,$d000,$1ff8,$c000,$7ff8,$8000,$fff8,$0000
	dc.w $ffe0,$0000,$ffc0,$0000,$ff00,$0000,$fe00,$0000
	dc.w $f800,$0000,$2000,$0000
	dc.w 0,0


frame3c:    
	dc.w $0000,$0080
	dc.w $0000,$f000,$c000,$3e00,$e000,$1f80,$fbc0,$0600
	dc.w $ffe0,$0000,$f5f0,$0c00,$f1f0,$1e08,$8070,$3f08
	dc.w $00a4,$ff98,$0074,$ffc8,$0004,$ffd8,$002e,$ffb2
	dc.w $001c,$ff80,$001e,$ff16,$001c,$fe0c,$003e,$fc0e
	dc.w $007c,$f88c,$01fe,$e806,$07fc,$e004,$0ffc,$8004
	dc.w $3ffc,$8004,$7ffc,$0004,$fff0,$0008,$fff8,$0000
	dc.w $fff0,$0010,$ffe0,$0020,$ffc0,$00c0,$ff80,$0180
	dc.w $fe00,$0600,$f000,$d000
	dc.w 0,0


frame4:


	dc.w $0000,$0000
	dc.w $0000,$001e,$0088,$00f6,$03a6,$03de,$07be,$07fe
	dc.w $0ffe,$0ffe,$1ffe,$1f7e,$3e7e,$3dfe,$387e,$3ffe
	dc.w $713e,$7efe,$643e,$7bfe,$403e,$7fde,$801e,$fffe
	dc.w $801e,$7fee,$000e,$fffe,$003c,$ffca,$007e,$ffbe
	dc.w $01fe,$fefe,$03fe,$fdfe,$07fe,$fbfe,$0ffe,$77fe
	dc.w $1ffe,$6ffe,$1ffa,$7ffa,$3fe8,$1fe8,$3fc2,$3fc0
	dc.w $0a06,$0a00,$003e,$0000,$07fe,$0000,$01f8,$0000
	dc.w $0070,$0000,$0010,$0000
	dc.w 0,0


frame4a:
	dc.w $0000,$0080
	dc.w $0000,$001e,$0088,$00fe,$03a6,$0078,$079e,$0060
	dc.w $0ffe,$0000,$1f7e,$0000,$3c7e,$0180,$383e,$0780
	dc.w $711e,$0fc0,$642e,$1fc0,$402e,$3fe0,$8006,$7fe0
	dc.w $801e,$fff0,$0002,$fff0,$0028,$ffe2,$003e,$ff82
	dc.w $017c,$ff82,$01fc,$fc02,$03fe,$f800,$07fe,$7000
	dc.w $1ffc,$7002,$1ffa,$6004,$3fe0,$201e,$3f42,$20bc
	dc.w $0806,$17f8,$003e,$0fc0,$07fc,$0002,$03fe,$0206
	dc.w $00fe,$008e,$000e,$001e
	dc.w 0,0


frame4b:

	dc.w $0000,$0000
	dc.w $7000,$b000,$3e00,$de00,$f880,$ff80,$fc00,$ffc0
	dc.w $fe00,$fde0,$fe00,$fff0,$ff00,$fff0,$ff00,$fff8
	dc.w $ff00,$fff8,$ff80,$ff78,$ffc0,$ffb0,$feec,$fd60
	dc.w $f00e,$ef80,$805c,$7f80,$003e,$ff80,$003c,$ffc0
	dc.w $003e,$ff80,$003c,$ff00,$803c,$7e00,$c03c,$b800
	dc.w $403c,$7000,$0030,$4000,$6080,$0000,$e788,$0000
	dc.w $ff90,$0000,$8fa0,$0000,$0740,$0000,$0600,$0000
	dc.w $0200,$0000,$0000,$0000
	dc.w 0,0

frame4c:
	dc.w $0000,$0080
	dc.w $3000,$8000,$0e00,$c000,$f880,$0700,$f800,$07c0
	dc.w $fe00,$03e0,$fe00,$01f0,$ff08,$01f0,$fe00,$01f0
	dc.w $ff84,$00e4,$ff04,$0074,$fe3c,$0184,$f28e,$0fb2
	dc.w $d00e,$3ff0,$805c,$ff60,$007e,$fe00,$003e,$fc02
	dc.w $007e,$f840,$80fc,$e8c0,$01fe,$61c2,$07fc,$c7c0
	dc.w $4ffc,$cfc0,$7ffc,$bfcc,$5ff8,$bf78,$fbf8,$1c70
	dc.w $eff0,$1060,$ffe0,$7040,$ffc0,$f880,$ff80,$f980
	dc.w $fe00,$fc00,$f000,$f000
	dc.w 0,0

frame5:

	dc.w $0000,$0000
	dc.w $001e,$001e,$007e,$00be,$01c0,$03fe,$07d0,$03ee
	dc.w $0fc0,$0ffe,$1fc0,$1ffe,$3fc0,$3ffe,$3fc0,$3ffe
	dc.w $7fc0,$3ffe,$7ffe,$7fde,$7ffe,$7ffe,$7ffe,$fe7e
	dc.w $787e,$fffe,$607e,$fffe,$407e,$fffe,$c07e,$ffbe
	dc.w $c07e,$ffbe,$e03e,$fffe,$e03e,$fffe,$703e,$7fde
	dc.w $701e,$7ffe,$7818,$7fe8,$38f0,$3f02,$3fa0,$3dae
	dc.w $0a10,$0c08,$0038,$0700,$0078,$0000,$001c,$0000
	dc.w $000c,$0000,$0002,$0000
	dc.w 0,0


frame5a:
	dc.w $0000,$0080
	dc.w $001e,$0000,$005c,$00c2,$00c0,$023e,$03d0,$003e
	dc.w $0fc0,$003e,$1fc0,$003e,$1fc0,$003e,$3fc0,$003e
	dc.w $3fc0,$003e,$7fe0,$003e,$7ffe,$0000,$3ebe,$8080
	dc.w $707e,$8f80,$203e,$9f80,$403e,$bf80,$c01e,$3f80
	dc.w $c07e,$3fc0,$c01e,$3fc0,$e01e,$1fc0,$701e,$1fc0
	dc.w $701c,$0fe2,$7000,$0fee,$3cec,$07e0,$3a20,$07d0
	dc.w $0e16,$13e6,$003e,$08c6,$07fe,$0786,$03fe,$03e2
	dc.w $00fe,$00f2,$001e,$001c
	dc.w 0,0

frame5b:


	dc.w $0000,$0000
	dc.w $f000,$f000,$f800,$fe00,$0700,$fe80,$07c0,$ff80
	dc.w $07e0,$ffe0,$07f0,$fbf0,$07f0,$fbf8,$07f0,$fbf0
	dc.w $07f0,$fbf0,$ffe4,$c3e0,$ffe4,$ffe0,$fdcc,$fe00
	dc.w $fc2c,$ffc0,$fc04,$ffe0,$fc00,$ffe0,$fc00,$fbc0
	dc.w $f806,$ff80,$f004,$f700,$e00e,$ee00,$a00c,$a000
	dc.w $801c,$8000,$301c,$0000,$9438,$0000,$1f78,$0000
	dc.w $1f70,$0000,$1e20,$0000,$3c00,$0000,$7800,$0000
	dc.w $6000,$0000,$0000,$0000
	dc.w 0,0


frame5c:
	dc.w $0000,$0080
	dc.w $f000,$0000,$bc00,$4600,$0300,$f980,$03c0,$f840
	dc.w $07e0,$f800,$03f0,$f800,$01f8,$f800,$03f0,$f808
	dc.w $01f4,$f80c,$0be4,$c818,$f8c4,$0538,$fd8e,$03b2
	dc.w $f81c,$07a0,$f81e,$071a,$fc1c,$061c,$fc3e,$043a
	dc.w $f47e,$0c78,$f0fc,$08f8,$c9fe,$31f0,$affc,$57f0
	dc.w $8ffc,$7fe0,$3ffc,$cfe0,$6bf8,$ffc0,$fef8,$e180
	dc.w $fff0,$e080,$ffe0,$c1c0,$ffc0,$c3c0,$f780,$8f80
	dc.w $fe00,$9e00,$f000,$f000
	dc.w 0,0

frame6:

	dc.w $0000,$0000
	dc.w $001c,$001e,$00f8,$00f6,$027e,$03be,$027e,$05fe
	dc.w $01fe,$0e7e,$08fe,$17fe,$23fe,$3cfe,$11fe,$2ffe
	dc.w $47fe,$79fe,$1bfe,$67fe,$7ffe,$7ffe,$fffe,$fefe
	dc.w $fe1e,$ffee,$fc06,$fff8,$fc00,$fffe,$fc00,$fffe
	dc.w $fc00,$fffe,$fc00,$7ffe,$7c02,$fffc,$7c02,$7ffc
	dc.w $7c06,$7ffa,$7c00,$7ff8,$2708,$3ef0,$2382,$3ff0
	dc.w $0206,$0e00,$0222,$0400,$05e0,$0000,$00c0,$0000
	dc.w $0080,$0000,$0000,$0000
	dc.w 0,0



frame6a:
	dc.w $0000,$0080
	dc.w $0018,$0006,$00f0,$0006,$025e,$01c0,$021e,$0780
	dc.w $017e,$0f00,$08fe,$1f00,$227e,$1e00,$11fe,$3e00
	dc.w $47fe,$3e00,$1bfe,$7c00,$7dfe,$0000,$ff7e,$0180
	dc.w $fe06,$03e8,$fc04,$03fc,$fc00,$03fe,$7c00,$03fe
	dc.w $f800,$07fe,$f800,$87fe,$7802,$87fe,$7c00,$07fc
	dc.w $3804,$47fc,$0800,$77fe,$0508,$3fee,$0342,$3cac
	dc.w $001e,$1be0,$023e,$09dc,$07de,$023e,$03fe,$033e
	dc.w $00fe,$007e,$001e,$001e
	dc.w 0,0

frame6b:

	dc.w $0000,$0000
	dc.w $0000,$f000,$0000,$fe00,$c380,$fd80,$fbc0,$ffc0
	dc.w $ffe0,$ffe0,$fff0,$fdf0,$fcf0,$ff70,$fc30,$ffd0
	dc.w $f814,$ffe0,$f80c,$fff0,$f000,$fff8,$f002,$fff8
	dc.w $e000,$fff0,$e000,$ffe0,$7000,$efe0,$f800,$77c0
	dc.w $fa00,$7980,$f100,$7000,$eb80,$e800,$a3c0,$a000
	dc.w $4fe0,$4000,$1ff0,$0000,$7ff0,$0000,$fff0,$0000
	dc.w $fff0,$0000,$ffe0,$0000,$ffc0,$0000,$3f00,$0000
	dc.w $1c00,$0000,$1000,$0000
	dc.w 0,0

 
frame6c:
	dc.w $0000,$0080
	dc.w $0000,$f000,$0000,$fe00,$c180,$3c00,$f1c0,$0c00
	dc.w $fde0,$0000,$fef0,$0300,$fcb0,$03c8,$fc10,$07c8
	dc.w $fc14,$07f8,$f004,$0fe8,$f804,$0fc4,$e006,$1fc4
	dc.w $f00c,$1f8c,$401e,$bf1e,$101c,$fe1c,$b43e,$843e
	dc.w $727c,$0e7c,$70fe,$0ffe,$c3fc,$3c7c,$a3fc,$5c3c
	dc.w $0ffc,$f01c,$1fec,$e01c,$7ff8,$8008,$fff8,$0008
	dc.w $fff0,$0000,$ffe0,$0000,$7fc0,$8000,$ff80,$c080
	dc.w $fe00,$e200,$e000,$f000
	dc.w 0,0


frame7:

	dc.w $0000,$0000
	dc.w $0000,$001e,$0016,$00ee,$009e,$036e,$07be,$07fe
	dc.w $0ffe,$0ffe,$1ffe,$1fbe,$3f1e,$3fee,$3f06,$3ffa
	dc.w $7e00,$7ffe,$7c00,$7ffe,$7c00,$7ffe,$f800,$fffe
	dc.w $f800,$7ffe,$7000,$bffe,$3800,$d7fe,$3c00,$dffe
	dc.w $3f00,$fefe,$3f80,$ff7e,$3fc0,$fffe,$3ff0,$7fee
	dc.w $3ff8,$7ff6,$3ff8,$7ffa,$3fe8,$1fe8,$3fc2,$3fc0
	dc.w $0a0e,$1a00,$003e,$0800,$01fe,$0000,$00fe,$0000
	dc.w $003e,$0000,$0008,$0000
	dc.w 0,0


frame7a:

	dc.w $0000,$0080
	dc.w $0000,$001e,$0010,$00f8,$008e,$03e0,$073e,$00c0
	dc.w $0ffe,$0000,$1ffe,$0040,$3f0e,$00e0,$3f02,$01f8
	dc.w $7c00,$03fe,$7c00,$03fe,$7c00,$07fe,$f800,$07fe
	dc.w $7800,$0ffe,$3000,$8ffe,$3000,$e7fe,$1800,$c7fe
	dc.w $3f00,$c1fe,$1f00,$c07e,$3f80,$c07e,$3fd0,$403e
	dc.w $1fe0,$4014,$3ff0,$400e,$1fe8,$0016,$3f42,$00bc
	dc.w $020e,$0df0,$043e,$03c0,$07fe,$0600,$037e,$0380
	dc.w $00fe,$00c0,$001e,$0016
	dc.w 0,0


frame7b:

	dc.w $0000,$0000
	dc.w $7000,$f000,$f800,$fe00,$fe00,$ff80,$ff80,$ff40
	dc.w $ffc0,$ffe0,$ffe0,$fff0,$fff0,$fff0,$fff0,$fff8
	dc.w $fff0,$fff0,$7ff8,$bff0,$1fe0,$efe0,$07c8,$ffc0
	dc.w $03c8,$fdc0,$0018,$ff80,$0030,$ffc0,$0010,$ffc0
	dc.w $0008,$ff80,$0018,$ff00,$001c,$fe00,$003c,$f800
	dc.w $003c,$f000,$007c,$e000,$8078,$0000,$c0f8,$0000
	dc.w $f1f0,$0000,$fbe0,$0000,$f8c0,$0000,$e000,$0000
	dc.w $c000,$0000,$0000,$0000
	dc.w 0,0

frame7c:
	dc.w $0000,$0080
	dc.w $2000,$9000,$f800,$0600,$fe00,$0180,$ff80,$00c0
	dc.w $ff80,$0060,$ffe0,$0010,$fff0,$0008,$fff8,$0000
	dc.w $7fe4,$801c,$7ffc,$c004,$0fc4,$e03c,$03cc,$fc34
	dc.w $024e,$ffb6,$0094,$ff6c,$003e,$fe0e,$002c,$fc3c
	dc.w $007e,$f876,$00fc,$e8e4,$01fe,$e1e2,$07fc,$87c0
	dc.w $0ffc,$8fc0,$1ffc,$1f80,$7ff8,$ff00,$fff8,$3f00
	dc.w $eff0,$1e00,$ffe0,$0000,$f7c0,$0f00,$ff80,$1f80
	dc.w $be00,$7e00,$f000,$f000
	dc.w 0,0

frame8:

	dc.w $0000,$0000
	dc.w $0010,$001e,$00f8,$00fe,$01fc,$03fe,$07fe,$07fe
	dc.w $0ffe,$0ffe,$1ffe,$1ffe,$3ffe,$3ffe,$3ffe,$3ffe
	dc.w $3ffe,$5ffe,$1ffe,$7ffe,$0ffe,$7ffe,$07fe,$fffe
	dc.w $03fe,$fffe,$01fe,$fefe,$007e,$ffbe,$003c,$ffce
	dc.w $000e,$fffe,$800e,$7ffe,$801e,$ffee,$401e,$7fee
	dc.w $603e,$5fde,$703c,$6fdc,$3830,$37d0,$3c42,$3f80
	dc.w $0d06,$0c80,$003e,$0000,$079e,$0000,$0302,$0000
	dc.w $0000,$0000,$0000,$0000
	dc.w 0,0


frame8a:
	dc.w $0000,$0080
	dc.w $0010,$000e,$0070,$000e,$01fc,$0202,$07fe,$0000
	dc.w $0ffe,$0000,$1ffe,$0000,$3ffe,$0000,$3ffe,$0000
	dc.w $3ffe,$6000,$1ffe,$6000,$0ffe,$7000,$07fe,$f800
	dc.w $01fe,$fe00,$01fc,$ff02,$003e,$ff82,$0028,$ffe6
	dc.w $0004,$fffa,$8006,$fff0,$801e,$7ff0,$0006,$7fe0
	dc.w $403c,$1fe2,$6024,$0fea,$3010,$07ce,$3842,$077c
	dc.w $0546,$1b38,$00fe,$0f00,$077e,$00e0,$03fe,$00fc
	dc.w $00fe,$00fe,$001e,$001e
	dc.w 0,0



frame8b:

	dc.w $0000,$0000
	dc.w $0000,$f000,$0200,$fe00,$0780,$ff80,$8f40,$7fc0
	dc.w $efa0,$dfe0,$ff90,$fff0,$ff80,$eff0,$e3c0,$fdf0
	dc.w $e070,$ffe0,$c064,$ffa0,$c024,$ffe0,$8004,$ffc0
	dc.w $800c,$ff80,$005e,$ff80,$007e,$ff80,$003e,$ff80
	dc.w $807e,$7f80,$e07e,$9f00,$e07e,$ee00,$a674,$a000
	dc.w $8f80,$8000,$1f00,$0000,$7f00,$0000,$fe00,$0000
	dc.w $fe00,$0000,$fc00,$0000,$f800,$0000,$f800,$0000
	dc.w $1e00,$0000,$3000,$0000
	dc.w 0,0


frame8c:
	dc.w $0000,$0080
	dc.w $0000,$f000,$0200,$fc00,$0200,$f980,$0740,$7880
	dc.w $efa0,$3040,$ef90,$0060,$f7c0,$1878,$e288,$1f70
	dc.w $e05c,$3ff4,$c060,$3fdc,$c024,$7fd8,$0006,$fffa
	dc.w $804e,$ffb2,$005e,$ff60,$003e,$fe40,$007e,$fc00
	dc.w $803e,$f840,$a0fe,$3080,$c9fc,$3182,$87fc,$7888
	dc.w $8f7c,$70fc,$1ffc,$e0fc,$7ef8,$81f8,$fff8,$01f8
	dc.w $fff0,$01f0,$ffe0,$03e0,$ffc0,$07c0,$ff80,$0780
	dc.w $fe00,$e000,$f000,$c000
	dc.w 0,0


*****************************************************************************

	SECTION	Data,DATA_C


FONT_HEADER:
	incdir	"dh1:own/demo/repository/resources/fonts/"
	incbin	"32x32-FI.raw"

FONT:
	incdir	"dh1:own/demo/repository/resources/fonts/"
	incbin  "16X16-F2_944_16_2.blt.raw"

*****************************************************************************

	SECTION	SCREEN, BSS_C	

SCREEN_H:
	ds.b	ScrHBpl*h_H*bpls_H		
SCREEN_L:
	ds.b	ScrLBpl*h_L*bpls_L
BUFFER:
	ds.b	(ScrLBpl+2)*bpls_L*FONT_SCRTXT_HEIGHT
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
