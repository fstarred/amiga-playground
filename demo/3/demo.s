*********************************************
*
*	   STARRED MEDIASOFT
*
*		DEMO 3
*
*		VER 1.0 (2018)
*
*
*********************************************

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





P61mode	=1	;Try other modes ONLY IF there are no Fxx commands >= 20.
		;(f.ex., P61.new_ditty only works with P61mode=1)


;;    ---  options common to all P61modes  ---

usecode	=-1	;CHANGE! to the USE hexcode from P61con for a big 
		;CPU-time gain! (See module usecodes at end of source)
		;Multiple songs, single playroutine? Just "OR" the 
		;usecodes together!

		;...STOP! Have you changed it yet!? ;)
		;You will LOSE RASTERTIME AND FEATURES if you don't.

P61pl=usecode&$400000

split4	=1	;Great time gain, but INCOMPATIBLE with F03, F02, and F01
		;speeds in the song! That's the ONLY reason it's default 0.
		;So ==> PLEASE try split4=1 in ANY mode!
		;Overrides splitchans to decrunch 1 chan/frame.
		;See ;@@ note for P61_SetPosition.


splitchans=1	;#channels to be split off to be decrunched at "playtime frame"
		;0=use normal "decrunch all channels in the same frame"
		;Experiment to find minimum rastertime, but it should be 1 or 2
		;for 3-4 channels songs and 0 or 1 with less channels.

visuctrs=1	;enables visualizers in this example: P61_visuctr0..3.w 
		;containing #frames (#lev6ints if cia=1) elapsed since last
		;instrument triggered. (0=triggered this frame.)
		;Easy alternative to E8x or 1Fx sync commands.

asmonereport	=0	;ONLY for printing a settings report on assembly. Use
			;if you get problems (only works in AsmOne/AsmPro, tho)

p61system=0	;1=system-friendly. Use for DOS/Workbench programs.

p61exec	=0	;0 if execbase is destroyed, such as in a trackmo.

p61fade	=0	;enable channel volume fading from your demo

channels=4	;<4 for game sound effects in the higher channels. Incompatible
		; with splitchans/split4.

playflag=0	;1=enable music on/off capability (at run-time). .If 0, you can
		;still do this by just, you know, not calling P61_Music...
		;It's a convenience function to "pause" music in CIA mode.

p61bigjtab=0	;1 to waste 480b and save max 56 cycles on 68000.

opt020	=0	;1=enable optimizations for 020+. Please be 68000 compatible!
		;splitchans will already give MUCH bigger gains, and you can
		;try the MAXOPTI mode.

p61jump	=0	;0 to leave out P61_SetPosition (size gain)
		;1 if you need to force-start at a given position fex in a game

C	=0	;If you happen to have some $dffxxx value in a6, you can 
		;change this to $xxx to not have to load it before P61_Music.

clraudxdat=0	;enable smoother start of quiet sounds. probably not needed.

optjmp	=1	;0=safety check for jump beyond end of song. Clear it if you 
		;play unknown P61 songs with erroneous Bxx/Dxx commands in them

oscillo	=0	;1 to get a sample window (ptr, size) to read and display for 
		;oscilloscope type effects (beta, noshorts=1, pad instruments)
		;IMPORTANT: see ;@@ note about chipmem dc.w buffer.

quietstart=0	;attempt to avoid the very first click in some modules
		;IMPORTANT: see ;@@ note about chipmem dc.w buffer.

use1Fx=0	;Optional extra effect-sync trigger (*). If your module is free
		;from E commands, and you add E8x to sync stuff, this will 
		;change the usecode to include a whole code block for all E 
		;commands. You can avoid this by only using 1Fx. (You can 
		;also use this as an extra sync command if E8x is not enough, 
		;of course.)

;(*) Slideup values>116 causes bugs in Protracker, and E8 causes extra-code 
;for all E-commands, so I used this. It's only faster if your song contains 0
;E-commands, so it's only useful to a few, I guess. Bit of cyclemania. :)

;Just like E8x, you will get the trigger after the P61_Music call, 1 frame 
;BEFORE it's heard. This is good, because it allows double-buffered graphics 
;or effects running at < 50 fps to show the trigger synced properly.



;;    ---  CIA mode options (default) ---

	ifeq P61mode-1

p61cia	=1	;call P61_Music on the CIA interrupt instead of every frame.

lev6	=1	;1=keep the timer B int at least for setting DMA.
		;0="FBI mode" - ie. "Free the B-timer Interrupt".

		;0 requires noshorts=1, p61system=0, and that YOU make sure DMA
		;is set at 11 scanlines (700 usecs) after P61_Music is called.
		;AsmOne will warn you if requirements are wrong.

		;DMA bits will be poked in the address you pass in A4 to 
		;P61_init. (Update P61_DMApokeAddr during playing if necessary,
		;for example if switching Coppers.)

		;P61_Init will still save old timer B settings, and initialize
		;it. P61_End will still restore timer B settings from P61_Init.
		;So don't count on it 'across calls' to these routines.
		;Using it after P61_Init and before P61_End is fine.

noshorts=0	;1 saves ~1 scanline, requires Lev6=0. Use if no instrument is
		;shorter than ~300 bytes (or extend them to > 300 bytes).
		;It does this by setting repeatpos/length the next frame 
		;instead of after a few scanlines,so incompatible with MAXOPTI

dupedec	=0	;0=save 500 bytes and lose 26 cycles - I don't blame you. :)
		;1=splitchans or split4 must be on.

suppF01	=1	;0 is incompatible with CIA mode. It moves ~100 cycles of
		;next-pattern code to the less busy 2nd frame of a notestep.
		;If you really need it, you have to experiment as the support 
		;is quite complex. Basically set it to 1 and try the various 
		;P61modes, if none work, change some settings.

	endc


	
*****************************************************************************
	incdir	"dh1:own/demo/repository/startup/borchen/"
	include	"startup.s"	
	incdir	"dh1:own/demo/repository/shared/"	
	include "hardware/custom.i"
	incdir  "dh1:own/demo/repository/replay/"
	include "P6112-Play.i"
*****************************************************************************


;;    ---  SCREEN_H buffer dimensions  ---

w_H	=640+320
h_H 	=48
ScrHBpl	=w_H/8	

w_L	=320
h_L	=256-h_H
ScrLBpl	=w_L/8	

bpls_H = 4
bpls_L = 1

;wbl = $2c+h_H+4 (for copper monitor only)
wbl = $ff

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
	
	
;	move.l  #SCREEN_L,d0  ; point to bitplane
;    	lea BPLPOINTERS_L,a1  ; 
;   	moveq   #bpls_L-1,d1  ; 2 BITPLANE
;POINTBP_L:
;    	move.w  d0,6(a1)    ; copy low word of pic address to plane
;    	swap    d0          ; swap the the two words
;   	move.w  d0,2(a1)    ; copy the high word of pic address to plane
;    	swap    d0          ; swap the the two words
;
;	add.l   #ScrLBpl*h_L,d0      
;			
;	addq.w  #8,a1
;                	
;	dbra    d1,POINTBP_L
	
    
	move.w  #DMASET,$dff096     ; enable necessary bits in DMACON
	move.w  #INTENASET,$dff09a     ; INTENA
    
	move.l  #COPPERLIST,$dff080 ; COP1LCH set custom copperlist
	move.w  #0,$dff088      ; COPJMP1 activate copperlist

	movem.l d0-a6,-(sp)	; P61_Init

	lea M_DATA,a0
	sub.l a1,a1
	sub.l a2,a2
	moveq #0,d0
	jsr P61_Init

	movem.l (sp)+,d0-a6

	
	lea	OFFSET_TAB, a0	
	moveq	#0, d0		
	move.w	#h_L-1, d7	
fill_offset_tab:
	move.w	d0,(a0)+		; put ScrBpl on each word value
	add.w	#ScrLBpl*bpls_L, d0		; ScrBpl+ScrBpl...
	dbra	d7, fill_offset_tab
	
	lea	$dff000,a5
	
	bsr.w	init_chessboard
		
	bsr.w	init_copper_bars
		
	bsr	print_text_header
	

Main:
	WAITVB  Main
	
	; IN ORDER TO DISPLAY COPPER MONITOR CORRECTLY
	; COMMENT THE FOLLOWING ROUTINES:
	; 1. init_copper_bars
	; 2. clear_copper_area
	; 3. rolling_copper_bars
	
	
;	***** COPPER MONITOR
	;move.w  #$F00, $dff180

	bsr.w	animate_chessboard

	bsr.w	clear_copper_area
	bsr.w	rolling_copper_bars

	bsr.w	scroll_screen
	
	bsr.w   sprite_animation
	bsr.w   sprite_move

	bsr.w	swap_buffer
	
	bsr.w	print_char_scrolling_text
	bsr.w	scroll_text
	bsr.w	copy_text_buffer_to_screen
	bsr.w	compute_offset
	bsr.w	clear_scrtxt_area		
	bsr.w	make_camel
	
			
;  	**** COPPER MONITOR
	;move.w  #0, $dff180
	
Wait    WAITVB2 Wait

WaitRm:
	;RMOUSE2 continue
	RMOUSE WaitRm
	
continue:	
	LMOUSE Main
	
	movem.l d0-a6,-(sp)	; P61_End
	jsr P61_End
	movem.l (sp)+,d0-a6
	
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
	
	move.l	#$ffffffff,BLTAFWM(a5)	; BLTALWM, BLTAFWM
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

	
CHESSBOARD_ANIM_SPEED = 2

CHESSBOARD_CLOSE = 0
CHESSBOARD_OPEN = 1

chessboard_counter:	dc.b	8
chessboard_action:	dc.b	CHESSBOARD_OPEN
chessboard_anim_cnt:	dc.w	1

animate_chessboard:
	move.b	chessboard_counter(pc), d1
	tst.b	chessboard_action
	bne.s	prepare_chessboard_open_action
prepare_chessboard_close_action:
	tst.b	d1
	beq.s	no_chessboard_animation	; check if chessboard is already closed
	subq	#1, d1
	bra.s	prepare_draw_chessboard
prepare_chessboard_open_action:	
	btst	#3, d1
	bne.s	no_chessboard_animation	; check if chessboard is already open
	addq	#1, d1
prepare_draw_chessboard:
	move.b	d1, chessboard_counter	; update chessboard counter
	
	move.b	#$FF, d0
	lsr.b	d1, d0
	
	move.l	#$FF00FF00, d1		; start composing square patterns
	add.b	d0, d1
	swap	d1
	add.b	d0, d1
	move.l	d1, d0
	lsl.l	#8, d0
	move.b	#$FF, d0
	
	exg	d0, d1	; todo
	
	bra.s	draw_chessboard

no_chessboard_animation:
	rts
	
init_chessboard:

	move.l	#%11111111000000001111111100000000, d0
	move.l	#%00000000111111110000000011111111, d1
	
	bra.w	draw_chessboard
	
	; exit
	
SQUARE_HEIGHT = 8
	
***********************************
*
*	draw chessboard routine
*	<INPUT>
*	D0.L	pattern square 1
*	D1.L	pattern square 2
*	
***********************************

draw_chessboard:

	moveq	#(h_H/16)-1, d6
	lea	SCREEN_H+(ScrHBpl*h_H*3), a0	; move to bitplane 3

draw_cb_loop_2_lines:
	
draw_cb_loop:
	
	move.l	d0, (a0)
	move.l	d0, ScrHBpl(a0)
	move.l	d0, ScrHBpl*2(a0)
	move.l	d0, ScrHBpl*3(a0)
	move.l	d0, ScrHBpl*4(a0)
	move.l	d0, ScrHBpl*5(a0)
	move.l	d0, ScrHBpl*6(a0)
	move.l	d0, ScrHBpl*7(a0)
	
draw_cb_loop_alt:
	
	move.l	d1, ScrHBpl*8(a0)
	move.l	d1, ScrHBpl*9(a0)
	move.l	d1, ScrHBpl*10(a0)
	move.l	d1, ScrHBpl*11(a0)
	move.l	d1, ScrHBpl*12(a0)
	move.l	d1, ScrHBpl*13(a0)
	move.l	d1, ScrHBpl*14(a0)
	move.l	d1, ScrHBpl*15(a0)
	
	BLTWAIT BWT9
	
	move.l	#$09f00000,BLTCON0(a5)	; BLTCON0: A-D
	move.l	#$ffffffff,BLTAFWM(a5)	; BLTAFWM + BLTALWM 

	move.l	a0, BLTAPT(a5)	; BLTAPT
	addi.l	#ScrHBpl*SQUARE_HEIGHT*2, a0
	move.l	a0, BLTDPT(a5) 	; BLTDPT
	move.l	#$00740074, BLTAMOD(a5) ; BLTAMOD
	move.w	#((h_H-(SQUARE_HEIGHT*2))*64)+2, BLTSIZE(a5) ; BLTSIZE	
	
	lea	SCREEN_H+(ScrHBpl*h_H*3), a0	; move to bitplane 3	
	
	BLTWAIT BWT10

	move.l	a0, BLTAPT(a5)	; BLTAPT	
	addq.l	#4, a0
	move.l	a0, BLTDPT(a5) 	; BLTDPT
	move.w	#$0004, BLTAMOD(a5) ; BLTDMOD
	move.w	#$0004, BLTDMOD(a5) ; BLTDMOD
	
	move.w	#(h_H*64)+(ScrHBpl/2-2), BLTSIZE(a5) ; BLTSIZE		
	
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
SCREEN_VOFFSET = SCRTEXT_V_OFFSET*ScrLBpl

	
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
	move.w	#(FONTSET_SCRTXT_HEIGHT*64)+FONT_SCRTXT_WIDTH/16,BLTSIZE(a5) 	; BLTSIZE	
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

	move.l	#BUFFER+(FONT_SCRTXT_HEIGHT*42)-2,d0 ; source and dest address

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
	move.w	#(FONT_SCRTXT_HEIGHT*64)+21,BLTSIZE(a5)	; BLTSIZE
	rts					


copy_text_buffer_to_screen:
		
	move.w	y1(pc), d0
	tst	d0
	beq.s	copy_whole_text
	
	cmpi.w	#20, w_sine_length	; w_sine_length
	bne.s	copy_whole_text
	
	rts	; does not draw because it is useless
	
copy_whole_text:
	
	BLTWAIT BWT3

	move.l	draw_buffer(pc), a0
	addi.w	#SCREEN_VOFFSET, a0
	
	move.l	#$09f00000,BLTCON0(a5)	; BLTCON0+BLTCON1 (A-F) 
	move.l	#$ffffffff,BLTAFWM(a5)	; BLTAFWM / BLTALWM
	move.l	#BUFFER,BLTAPT(a5)			; BLTAPT - source
	move.l	a0,BLTDPT(a5)	; BLTDPT - dest

	; scroll an image of the full screen width * FONT_SCRTXT_HEIGHT

	move.l	#$00020000,BLTAMOD(a5)	; BLTAMOD + BLTDMOD 
	move.w	#(FONT_SCRTXT_HEIGHT*64)+20,BLTSIZE(a5)	; BLTSIZE
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
	addi.w	#MOUSEX_SPRITE_POINTER, x1
	move.w	sprite_y(pc), d0
	addi.w	#MOUSEY_SPRITE_POINTER, d0
	subi.w	#SCRTEXT_V_OFFSET+h_H, d0	; SCREEN_L starts when h_H ends
	tst	d0
	bge.s	compute_all_offset
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
		
	;move.w	#ScrLBpl, d1	; const delta y	
	
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
	;mulu	d1, d0
	lea	OFFSET_TAB, a1
	add.w	d0, d0
	move.w	(a1,d0.w), d0
	
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
old_y1:			dc.w	0,0	; we store 2 values of old_y1, one for each buffer.
					; Once we use the correct old_y1
					; we swap the 2 words in order to work
					; with the correct old_y1 value

clear_scrtxt_area:

	move.l	draw_buffer(pc), a0
	addi.w	#(SCRTEXT_V_OFFSET+FONT_SCRTXT_HEIGHT)*ScrLBpl*bpls_L, a0
	
	move.l	old_y1(pc), d3	; old_y1
	
	tst.w	d3
	beq	clear_text_sine_involved

	BLTWAIT BWT4
	
	; clear below text area

	move.l	draw_buffer(pc), a0
	addi.w	#SCREEN_VOFFSET+(FONT_SCRTXT_HEIGHT*ScrLBpl), a0	
	
	move.l	#$01000000,BLTCON0(a5)	; BLTCON0+BLTCON1 delete (only D)
	move.l	#$ffffffff,BLTAFWM(a5)	; BLTAFWM / BLTALWM
	move.l	#0, BLTAPT(a5)		; BLTAPT - source	
	move.l	a0, BLTDPT(a5)	; BLTDPT - dest
	move.l	#0, BLTAMOD(a5)	; BLTAMOD+BLTDMOD
	move.w	#((h_L-SCRTEXT_V_OFFSET-FONT_SCRTXT_HEIGHT)*64)+20, BLTSIZE(a5)	; BLTSIZE
	
clear_text_sine_involved:

	move.w	y1(pc), d0
	tst.w	d0
	beq	exit_clear_area
	
	move.l	draw_buffer(pc), a0
	addi.w	#SCREEN_VOFFSET, a0
	
	move.w	w_x0(pc), d0
	add.w	d0, d0			; in bytes
	lea	(a0,d0.w), a0	
	
	BLTWAIT BWT5
	
	; clear text where sine is involved

	move.l	#$01000000,BLTCON0(a5)	; BLTCON0 / BLTCON1 delete (only D)
	move.l	#$ffffffff,BLTAFWM(a5)	; BLTAFWM / BLTALWM
	move.w	#0, BLTAPT(a5)
	move.w	#0, BLTAMOD(a5)	
	move.l	a0, BLTDPT(a5)		; BLTDPT
	
	move.w	w_sine_length(pc), d1
	move.w	d1, d2			; copy w_sine_length to d2
	
	move.w	#ScrLBpl, d0
	sub.w	d1, d0
	sub.w	d1, d0
	move.w	d0, BLTDMOD(a5)		; BLTDMOD
	
	move.w	#(FONT_SCRTXT_HEIGHT*bpls_L*64), d0
	add.w	d2, d0			; BLTAMOD
	move.w	d0, BLTSIZE(a5)		; BLTSIZE
	

exit_clear_area:
	
	move.w	y1(pc), d3	; store new value to old_y1
	swap	d3		; swap w value because of double buffer
	move.l	d3, old_y1	; store both values to old_y1
	
	rts

	
	
	
	
make_camel:

	move.w	w_sine_length(pc), d6	; word loop cnt			
	tst.w	d6		
	beq.w	exit_sine_loop				
	subq	#1, d6
	
	lea	BUFFER, a1
	move.w	w_x0(pc), d0
	add.w	d0, d0
	lea	(a1,d0.w), a1

	move.l	draw_buffer(pc), a2
	addi.w	#SCREEN_VOFFSET, a2

	lea	(a2,d0.w), a2
	
	move.w	xd0(pc), d0	
	move.w	#ScrLBpl, d1	; const delta y		
	moveq	#0, d2		; sine counter
	move.w	s_x0(pc), d3	; move s_x0 to d3
	lea	s_x1(pc), a4	; load s_x1 to a4
	move.w	s_x2(pc), d4	; move s_x2 to d4		
	move.w	#$C000, d5
	
	move.w	w_sine_length(pc), d6	; word loop cnt	
	subq	#1, d6

	BLTWAIT BWTA

	move.w	#$ffff, BLTAFWM(a5)	; BLTAFWM
	move.l	#$0bfa0000, BLTCON0(a5)	; BLTCON0/BLTCON1 - A,C,D
					; D=A OR C

	move.w	#$0026, BLTCMOD(a5)	; BLTCMOD=40-2=$26
	move.l	#$00280026, BLTAMOD(a5)	; BLTAMOD=42-2=$28
					; BLTDMOD=40-2=$26

	
word_loop:
	moveq	#8-1, d7		; slice loop cnt
slice_loop:	
	cmp.w	d3, d2		; check if x0 is reached	
	blt.s	start_slice	
	cmp.w	(a4), d2	; check if x1 is reached	
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

	move.w	d5, BLTALWM(a5)		; BLTALWM 

	move.l	a1, BLTAPT(a5)		; BLTAPT  
	move.l	a3, BLTCPT(a5)		; BLTCPT
	move.l	a3, BLTDPT(a5)		; BLTDPT
	move.w	#(FONT_SCRTXT_HEIGHT*64)+1, BLTSIZE(a5)	; BLTSIZE
	
	ror.w	#2, d5			; right shift mask of 2 pixel

	dbra	d7, slice_loop

	addq.w	#2, a1			; point to next word
	addq.w	#2, a2			; point to next word
	
	dbra	d6, word_loop

exit_sine_loop:
	
	rts
	
TEXT:
	dc.b	'HELLO AMIGAS !!! WELCOME TO THIS DEMO RELEASED BY STARRED MEDIASOFT '
	dc.b	'            '
	dc.b	'THIS SONG IS CALLED "SUNNY WALKING ON PIAZZA VENEZIA": '
	dc.b	'AS A WEIRD FACT, THE BAD WEATHER OF THESE DAYS '
	dc.b	'CAUSED SEVERAL INCONVENIENCES ALL OVER THE CITY... :( '
	dc.b	'IF YOU ARE INTERESTED ON COMPOSING MOD WITH A 3RD GENERATION TRACKER '
	dc.b	'CHECK XRNS2XMOD. IT IS AVAILABLE FOR WINDOWS, MAC AND LINUX '
	dc.b	'    :::::::::::::::::   '
	dc.b	'MANY GREETINGS TO ALL EAB FORUM '
	dc.b	'    (((::::::::::::::)))   '
	dc.b	'GRAPHICS, MUSIC AND CODE BY FABRIZIO STELLATO '
	dc.b	'  :::::   '
	dc.b	'STARRED MEDIASOFT  2018       '
	dc.b	'                                              '
	
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

	move.w	#ANIMATION_SLOW, animation_frame_delay
check_bottom_0:	; if ball is above scrolling text, slow down
	move.w	sprite_y(pc), d0
	cmpi.w	#SCRTEXT_V_OFFSET, d0
	blt.s	roll_frame
	move.w	#ANIMATION_FAST, animation_frame_delay	

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
	lea	TABY+200, a0
	cmp.l	a0, d1
	bne.s	check_bottom_2
	move.w	#$0012, SPRITE_PRIORITY
	;bsr.w	close_chessboard
	move.b	#CHESSBOARD_CLOSE, chessboard_action	; close chessboard square
check_bottom_2:
	lea	TABY+280, a0
	cmp.l	a0, d1
	bne.s	exit_sprite_move
	move.w	#0, SPRITE_PRIORITY
	;bsr.w	open_chessboard
	move.b	#CHESSBOARD_OPEN, chessboard_action	; open chessboard square

exit_sprite_move:   
	rts

enable_anim_chessboard_courtaine_flag:	dc.w	0

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


swap_buffer:
	move.l	draw_buffer(pc), d0		
	move.l	view_buffer(pc), draw_buffer	
	move.l	d0, view_buffer			
				
	lea	BPLPOINTERS_L, a1	
	moveq	#bpls_L-1, d1	
POINTBP:
	move.w	d0,6(a1)
	swap	d0
	move.w	d0,2(a1)
	swap	d0
	
	addi.l	#ScrLBpl*h_L, d0
	
	addq.w	#8, a1
	
	dbra	d1, POINTBP

	rts

view_buffer	dc.l	SCREEN_L	; displayed buffer
draw_buffer	dc.l	SCREEN_L_2	; drawn buffer
	
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
CLR_BOARD= $104
PALETTE:	

	dc.w CLR_STRT+00,$0cb2,CLR_STRT+02,$0ee3,CLR_STRT+04,$0ffd
	dc.w CLR_STRT+06,$0a81,CLR_STRT+08,$0860,CLR_STRT+10,$0640
	dc.w CLR_STRT+12,$0420

	dc.w CLR_STRT+14,CLR_BOARD,CLR_STRT+16,$0cb2,CLR_STRT+18,$0ee3
	dc.w CLR_STRT+20,$0ffd,CLR_STRT+22,$0a81,CLR_STRT+24,$0860
	dc.w CLR_STRT+26,$0000

	dc.w	$3007, $fffe
	dc.w	CLR_STRT+14, CLR_BOARD+$001
	dc.w	$3407, $fffe
	dc.w	CLR_STRT+14, CLR_BOARD+$101
	dc.w	$3807, $fffe
	dc.w	CLR_STRT+14, CLR_BOARD+$102
	dc.w	$3c07, $fffe
	dc.w	CLR_STRT+14, CLR_BOARD+$202
	dc.w	$4007, $fffe
	dc.w	CLR_STRT+14, CLR_BOARD+$203
	dc.w	$4407, $fffe
	dc.w	CLR_STRT+14, CLR_BOARD+$303
	dc.w	$4807, $fffe
	dc.w	CLR_STRT+14, CLR_BOARD+$304
	dc.w	$4c07, $fffe
	dc.w	CLR_STRT+14, CLR_BOARD+$404
	dc.w	$5007, $fffe
	dc.w	CLR_STRT+14, CLR_BOARD+$405
	dc.w	$5407, $fffe
	dc.w	CLR_STRT+14, CLR_BOARD+$505

START_LORES = ($2c+h_H)*$100+07

	dc.w	START_LORES,$fffe

*********** LORES **************	
	
	dc.w	$92,$0038	; DdfStart
	dc.w	$94,$00d0	; DdfStop
	dc.w	$102,0	; BplCon1
	dc.w	$108,0	; Bpl1Mod
	dc.w	$10a,0	; Bpl2Mod
	
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

	dc.w	$d207,$fffe
	dc.w	$0182,$0af0

	dc.w	$da07,$fffe
	dc.w	$0182,$0cf0

	dc.w	$e27,$fffe
	dc.w	$0182,$0ef0

	dc.w	$ea07,$fffe
	dc.w	$0182,$0fc0

	dc.w	$f207,$fffe
	dc.w	$0182,$0ff0

	dc.w	$ffdf,$fffe

	dc.w	$1607,$fffe
	dc.w	$0182,$0444
	dc.w	$0180,$0004
	dc.w	$0108,-80
	dc.w	$010a,-80
	dc.w	$1807,$fffe
	dc.w	$0180,$0006
	dc.w	$1a07,$fffe
	dc.w	$0180,$0008
	dc.w	$1e07,$fffe
	dc.w	$0182,$0884
	dc.w	$0180,$0009
	dc.w	$2307,$fffe
	dc.w	$0180,$000A

	
	dc.w	$FFFF,$FFFE	; End of copperlist


*****************************************
*             BALL SPRITE               *
*                                       *
*       4 sprites for each frame	*
*	in attached mode		* 
*	8 anim frames       		*
*                                       *
*****************************************

	incdir	"dh1:own/demo/repository/demo/3/"
    
frame1:
	incbin	"ball_frame1"

frame2:
	incbin	"ball_frame2"

frame3:
	incbin	"ball_frame3"

frame4:
	incbin	"ball_frame4"
	
frame5:
	incbin	"ball_frame5"
	
frame6:
	incbin	"ball_frame6"

frame7:
	incbin	"ball_frame7"
	
frame8:
	incbin	"ball_frame8"
	

*****************************************************************************

	SECTION	Data,DATA_C
	
OFFSET_TAB:	; contains the effective address pointer for each line
	ds.w	256
		; for standard lores bitplane is 0=0, 1=40, 2=80, etc
		; for interleaved lores bitplane is 0=0, 1=40*bpls, 2=80*bpls, etc

FONT_HEADER:
	incdir	"dh1:own/demo/repository/resources/fonts/"
	incbin	"32x32-FI.raw"

FONT:
	incdir	"dh1:own/demo/repository/resources/fonts/"
	incbin  "16X16-F2_944_16_1.raw"

*****************************************************************************

	SECTION Music,DATA_C
M_DATA:
	incdir  "dh1:own/demo/repository/resources/mod/"
	incbin  "p61.venezia"
	
*****************************************************************************

	SECTION	SCREEN, BSS_C	

SCREEN_H:
	ds.b	ScrHBpl*h_H*bpls_H		
SCREEN_L:
	ds.b	ScrLBpl*h_L*bpls_L
SCREEN_L_2:
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
