
	SECTION	Code,CODE	; This command will run the below code
				; on FAST RAM (if enough) or CHIP RAM

DMASET	= %1000001111110000
;	  %-----axbcdefghij
;	a: Blitter Nasty
;	x: Enable DMA
;	b: Bitplane DMA (if this isn't set, sprites disappear!)
;	c: Copper DMA
;	d: Blitter DMA
;	e: Sprite DMA
;	f: Disk DMA
;	g-j: Audio 3-0 DMA

INTENA=	    %1010000000000000
;           -FEDCBA9876543210

;	F	SET/CLR	0=clear, 1=set bits that are set to 1 below
;	E	INTEN	Enable interrupts below (master toggle)
;	D	EXTER	Level 6 External interrupt
;	C	DSKSYN	Level 5 Disk Sync value found
;	B	RBF	Level 5 Receive Buffer Full (serial port)
;	A	AUD3	Level 4 Audio Interrupt channel 3
;	9	AUD2	Level 4 Audio Interrupt channel 2
;	8	AUD1	Level 4 Audio Interrupt channel 1
;	7	AUD0	Level 4 Audio Interrupt channel 0
;	6	BLIT	Level 3 Blitter Interrupt
;	5	VERTB	Level 3 Vertical Blank Interrupt
;	4	COPER	Level 3 Copper Interrupt
;	3	PORTS	Level 2 CIA Interrupt (I/O ports and timers)
;	2	SOFT	Level 1 Software Interrupt
;	1	DSKBLK	Level 1 Disk Block Finished Interuppt
;	0	TBE	Level 1 Transmit Buffer Empty Interrupt (serial port)


;;    ---  screen buffer dimensions  ---

w	=320	; Screen width
h	=256	; Screen height
bplsize	=w*h/8	; Bitplane size (bytes)
ScrBpl	=w/8	; Screen line size (bytes)

bpls = 2	; bitplanes enabled

;wbl = $2c (for copper monitor only)
wbl = 303

BLTWAIT	MACRO
	tst $dff002	;for compatibility
\1
	btst #6,$dff002	; DMACONR
	bne.s \1
	ENDM

LMOUSE	MACRO
;\1
	btst	#6,$bfe001	; check L MOUSE btn
	bne.s	\1
	ENDM


RMOUSE	MACRO
;\1
	btst	#2,$dff016	; check L MOUSE btn
	beq.s	\1
	ENDM

	
*****************************************************************************
	incdir	"dh1:own/demo/repository/startup/borchen/"
	include	"startup.s"	; 
	incdir  "dh1:own/demo/repository/startup/"
	include	"pt2.3a_replay_cia.s"	
*****************************************************************************

WAITVB	MACRO
	move.l	$dff004,d0		; wait
	and.l	#$0001ff00,d0		; for
	cmp.l	#wbl<<8,d0		; rasterline 303
	bne.s	\1
	ENDM

WAITVB2	MACRO
	move.l	$dff004,d0		; wait
	and.l	#$0001ff00,d0		; for
	cmp.l	#wbl<<8,d0		; rasterline 303
	beq.s	\1
	ENDM

	
Start:	
;	bra.s	main
	move.l	#SCREEN,d0	; point to bitplane
	lea	BPLPOINTERS,a1	; 
	MOVEQ	#bpls-1,d1		; 2 BITPLANE
POINTBP:
	move.w	d0,6(a1)	; copy low word of pic address to plane
	swap	d0          ; swap the the two words
	move.w	d0,2(a1)    ; copy the high word of pic address to plane
	swap	d0			; swap the the two words

	add.l	#40,d0		; BITPLANE point to next byte line data
						; instead of the standard raw
						; where bitplane is immediately
						; after the previous bitplane
						; standard raw (40*256)
						; blitter raw (40)
	addq.w	#8,a1		; the next bpl starts one row
				; after the previous one
	dbra	d1,POINTBP
	
	move.l	#SPRITE,d0		; SPRITE_1 address
	lea	SPRITEPOINTERS,a1	; SPRITE pointer
	move.w	d0,6(a1)	; copy L word of sprite address to pointer
	swap	d0              ; swap the the two words
	move.w	d0,2(a1)        ; copy the H word of sprite address to pointer


	move.w	#DMASET,$dff096		; enable necessary bits in DMACON
	move.w  #INTENA,$dff09a		; INTENA
	
	move.l	#COPPERLIST,$dff080	; COP1LCH set custom copperlist
	move.w	#0,$dff088		; COPJMP1 activate copperlist

	bsr.w	SetCIAInt
	bsr	mt_init
	st	mt_Enable
Main:
	WAITVB	Main

;	***** COPPER MONITOR
;	move.w	#$F00, $dff180

	bsr.s	move_tb_margin_bars
	bsr.w	move_stars
	bsr.w	show_text	

;	move.w	#0, $dff180

Wait	WAITVB2 Wait

WaitRm:
	RMOUSE WaitRm

	LMOUSE Main
	
	BSR	mt_end
	BSR	ResetCIAInt
	
	rts


BAR_MOVE_VB_DELAY = 3

bar_move_counter:	dc.w	BAR_MOVE_VB_DELAY

move_tb_margin_bars:

	move.w	bar_move_counter, d0
	subq	#1, d0
	tst	d0
	bne.s	exit_margin_bar	
	
	move	#BAR_MOVE_VB_DELAY, d0	; reset counter
	lea TOP_MARGIN_BAR, a0
	bsr.s	rolling_color_hbar
	lea BOTTOM_MARGIN_BAR, a0
	bsr.s	rolling_color_hbar
	
exit_margin_bar:
	move.w	d0, bar_move_counter
	rts

****************************************************************************
*	rolling color routine						   *
*	<INPUT>								   *
*	A0 = HORIZONTAL BAR	(STARTING FROM FIRST COLOR		   *
****************************************************************************

rolling_color_hbar:	
	
	move.w	2+8(a0),2+0(a0)	; 07
	move.w	2+16(a0),2+8(a0)	; 17
	move.w	2+24(a0),2+16(a0)	; 27
	move.w	2+32(a0),2+24(a0)	; 37
	move.w	2+40(a0),2+32(a0)	; 47
	move.w	2+48(a0),2+40(a0)	; 57
	move.w	2+56(a0),2+48(a0)	; 67
	move.w	2+64(a0),2+56(a0)	; 77
	move.w	2+72(a0),2+64(a0)	; 87
	move.w	2+80(a0),2+72(a0)	; 97
	move.w	2+88(a0),2+80(a0)	; a7
	move.w	2+96(a0),2+88(a0)	; b7
	move.w	2+104(a0),2+96(a0)	; c7
	move.w	2+112(a0),2+104(a0)	; d7
	move.w	2+0(a0),2+112(a0)	; e7

	rts


****************************************************************************
*	move stars routine 	taken from (RamJam course)		   *
*									   *
****************************************************************************

STAR_MOVE_DELAY = 2
star_move_progress	dc.w	0


STAR_S_COL = $0444
STAR_M_COL = $0999
STAR_F_COL = $0eee
;STAR_S_COL = $0f00
;STAR_M_COL = $00f0
;STAR_F_COL = $00ff


move_stars:
	addq.b	#1,star_move_progress
	cmpi.b	#STAR_MOVE_DELAY,star_move_progress
	bne	exit_move_stars	
	lea	SPRITE,a0		; let a0 point to SPRITE

	
; this routine process 3 stars each loop
; 1 - medium speed
; 2 - slow speed
; 3 - fast speed
move_loop:	

;  medium speed star - 2 pixel move

	cmpi.b	#$f0,1(a0)	; check if star reached end screen
	bne.s	move_star_ms	; if Z is not set move star
	move.b	#$30,1(A0)	; if Z is set reset HSTART
move_star_ms:
	addq.b  #1,1(a0)	; move sprite of 2 pixels
	addq.w	#8,a0		; point to next sprite

; slow speed star - 1 pixel move

 	cmpi.b	#$f0,1(a0)	; check if star reached end screen
	bne.s	move_star_ls	; if Z is not set move star
	move.b	#$30,1(a0)	; if Z is set reset HSTART
move_star_ls:
	bchg	#0,3(a0)	; check bit 0 SPR0CTL and change it
	beq.s	next_sprite	; if Z is set then go next sprite
	addq.b  #1,1(a0)	; move slow sprite
next_sprite:
	addq.w	#8,a0		; point to next sprite

; fast speed star - 4 pixel move

	cmpi.b	#$f0,1(a0)	; check if star reached end screen
	bne.s	move_star_fs	; if Z is not set move star
	move.b	#$30,1(a0)	; if Z is set reset HSTART
move_star_fs:
	addq.b  #2,1(A0)	; move fast sprite
	addq.w	#8,A0		; point to next sprite

	cmp.l	#SPRITE_END,A0	; check if SPRITE_END reached
	bcs.s	move_loop	; if lower repeat loop
	clr.b	star_move_progress
exit_move_stars:
	rts			; end routine
	

***************************************************************************



*******************************
*                             *
*	CONSTANTS     	      *
*                             *
*******************************


FONTSET_WIDTH	= 944	; pixel
FONTSET_HEIGHT	= 16	; pixel

FONT_WIDTH = 16	; pixel
FONT_HEIGHT = 16	; pixel

TEXT_ROWS = 10	
TEXT_COLS = 20

TEXT_VOFFSET = (ScrBpl*2*FONT_HEIGHT)*bpls

TEXT_LENGTH	= TEXT_COLS*TEXT_ROWS
DELAY_TEXT	= 50*1	; delay between text phase

text_vb_counter	dc.w	DELAY_TEXT		; vertical blank counter
text_phase	dc.w	0		; text phase counter
text_anim_in_progress	dc.w	0	; text blitting / fade in progress flag) 
text_offset_pointer	dc.l	TEXT_1	; address pointer to displayed text
text_message_counter	dc.w	0	; current text counter
text_loading_progress	dc.w	0	; blit text progress
text_screen_offset_pointer	dc.l	SCREEN+TEXT_VOFFSET

show_text:
	btst	#0,text_anim_in_progress
	bne.s	do_text_animation
	subq.w	#1,text_vb_counter
	tst	text_vb_counter
	beq.s	prepare_next_phase
	rts
prepare_next_phase:
	st	text_anim_in_progress
	addq.b	#1,text_phase
	clr.w	text_vb_counter
	moveq	#0,d0
do_text_animation:
	move.b	text_phase,d0
	cmpi.b	#1,d0
	beq.s	print_new_text
	cmpi.b	#2,d0
	beq.w	fade_in_quick
	cmpi.b	#3,d0
	beq.w	fade_out_quick
	cmpi.b	#4,d0
	beq.w	clear_text
	rts
	
print_new_text:	
	move.l	text_offset_pointer(PC), a0
	move.l	text_screen_offset_pointer(PC), a3
	move.w	text_loading_progress(PC), d1
	bsr.s	print_text
	addq	#1, d1	; next row pointer
	cmpi.w	#TEXT_ROWS, d1	; check if end of text is reached
	bne.s	exit_print_new_text	
.end_text_reached:
	; *******
	; uncomment code below if TEXT_ROWS < 10
	;addi	#20*(10-TEXT_ROWS), a0
	; *******
	cmpi.l	#END_TEXT, a0
	bne.s	no_all_messages_finished
.reset_to_first_message
	lea	TEXT_1, a0	; reset text_offset_pointer to TEXT_1
no_all_messages_finished:
	lea	SCREEN+TEXT_VOFFSET, a3	; reset bitplane pointer to VOFFSET
	moveq	#0,d1
	bclr	#0,text_anim_in_progress	
	move.w	#1,text_vb_counter
exit_print_new_text:
	move.l	a0, text_offset_pointer
	move.l	a3, text_screen_offset_pointer
	move.w	d1, text_loading_progress
	rts
	
***************************************************************************
*	print text routine 						  *
*									  *
*	<INPUT>								  *
*	A0 = TEXT address pointer					  *
*	A3 = BITPLANE address pointer					  *
*									  *
*	<OUTPUT>							  *
*	A0 = TEXT address pointer + TEXT_COLS				  *
*	A3 = BITPLANE address pointer + BITPLANE text line height   	  *
*									  *
***************************************************************************

print_text:

.print_row:
	moveq	#TEXT_COLS-1,d0	; NUMBER OF COLUMNS in D0

print_char:
	moveq	#0,d2		; 
	move.b	(a0)+,d2	; point to next char in D2
	sub.b	#$20,d2		; subtract 32 ASCII chars to d2						
	add.l	d2,d2		; get the char offset, because
				; every char is 16 pixel
	move.l	d2,a2		; copy the offset to A2

	add.l	#FONT,a2	; retrieve the char we need

	BLTWAIT BWT1
	
	move.l	#$09f00000,$dff040	;A->D copy, no shifts, ascending mode
	move.l	#$ffffffff,$dff044	;no masking of first/last word
		
	move.w	#(FONTSET_WIDTH-FONT_WIDTH)/8,$dff064	;A modulo=bytes to skip between lines
	move.w	#ScrBpl-FONT_WIDTH/8,$dff066	;D modulo=bytes to skip between lines
	move.l	a2,$dff050	;source graphic top left corner
	move.l	a3,$dff054	;destination top left corner
	move.w	#(bpls*FONTSET_HEIGHT*64)+FONT_WIDTH/16,$dff058	;rectangle size, starts blit

	addq.w	#FONT_WIDTH/8,a3		; point to next column (16 pixel)

	dbra	d0,print_char	; print char

	;	40*(bpls-1) skip all bitplane line (excluding the first one)
	;	(40*FONT_HEIGHT)*bpls	distance between row
	add.w	#ScrBpl*(bpls-1)+(ScrBpl*FONT_HEIGHT)*bpls,a3	; jump to next bitplane line
	;lea	+(ScrBpl*(bpls-1)+(ScrBpl*FONT_HEIGHT)*bpls)(a3), a3 ; same as above

	; ********************************
	; uncomment code below if TEXT_COLS < 20

	;addi	#(20-TEXT_COLS), a0
	;add.w	#(ScrBpl-(TEXT_COLS*2)), a3
	; ********************************

	rts

TEXT_1:	        ;         11111111112
		;12345678901234567890
	dc.b	'FIRST ROW TEXT 12345' ; 1
	dc.b	'SECOND ROW TEXT 2  6' ; 2
	dc.b	'THIRS ROW TEXT 3   7' ; 3
	dc.b	'FOURTH ROW 4       8' ; 4
	dc.b	'FIFTH ROW TEXT 5   9' ; 5
	dc.b	'   3      #         ' ; 6
	dc.b	'    A               ' ; 7
	dc.b	'      B  !          ' ; 8
	dc.b	'       C            ' ; 9
	dc.b	'456789DEFGHIJKLMNOPQ' ; 10

TEXT_2:	        ;         11111111112
		;12345678901234567890
	dc.b	'123456DEFGHIJKLMNOPQ' ; 1
	dc.b	'   SECOND ROW TEXT 2' ; 2
	dc.b	'THIRD               ' ; 3
	dc.b	' ROW                ' ; 4
	dc.b	'  2                 ' ; 5
	dc.b	'   3      #         ' ; 6
	dc.b	'    A               ' ; 7
	dc.b	'      B  !          ' ; 8
	dc.b	'       C            ' ; 9
	dc.b	'ZFGHIJKLMNOPRREEWWQV' ; 10

TEXT_3:	        ;         11111111112
		;12345678901234567890
	dc.b	'123456DEFGHIJKLMNOPQ' ; 1
	dc.b	'   SECOND ROW TEXT 2' ; 2
	dc.b	'THIRD  FOURTH       ' ; 3
	dc.b	' ROW    !!!         ' ; 4
	dc.b	'  2                 ' ; 5
	dc.b	'   3      #         ' ; 6
	dc.b	'    A               ' ; 7
	dc.b	'      B  !          ' ; 8
	dc.b	'       C            ' ; 9
	dc.b	'ZFGHIJKLMNOPRREEWWQV' ; 10

	
END_TEXT

	
;**************************************

fade_counter	dc.w	FADE_STEP_COUNT
FADE_STEP_COUNT = 17
AVAILABLE_COLORS = 3

tabpointer:
	dc.l	TAB_COLOR_1
TAB_COLOR_1:
	dc.w	$0, $0, $11, $12, $23, $23, $134, $135, $146, $156, $157, $268, $269, $279, $27a, $28b, $39c		; blue
	dc.w	$0, $0, $110, $121, $231, $241, $352, $362, $473, $483, $593, $5a4, $6b4, $6c4, $7d5, $7e5, $8f6	; green
	dc.w	$0, $0, $111, $222, $332, $443, $554, $664, $775, $886, $996, $aa7, $bb8, $cc8, $dd9, $eea, $ffb 	; red
ETAB_COLOR_1
TAB_COLOR_2:
	dc.w	$0, $0, $1, $2, $13, $13, $114, $125, $126, $126, $137, $238, $239, $249, $24a, $24b, $35c
	dc.w	$0, $0, $10, $20, $120, $130, $140, $140, $251, $261, $261, $271, $381, $381, $391, $3a1, $4b2		
	dc.w	$0, $0, $100, $200, $200, $300, $410, $410, $510, $610, $610, $720, $820, $820, $920, $a20, $b31
TAB_COLOR_3:
	dc.w	$0, $0, $1, $1, $2, $2, $3, $3, $104, $105, $105, $106, $106, $107, $107, $108, $219
	dc.w	$0, $0, $0, $10, $10, $20, $20, $30, $130, $130, $140, $140, $150, $150, $160, $160, $270
	dc.w	$0, $0, $0, $11, $11, $22, $22, $33, $133, $133, $144, $144, $155, $155, $166, $166, $277

fade_in_quick:
	moveq	#0,d0
	move.w	fade_counter, d0
	subq	#1,d0		
	move.l	tabpointer(PC),a0	
	lea	TEXT_COLORS+2,a1
	move.w	(a0),(a1)
	; distance between TAB_COLOR_1 and TAB_COLOR_2
	; 2 bytes * AVAILABLE_COLORS*FADE_STEP_COUNT
	move.w	2*AVAILABLE_COLORS*FADE_STEP_COUNT(a0),4(a1) 
	; same as above, skip also TAB_COLOR_2
	move.w	2*2*AVAILABLE_COLORS*FADE_STEP_COUNT(a0),8(a1) ; distance between TAB_COLOR_1 and TAB_COLOR_3
	move.w	d0, fade_counter	
	tst	d0
	beq.s	end_fade_in_quick
	add.l	#2, tabpointer
	rts
end_fade_in_quick:
	move.w	#FADE_STEP_COUNT, fade_counter	; reset fade counter
	bclr	#0,text_anim_in_progress
	move.w	#DELAY_TEXT, text_vb_counter
	rts
	

;TAB_COLOR_SIZE = 3
	
;fade_in:
;	cmp.w	#17,fade_phase
;	beq.s	end_fade_in
;	moveq	#0,d0
;	move.w	fade_phase(PC),d0
;	moveq	#TAB_COLOR_SIZE-1,d7		; 
;	lea	TabColoriPic(PC),a0	
;	lea	TEXT_COLORS+2,a1		
;	bsr.s	Fade
;	addq.w	#1,fade_phase
;	rts
;end_fade_in:
;	bclr	#0,text_anim_in_progress	
;	rts


*****************************************************************************
*		Fade routine (take from RamJam course) 			    *
* Input:								    *
*									    *
* d7 = colors number - 1						    *
* a0 = address colour table			    			    *
* a1 = address of the copperlist colour				    	    *
* d0 = fade phase	    						    *
*									    *
*****************************************************************************

;Fade:
;;	BLUE value
;
;	move.w	(a0),d4		; table color in D4
;	and.w	#$00f,d4	; get blue value
;	mulu.w	d0,d4		; mul by the current phase
;	asr.w	#4,d4		; div by 16
;	and.w	#$00f,d4	; get blue value
;	move.w	d4,d5		; save blue value in d5
;
;;	GREEN value
;
;	move.w	(a0),d4		; table color in d4
;	and.w	#$0f0,d4	; get green value
;	mulu.w	d0,d4		; mul by the current phase
;	asr.w	#4,d4		; div by 16
;	and.w	#$0f0,d4	; get green value
;	or.w	d4,d5		; save blue+green value in d5
;
;;	RED value
;
;	move.w	(a0)+,d4	; table color in d4 and point to next value
;	and.w	#$f00,d4	; get red value
;	mulu.w	d0,d4		; mul by the current phase
;	asr.w	#4,d4		; div by 16
;	and.w	#$f00,d4	; get red value
;	or.w	d4,d5		; save blue+green+red value in d5
;
;	move.w	d5,(a1)		; put the final value in a1
;	addq.w	#4,a1		; go to next colour in the copperlist
;	dbra	d7,fade		; do loop for all color table
;	rts

fade_out_quick:
	moveq	#0,d0
	move.w	fade_counter, d0
	subq	#1,d0		
	move.l	tabpointer(PC),a0
	lea	TEXT_COLORS+2,a1		
	move.w	(a0),(a1)
	move.w	2*AVAILABLE_COLORS*FADE_STEP_COUNT(a0),4(a1) ; distance between TAB_COLOR_1 and TAB_COLOR_2
	move.w	2*2*AVAILABLE_COLORS*FADE_STEP_COUNT(a0),8(a1) ; distance between TAB_COLOR_1 and TAB_COLOR_3
	move.w	d0, fade_counter	
	tst	d0
	beq.s	end_fade_out_quick
	sub.l	#2, tabpointer
	rts
end_fade_out_quick:	
	move.w	#FADE_STEP_COUNT,fade_counter
	move.w	#1,text_vb_counter
	bclr	#0,text_anim_in_progress
	
	; end of tab color reached ?
	cmpi.l	#ETAB_COLOR_1-(FADE_STEP_COUNT*2),tabpointer
	beq.s	reset_tabpointer
	bne.s	no_reset_tabpointer
reset_tabpointer:	; reset to TAB_COLOR_1
	move.l	#TAB_COLOR_1, tabpointer
	rts
no_reset_tabpointer:	; go next TAB_COLOR
	add.l	#FADE_STEP_COUNT*2, tabpointer	; FADE_STEP_COUNT*2 bytes
	rts

clear_text:
	BLTWAIT BWT2
		
	move.w	#$0100,$dff040	 ; BLTCON0: enable destination D (only write)
	move.w	#$0000,$dff042	 ; BLTCON1: disabled
	move.l	#SCREEN+TEXT_VOFFSET,$dff054	 ; BLTDPT: destination 
	move.w	#ScrBpl-(FONT_WIDTH/8*TEXT_COLS),$dff066	 ; BLTDMOD: 
	move.w	#(bpls*TEXT_ROWS*(FONT_HEIGHT+1)*64)+FONT_WIDTH/8*TEXT_COLS/2,$dff058 ; BLTSIZE: rectangle size	
.next_phase
	bclr	#0,text_anim_in_progress
	clr.b	text_phase
	move.w	#DELAY_TEXT, text_vb_counter
	rts

;TabColoriPic:
;	dc.w $039c,$035c,$0219

	
;fade_out:
;	tst.w	fade_phase	; 
;	beq.s	end_fade_out
;	subq.w	#1,fade_phase	; 
;	moveq	#0,d0
;	move.w	fade_phase(PC),d0
;	moveq	#TAB_COLOR_SIZE-1,d7
;	lea	TabColoriPic(PC),a0	
;	lea	TEXT_COLORS+2,a1		
;	bsr.w	Fade
;	rts
;	
;end_fade_out:
;	; clear text routine
;	BLTWAIT BWT3
;		
;	move.w	#$0100,$dff040	 ; BLTCON0: enable destination D (only write)
;	move.w	#$0000,$dff042	 ; BLTCON1: disabled
;	move.l	#SCREEN+TEXT_VOFFSET,$dff054	 ; BLTDPT: destination 
;	move.w	#ScrBpl-(FONT_WIDTH/8*TEXT_COLS),$dff066	 ; BLTDMOD: 
;	move.w	#(bpls*TEXT_ROWS*(FONT_HEIGHT+1)*64)+FONT_WIDTH/8*TEXT_COLS/2,$dff058 ; BLTSIZE: rectangle size	
;	
;	bclr	#0,text_anim_in_progress
;	clr.b	text_phase
;	cmp.b	#TEXT_COUNT, text_message_counter
;	bne.s	exit_fade_out
;.reset_text_loop
;	clr.l	text_offset_pointer
;	clr.b	text_message_counter
;exit_fade_out:	
;	rts


*****************************************************************************

	SECTION	Copper,DATA_C

COPPERLIST:
SPRITEPOINTERS:
	dc.w	$120,$0000,$122,$0000,$124,$0000,$126,$0000,$128,$0000	; clear sprite pointers
	dc.w	$12a,$0000,$12c,$0000,$12e,$0000,$130,$0000,$132,$0000  ; clear sprite pointers
	dc.w	$134,$0000,$136,$0000,$138,$0000,$13a,$0000,$13c,$0000  ; clear sprite pointers
	dc.w	$13e,$0000

	dc.w	$8E,$2c81	; DiwStrt
	dc.w	$90,$2cc1	; DiwStop
	dc.w	$92,$38		; DdfStart
	dc.w	$94,$d0		; DdfStop
	dc.w	$102,0		; BplCon1
	dc.w	$104,0		; BplCon2
	dc.w	$108,ScrBpl*(bpls-1)	; Bpl1Mod (interleaved) 
	dc.w	$10a,ScrBpl*(bpls-1)	; Bpl2Mod (interleaved)

	dc.w	$100,bpls*$1000+$200	; bplcon0 - bitplane lowres

BPLPOINTERS:
	dc.w $e0,$0000,$e2,$0000	;bitplane 1
	dc.w $e4,$0000,$e6,$0000	;bitplane 2
	
	dc.w $0180,$0000

	dc.w $4207,$fffe
TOP_MARGIN_BAR:
	dc.w $0180,$0032
	dc.w $4217,$fffe
	dc.w $0180,$0042
	dc.w $4227,$fffe
	dc.w $0180,$0052
	dc.w $4237,$fffe
	dc.w $0180,$0062
	dc.w $4247,$fffe
	dc.w $0180,$0082
	dc.w $4257,$fffe
	dc.w $0180,$0592
	dc.w $4267,$fffe
	dc.w $0180,$09a2
	dc.w $4277,$fffe
	dc.w $0180,$0ac2
	dc.w $4287,$fffe
	dc.w $0180,$09a2
	dc.w $4297,$fffe
	dc.w $0180,$0592
	dc.w $42a7,$fffe
	dc.w $0180,$0082
	dc.w $42b7,$fffe
	dc.w $0180,$0062
	dc.w $42c7,$fffe
	dc.w $0180,$0052
	dc.w $42d7,$fffe
	dc.w $0180,$0042
	dc.w $42e7,$fffe
	dc.w $0180,$0032
ETOP_MARGIN_BAR:
	dc.w $4307,$fffe
	dc.w $0180,$0000



TEXT_COLORS:
	dc.w $0182,$0000
	dc.w $0184,$0000
	dc.w $0186,$0000

;	GREEN
;	dc.w $0182,$08f6
;	dc.w $0184,$04b2
;	dc.w $0186,$0270

;	RED
;	dc.w $0182,$0ffb
;	dc.w $0184,$0b31
;	dc.w $0186,$0277


	; set star color according to its speed
	; slow are dark
	; medium are mid-bright 
	; fast are bright
	
	dc.w $5407,$fffe
	dc.w $01a2,STAR_M_COL	; medium (col17 sprite a)
	dc.w $5507,$fffe
	dc.w $01a2,STAR_S_COL	; slow
	dc.w $5707,$fffe
	dc.w $01a2,STAR_F_COL	; fast
	dc.w $5907,$fffe
	dc.w $01a2,STAR_M_COL	; medium (col17 sprite a)
	dc.w $5b07,$fffe
	dc.w $01a2,STAR_S_COL	; slow
	dc.w $5d07,$fffe
	dc.w $01a2,STAR_F_COL	; fast
	dc.w $5f07,$fffe
	dc.w $01a2,STAR_M_COL	; medium (col17 sprite a)
	dc.w $6107,$fffe
	dc.w $01a2,STAR_S_COL	; slow
	dc.w $6307,$fffe
	dc.w $01a2,STAR_F_COL	; fast
	dc.w $6507,$fffe
	dc.w $01a2,STAR_M_COL	; medium (col17 sprite a)
	dc.w $6707,$fffe
	dc.w $01a2,STAR_S_COL	; slow
	dc.w $6907,$fffe
	dc.w $01a2,STAR_F_COL	; fast
	dc.w $6b07,$fffe
	dc.w $01a2,STAR_M_COL	; medium (col17 sprite a)
	dc.w $6d07,$fffe
	dc.w $01a2,STAR_S_COL	; slow
	dc.w $6f07,$fffe
	dc.w $01a2,STAR_F_COL	; fast
	dc.w $7107,$fffe
	dc.w $01a2,STAR_M_COL	; medium (col17 sprite a)
	dc.w $7307,$fffe
	dc.w $01a2,STAR_S_COL	; slow
	dc.w $7507,$fffe
	dc.w $01a2,STAR_F_COL	; fast
	dc.w $7707,$fffe
	dc.w $01a2,STAR_M_COL	; medium (col17 sprite a)
	dc.w $7907,$fffe
	dc.w $01a2,STAR_S_COL	; slow
	dc.w $7b07,$fffe
	dc.w $01a2,STAR_F_COL	; fast
	dc.w $7d07,$fffe
	dc.w $01a2,STAR_M_COL	; medium (col17 sprite a)
	dc.w $7f07,$fffe
	dc.w $01a2,STAR_S_COL	; slow
	dc.w $8107,$fffe
	dc.w $01a2,STAR_F_COL	; fast
	dc.w $8307,$fffe
	dc.w $01a2,STAR_M_COL	; medium (col17 sprite a)
	dc.w $8507,$fffe
	dc.w $01a2,STAR_S_COL	; slow
	dc.w $8707,$fffe
	dc.w $01a2,STAR_F_COL	; fast
	dc.w $8907,$fffe
	dc.w $01a2,STAR_M_COL	; medium (col17 sprite a)
	dc.w $8b07,$fffe
	dc.w $01a2,STAR_S_COL	; slow
	dc.w $8d07,$fffe
	dc.w $01a2,STAR_F_COL	; fast
	dc.w $8f07,$fffe
	dc.w $01a2,STAR_M_COL	; medium (col17 sprite a)
	dc.w $9107,$fffe
	dc.w $01a2,STAR_S_COL	; slow
	dc.w $9307,$fffe
	dc.w $01a2,STAR_F_COL	; fast
	dc.w $9507,$fffe
	dc.w $01a2,STAR_M_COL	; medium (col17 sprite a)
	dc.w $9707,$fffe
	dc.w $01a2,STAR_S_COL	; slow
	dc.w $9907,$fffe
	dc.w $01a2,STAR_F_COL	; fast
	dc.w $9b07,$fffe
	dc.w $01a2,STAR_M_COL	; medium (col17 sprite a)
	dc.w $9d07,$fffe
	dc.w $01a2,STAR_S_COL	; slow
	dc.w $9f07,$fffe
	dc.w $01a2,STAR_F_COL	; fast
	dc.w $a107,$fffe
	dc.w $01a2,STAR_M_COL	; medium (col17 sprite a)
	dc.w $a307,$fffe
	dc.w $01a2,STAR_S_COL	; slow
	dc.w $a507,$fffe
	dc.w $01a2,STAR_F_COL	; fast
	dc.w $a707,$fffe
	dc.w $01a2,STAR_M_COL	; medium (col17 sprite a)
	dc.w $a907,$fffe
	dc.w $01a2,STAR_S_COL	; slow
	dc.w $ab07,$fffe
	dc.w $01a2,STAR_F_COL	; fast
	dc.w $ad07,$fffe
	dc.w $01a2,STAR_M_COL	; medium (col17 sprite a)
	dc.w $af07,$fffe
	dc.w $01a2,STAR_S_COL	; slow
	dc.w $b107,$fffe
	dc.w $01a2,STAR_F_COL	; fast
	dc.w $b307,$fffe
	dc.w $01a2,STAR_M_COL	; medium (col17 sprite a)
	dc.w $b507,$fffe
	dc.w $01a2,STAR_S_COL	; slow
	dc.w $b707,$fffe
	dc.w $01a2,STAR_F_COL	; fast
	dc.w $b907,$fffe
	dc.w $01a2,STAR_M_COL	; medium (col17 sprite a)
	dc.w $bb07,$fffe
	dc.w $01a2,STAR_S_COL	; slow
	dc.w $bd07,$fffe
	dc.w $01a2,STAR_F_COL	; fast
	dc.w $bf07,$fffe
	dc.w $01a2,STAR_M_COL	; medium (col17 sprite a)
	dc.w $c107,$fffe
	dc.w $01a2,STAR_S_COL	; slow
	dc.w $c307,$fffe
	dc.w $01a2,STAR_F_COL	; fast
	dc.w $c607,$fffe
	dc.w $01a2,STAR_M_COL	; medium (col17 sprite a)
	dc.w $c807,$fffe
	dc.w $01a2,STAR_S_COL	; slow
	dc.w $ca07,$fffe
	dc.w $01a2,STAR_F_COL	; fast
	dc.w $cb07,$fffe
	dc.w $01a2,STAR_M_COL	; medium (col17 sprite a)
	dc.w $cd07,$fffe
	dc.w $01a2,STAR_S_COL	; slow
	dc.w $ab07,$fffe
	dc.w $cfa2,STAR_F_COL	; fast
	dc.w $d107,$fffe
	dc.w $01a2,STAR_M_COL	; medium (col17 sprite a)
	dc.w $d307,$fffe
	dc.w $01a2,STAR_S_COL	; slow
	dc.w $d507,$fffe
	dc.w $01a2,STAR_F_COL	; fast
	dc.w $d707,$fffe
	dc.w $01a2,STAR_M_COL	; medium (col17 sprite a)
	dc.w $d907,$fffe
	dc.w $01a2,STAR_S_COL	; slow
	dc.w $db07,$fffe
	dc.w $01a2,STAR_F_COL	; fast
	dc.w $dd07,$fffe
	dc.w $01a2,STAR_M_COL	; medium (col17 sprite a)
	dc.w $df07,$fffe
	dc.w $01a2,STAR_S_COL	; slow
	dc.w $e107,$fffe
	dc.w $01a2,STAR_F_COL	; fast
	dc.w $e307,$fffe
	dc.w $01a2,STAR_M_COL	; medium (col17 sprite a)
	dc.w $e507,$fffe
	dc.w $01a2,STAR_S_COL	; slow
	dc.w $e707,$fffe
	dc.w $01a2,STAR_F_COL	; fast
	dc.w $e907,$fffe
	dc.w $01a2,STAR_M_COL	; medium (col17 sprite a)
	dc.w $eb07,$fffe
	dc.w $01a2,STAR_S_COL	; slow
	dc.w $ed07,$fffe
	dc.w $01a2,STAR_F_COL	; fast
	dc.w $ef07,$fffe
	dc.w $01a2,STAR_M_COL	; medium (col17 sprite a)
	dc.w $f107,$fffe
	dc.w $01a2,STAR_S_COL	; slow
	dc.w $f307,$fffe
	dc.w $01a2,STAR_F_COL	; fast
	dc.w $f507,$fffe
	dc.w $01a2,STAR_M_COL	; medium (col17 sprite a)
	dc.w $f707,$fffe
	dc.w $01a2,STAR_S_COL	; slow
	dc.w $f907,$fffe
	dc.w $01a2,STAR_F_COL	; fast
	dc.w $fb07,$fffe
	dc.w $01a2,STAR_M_COL	; medium (col17 sprite a)
	dc.w $fd07,$fffe
	dc.w $01a2,STAR_S_COL	; slow
	dc.w $ff07,$fffe
	
	dc.w $ffdf,$fffe
	
	dc.w $01a2,STAR_F_COL	; fast
	dc.w $0107,$fffe
	dc.w $01a2,STAR_M_COL	; medium (col17 sprite a)
	dc.w $0307,$fffe
	dc.w $01a2,STAR_S_COL	; slow
	dc.w $0507,$fffe
	dc.w $01a2,STAR_F_COL	; fast
	; end star color copper set

	dc.w $1207,$fffe
BOTTOM_MARGIN_BAR:
	dc.w $0180,$0302
	dc.w $1217,$fffe
	dc.w $0180,$0402
	dc.w $1227,$fffe
	dc.w $0180,$0502
	dc.w $1237,$fffe
	dc.w $0180,$0602
	dc.w $1247,$fffe
	dc.w $0180,$0802
	dc.w $1257,$fffe
	dc.w $0180,$0952
	dc.w $1267,$fffe
	dc.w $0180,$0a92
	dc.w $1277,$fffe
	dc.w $0180,$0ca2
	dc.w $1287,$fffe
	dc.w $0180,$0a92
	dc.w $1297,$fffe
	dc.w $0180,$0952
	dc.w $12a7,$fffe
	dc.w $0180,$0802
	dc.w $12b7,$fffe
	dc.w $0180,$0602
	dc.w $12c7,$fffe
	dc.w $0180,$0502
	dc.w $12d7,$fffe
	dc.w $0180,$0402
	dc.w $12e7,$fffe
	dc.w $0180,$0302
EBOTTOM_MARGIN_BAR:
	dc.w $1307,$fffe
	dc.w $0180,$0000


;	dc.w $1207,$fffe
;	dc.w $0180,$00f2
;	dc.w $1307,$fffe
;	dc.w $0180,$0000
	
	
	dc.w	$FFFF,$FFFE	; End of copperlist

	
*****************************************************************************

	SECTION	Data,DATA_C



	
; each sprite is composed by 4 words (8 bytes)
; example: $307A,$3100,$1000,$0000
; STR0POS	VSTART	$30
; STR0POS	HSTART	$7A
; SPR0CTL	VSTOP	$31
; SPR0CTL	bit 7-0 $00
;
; SPRITE DATA:
; $1000	$0000	where 1 is the pixel of the start
;
; be aware the sprite beyond $FF vertical position
; must have SPR0CTL bit 2 and 1 set ($06 or %0110) 

	
SPRITE:
	;dc.w    $307A,$3100,$1000,$0000,$3220,$3300,$1000,$0000
	;dc.w    $34C0,$3500,$1000,$0000,$3650,$3700,$1000,$0000
	;dc.w    $3842,$3900,$1000,$0000,$3A6D,$3B00,$1000,$0000
	;dc.w    $3CA2,$3D00,$1000,$0000,$3E9C,$3F00,$1000,$0000
	;dc.w    $40DA,$4100,$1000,$0000,$4243,$4300,$1000,$0000
	;dc.w    $445A,$4500,$1000,$0000,$4615,$4700,$1000,$0000
	;dc.w    $4845,$4900,$1000,$0000,$4A68,$4B00,$1000,$0000
	;dc.w    $4CB8,$4D00,$1000,$0000,$4EB4,$4F00,$1000,$0000
	;dc.w    $5082,$5100,$1000,$0000,$5292,$5300,$1000,$0000
	
	dc.w    $54D0,$5500,$1000,$0000,$56D3,$5700,$1000,$0000
	dc.w    $58F0,$5900,$1000,$0000,$5A6A,$5B00,$1000,$0000
	dc.w    $5CA5,$5D00,$1000,$0000,$5E46,$5F00,$1000,$0000
	dc.w    $606A,$6100,$1000,$0000,$62A0,$6300,$1000,$0000
	dc.w    $64D7,$6500,$1000,$0000,$667C,$6700,$1000,$0000
	dc.w    $68C4,$6900,$1000,$0000,$6AC0,$6B00,$1000,$0000
	dc.w    $6C4A,$6D00,$1000,$0000,$6EDA,$6F00,$1000,$0000
	dc.w    $70D7,$7100,$1000,$0000,$7243,$7300,$1000,$0000
	dc.w    $74A2,$7500,$1000,$0000,$7699,$7700,$1000,$0000
	dc.w    $7872,$7900,$1000,$0000,$7A77,$7B00,$1000,$0000
	dc.w    $7CC2,$7D00,$1000,$0000,$7E56,$7F00,$1000,$0000
	dc.w    $805A,$8100,$1000,$0000,$82CC,$8300,$1000,$0000
	dc.w    $848F,$8500,$1000,$0000,$8688,$8700,$1000,$0000
	dc.w    $88B9,$8900,$1000,$0000,$8AAF,$8B00,$1000,$0000
	dc.w    $8C48,$8D00,$1000,$0000,$8E68,$8F00,$1000,$0000
	dc.w    $90DF,$9100,$1000,$0000,$924F,$9300,$1000,$0000
	dc.w    $9424,$9500,$1000,$0000,$96D7,$9700,$1000,$0000
	dc.w    $9859,$9900,$1000,$0000,$9A4F,$9B00,$1000,$0000
	dc.w    $9C4A,$9D00,$1000,$0000,$9E5C,$9F00,$1000,$0000
	dc.w    $A046,$A100,$1000,$0000,$A2A6,$A300,$1000,$0000
	dc.w    $A423,$A500,$1000,$0000,$A6FA,$A700,$1000,$0000
	dc.w    $A86C,$A900,$1000,$0000,$AA44,$AB00,$1000,$0000
	dc.w    $AC88,$AD00,$1000,$0000,$AE9A,$AF00,$1000,$0000
	dc.w    $B06C,$B100,$1000,$0000,$B2D4,$B300,$1000,$0000
	dc.w    $B42A,$B500,$1000,$0000,$B636,$B700,$1000,$0000
	dc.w    $B875,$B900,$1000,$0000,$BA89,$BB00,$1000,$0000
	dc.w    $BC45,$BD00,$1000,$0000,$BE24,$BF00,$1000,$0000
	dc.w    $C0A3,$C100,$1000,$0000,$C29D,$C300,$1000,$0000		
	dc.w    $C43F,$C500,$1000,$0000,$C634,$C700,$1000,$0000		
	dc.w    $C87C,$C900,$1000,$0000,$CA1D,$CB00,$1000,$0000		
	dc.w    $CC6B,$CD00,$1000,$0000,$CEAC,$CF00,$1000,$0000
	dc.w    $D0CF,$D100,$1000,$0000,$D2FF,$D300,$1000,$0000		
	dc.w    $D4A5,$D500,$1000,$0000,$D6D6,$D700,$1000,$0000		
	dc.w    $D8EF,$D900,$1000,$0000,$DAE1,$DB00,$1000,$0000		
	dc.w    $DCD9,$DD00,$1000,$0000,$DEA6,$DF00,$1000,$0000		
	dc.w    $E055,$E100,$1000,$0000,$E237,$E300,$1000,$0000		
	dc.w    $E47D,$E500,$1000,$0000,$E62E,$E700,$1000,$0000
	dc.w    $E8AF,$E900,$1000,$0000,$EA46,$EB00,$1000,$0000
	dc.w	$EC65,$ED00,$1000,$0000,$EE87,$EF00,$1000,$0000
	dc.w	$F0D4,$F100,$1000,$0000,$F2F5,$F300,$1000,$0000
	dc.w	$F4FA,$F500,$1000,$0000,$F62C,$F700,$1000,$0000
	dc.w	$F84D,$F900,$1000,$0000,$FAAC,$FB00,$1000,$0000
	dc.w	$FCB2,$FD00,$1000,$0000,$FE9A,$FF00,$1000,$0000
	dc.w	$009A,$0106,$1000,$0000,$02DF,$0306,$1000,$0000 ; sprite beyond vpos $FF
	dc.w	$0446,$0506,$1000,$0000,$0688,$0706,$1000,$0000

	;dc.w	$0899,$0906,$1000,$0000,$0ADD,$0B06,$1000,$0000
	;dc.w	$0CEE,$0D06,$1000,$0000,$0EFF,$0F06,$1000,$0000
	;dc.w	$10CD,$1106,$1000,$0000,$1267,$1306,$1000,$0000
	;dc.w	$1443,$1506,$1000,$0000,$1664,$1706,$1000,$0000
	;dc.w	$1823,$1906,$1000,$0000,$1A6D,$1B06,$1000,$0000
	;dc.w	$1C4F,$1D06,$1000,$0000,$1E5F,$1F06,$1000,$0000
	;dc.w	$2055,$2106,$1000,$0000,$2267,$2306,$1000,$0000
	;dc.w	$2445,$2506,$1000,$0000,$2623,$2706,$1000,$0000
	;dc.w	$2834,$2906,$1000,$0000,$2AF0,$2B06,$1000,$0000
SPRITE_END:
	dc.w 	$0000,$0000	; end of sprite address
	
	
	
MT_DATA:
	incdir  "dh1:own/mod/"
	incbin	"mod.towards"


FONT:
	incdir	"dh1:own/fonts/"
	incbin	"16X16-F2_944_16_2.blt.raw"
	
*****************************************************************************

	SECTION	Screen,BSS_C	

SCREEN:
	ds.b	40*256*bpls	; 

	end
