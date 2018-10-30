*****************************************************************************
*									    *
*    	This is interactive sine scrolling text example			    *
*									    *
*    									    *
*    									    *
*    									    *
*    									    *
*    									    *
*									    *
*****************************************************************************

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


;;    ---  screen buffer dimensions  ---

w	=320
h	=256
bplsize	=w*h/8
ScrBpl	=w/8	; standard screen width + 2 bytes
		; where we'll place the char data

bpls = 2

;wbl = $2c (for copper monitor only)
wbl = 303
;wbl  = $DA

FONTSET_WIDTH   = 944   ; pixel
FONTSET_HEIGHT  = 16    ; pixel

FONT_WIDTH  = 16 ; pixel
FONT_HEIGHT = 16 ; pixel

TEXT_V_OFFSET = 100
SCREEN_VOFFSET = TEXT_V_OFFSET*ScrBpl*bpls


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

START:
    	;move.l  #SCREEN,d0  ; point to bitplane
    	;lea BPLPOINTERS,a1  ; 
   	;moveq   #bpls-1,d1  ; 2 BITPLANE
;POINTBP:
    	;move.w  d0,6(a1)    ; copy low word of pic address to plane
    	;swap    d0          ; swap the the two words
   	;move.w  d0,2(a1)    ; copy the high word of pic address to plane
    	;swap    d0          ; swap the the two words
        ;
	;add.l   #ScrBpl,d0      ; BITPLANE point to next byte line data
        ;                ; instead of the standard raw
        ;                ; where bitplane is immediately
        ;                ; after the previous bitplane
        ;                ; standard raw (40*256)
        ;                ; blitter raw (40)
	;		; notice the +2 bytes where to place char data
	;		
	;addq.w  #8,a1   ; the next bpl starts one row
        ;        	; after the previous one	
	;dbra    d1,POINTBP
	
	move.l	#sprite, d0		; SPRITE pointer
	lea	SPRITEPOINTERS,a1
	move.w	d0,6(a1)
	swap	d0
	move.w	d0,2(a1)
    
	lea	OFFSET_TAB, a0	
	moveq	#0, d0		
	move.w	#256-1, d7	
fill_offset_tab:
	move.w	d0,(a0)+		; put ScrBpl on each word value
	add.w	#ScrBpl*bpls, d0		; ScrBpl+ScrBpl...
	dbra	d7, fill_offset_tab
    

	move.w  #DMASET,$dff096     ; enable necessary bits in DMACON
	move.w  #INTENASET,$dff09a     ; INTENA
    
	move.l  #COPPERLIST,$dff080 ; COP1LCH set custom copperlist
   	move.w  #0,$dff088      ; COPJMP1 activate copperlist
	
	lea	$dff000,a5

	move.b	JOY0DAT(a5),	mouse_y
	move.b	JOY0DAT+1(a5),	mouse_x
	
Main:
	WAITVB  Main
	
	bsr.w	swap_buffer
	
	bsr.s	read_mouse_coords

	;***** COPPER MONITOR
	;move.w  #$F00, $dff180
	
	bsr.w	print_char
	bsr.w	scroll_text
	bsr.w	compute_offset
	bsr.w	copy_text_buffer_to_screen
	bsr.w	clear_area	
	;bsr.w	draw_point	; just for debug 
	bsr.w	make_camel

	;**** COPPER MONITOR
	;move.w  #0, $dff180
		
	bsr.w	sprite_move
		
	
	
Wait    WAITVB2 Wait

WaitRm:
	RMOUSE WaitRm
	
	LMOUSE Main

	rts		; exit
	

SPRITE_HEIGHT = 13

MOUSEX_SPRITE_POINTER = 8
MOUSEY_SPRITE_POINTER = SPRITE_HEIGHT+1


*************************************
*   	read mouse coords           *
*                                   *
*   				    *
*   		                    *
*   		                    *
*                                   *
*************************************

read_mouse_coords:
	move.b	JOY0DAT(a5), d1	; JOY0DAT vertical mouse pos
	move.b	d1,d0		 
	sub.b	mouse_y(PC),d0	; subtract old mouse pos
	beq.s	no_vert		; check if mouse has moved from old pos
	ext.w	d0		 
				 
	add.w	d0, sprite_y	; set sprite pos
no_vert:
  	move.b	d1, mouse_y	; save pos Y

	move.b	JOY0DAT+1(a5),d1; JOY0DAT horizontal mouse pos
	move.b	d1,d0		 
	sub.b	mouse_x(PC),d0	; subtract old mouse pos
	beq.s	no_horiz		
	ext.w	d0		 
				 
	add.w	d0, sprite_x	; set sprite pos
no_horiz
  	move.b	d1, mouse_x	; save pos X

check_rx_margin:
	cmpi.w	#320-MOUSEX_SPRITE_POINTER-1, sprite_x
	ble.s	check_lx_margin
	move.w	#320-MOUSEX_SPRITE_POINTER-1, sprite_x

check_lx_margin:
	cmpi.w	#-MOUSEX_SPRITE_POINTER, sprite_x
	bge.s	check_yt_margin
	move.w	#-MOUSEX_SPRITE_POINTER, sprite_x

check_yt_margin:
	tst	sprite_y
	bge.s	check_yb_margin
	move.w	#0, sprite_y
	
check_yb_margin:
	cmpi.w	#$FF-SPRITE_HEIGHT-FONT_HEIGHT, sprite_y
	ble.s	exit_check
	move.w	#$FF-SPRITE_HEIGHT-FONT_HEIGHT, sprite_y

exit_check:	
	rts

sprite_y:	dc.w	0	 
sprite_x:	dc.w	0
mouse_y:	dc.b	0	 
mouse_x:	dc.b	0	 

	
	
*************************************
*   plot point routine              *
*                                   *
*   <INPUT>                         *
*   D0: X POINT COORD               *
*   D1: Y POINT COORD               *
*                                   *
*************************************

plot_point:

	lea	SCREEN, a0
	lea	OFFSET_TAB, a1
	
	move.w	d0, d2
	lsr.w	#3, d0

	add.w	d1, d1	; mul 2 because precalc table is made of word
				
	add.w	(a1,d1.w), d0 ; get Y byte offset from precalc table

	and.w	#%111,d2	; get pixel of the last byte
	not.w	d2		

	bset.b	d2,(a0,d0.w)	; write the point on bitplane
				
	rts


text_offset_pointer dc.l    TEXT

*****************************************************************************
* 
* 	Print char over the right screen margin
*
*
*****************************************************************************

SCROLL_COUNT = 8	; (FONT_WIDTH / pixel shift)
counter:	dc.w	SCROLL_COUNT	;

	
print_char:
	
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
	
	BLTWAIT BWT1

	move.l	#$09f00000,BLTCON0(a5)	; BLTCON0: A-D
	move.l	#$ffffffff,BLTAFWM(a5)	; BLTAFWM + BLTALWM 

	move.l	a2,BLTAPT(a5)	; BLTAPT: font address

	move.l	#BUFFER+40,BLTDPT(a5) 
			; print to not visible screen area
	move.w	#(FONTSET_WIDTH-FONT_WIDTH)/8,BLTAMOD(a5) ; BLTAMOD: modulo font
	move.w	#ScrBpl+2-FONT_WIDTH/8,BLTDMOD(a5)	  ; BLTDMOD: modulo bit planes
	move.w	#(bpls*FONTSET_HEIGHT*64)+FONT_WIDTH/16,BLTSIZE(a5) 	; BLTSIZE	
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

	move.l	#BUFFER+(FONT_HEIGHT*42*bpls)-2,d0 ; source and dest address

	BLTWAIT BWT2

	move.l	#$29f00002,BLTCON0(a5)	; BLTCON0 copy from A to D ($F) 
					; 1 pixel shift, LF = F0
	;move.w	#$0002,BLTCON1(a5)	; BLTCON1 use blitter DESC mode
					

	move.l	#$ffff7fff,BLTAFWM(a5)	; BLTAFWM / BLTALWM
					; BLTAFWM = $ffff - 
					; BLTALWM = $7fff = %0111111111111111
					; mask the left bit


	move.l	d0,BLTAPT(a5)			; BLTAPT - source
	move.l	d0,BLTDPT(a5)			; BLTDPT - dest

	; scroll an image of the full screen width * FONT_HEIGHT

	move.l	#$00000000,BLTAMOD(a5)	; BLTAMOD + BLTDMOD 
	move.w	#(FONT_HEIGHT*bpls*64)+21,BLTSIZE(a5)	; BLTSIZE
	rts					

	
	
copy_text_buffer_to_screen:
		
	move.w	y1(pc), d0
	tst	d0
	beq.w	copy_whole_text
	
;copy_left_area:

	;move.l	draw_buffer(pc), a0
	;addi.w	#SCREEN_VOFFSET, a0	; SCREEN offset
	
	cmpi.w	#20, w_sine_length	; w_sine_length
	bne	copy_whole_text
	
	rts	; does not draw because it is useless

	;THE MAIN PURPOSE OF THE CODE BELOW WAS TO DRAW JUST THE PARTIAL TEXT
	;HOWEVER IT WAS COMMENTED BECAUSE IT DOES NOT IMPROVE PERFORMANCE
	
	
;	move.w	d0, d1
;	add.w	d1, d1	; w_x0 in bytes
;	
;	BLTWAIT BWT8
;	
;	move.l	#$09f00000, BLTCON0(a5)	; BLTCON0+BLTCON1 (A-D) 
;	move.l	#$ffffffff, BLTAFWM(a5)	; BLTAFWM / BLTALWM	
;	move.l	#BUFFER, BLTAPT(a5)	; BLTAPT - source
;	move.l	a0, BLTDPT(a5)	; BLTDPT - dest
;	
;	moveq	#ScrBpl+2, d2
;	sub.w	d1, d2
;		
;	move.w	d2, BLTAMOD(a5)
;	subq	#2, d2
;	move.w	d2, BLTDMOD(a5)
;	
;	move.w	#(FONT_HEIGHT*bpls*64), d2
;	add.w	d0, d2
;	move.w	d2, BLTSIZE(a5)	; BLTSIZE
;	
;copy_right_area:
;	
;	move.w	w_sine_length(pc), d1	; w_sine_length	
;	add.w	d0, d1	; w_x0 + w_sine_length
;	moveq	#20, d3	
;	sub.w	d1, d3	; 20 - w_x0 + w_sine_length 
;	tst	d3	; right area to copy in words
;	beq	exit_copy_text_buffer_to_screen
;	
;	add.w	d1, d1	; w_x0 + w_sine_length in bytes
;	move.w	d3, d0
;	add.w	d0, d0	; right area to copy in bytes
;	
;	moveq	#ScrBpl+2, d2
;	sub.w	d0, d2
;
;	BLTWAIT BWT9
;	
;	move.w	d2, BLTAMOD(a5)
;	subq	#2, d2
;	move.w	d2, BLTDMOD(a5)
;	
;	lea	BUFFER, a1
;	add.w	d1, a1
;	
;	move.l	#$09f00000, BLTCON0(a5)	; BLTCON0+BLTCON1 (A-D) 
;	move.l	#$ffffffff, BLTAFWM(a5)	; BLTAFWM / BLTALWM	
;	move.l	a1, BLTAPT(a5)	; BLTAPT - source
;	add.w	d1, a0
;	move.l	a0, BLTDPT(a5)	; BLTDPT - dest
;	
;	move.w	#(FONT_HEIGHT*bpls*64), d2
;	add.w	d3, d2
;	move.w	d2, BLTSIZE(a5)	; BLTSIZE
;	
;exit_copy_text_buffer_to_screen:
;	rts
	
	
copy_whole_text:

	BLTWAIT BWT3

	move.l	#$09f00000,BLTCON0(a5)	; BLTCON0+BLTCON1 (A-D) 
	move.l	#$ffffffff,BLTAFWM(a5)	; BLTAFWM / BLTALWM
	move.l	draw_buffer(pc), a0
	addi.w	#SCREEN_VOFFSET, a0

	move.l	#BUFFER,BLTAPT(a5)			; BLTAPT - source
	move.l	a0,BLTDPT(a5)	; BLTDPT - dest

	; scroll an image of the full screen width * FONT_HEIGHT

	move.l	#$00020000,BLTAMOD(a5)	; BLTAMOD + BLTDMOD 
	move.w	#(FONT_HEIGHT*bpls*64)+20,BLTSIZE(a5)	; BLTSIZE

	rts			



draw_point:

	move.w	x0(pc), d0
	move.w	#SCREEN_VOFFSET/ScrBpl/bpls, d1
	bsr.w	plot_point
	
	move.w	x1(pc), d0	
	move.w	#SCREEN_VOFFSET/ScrBpl/bpls, d1
	add.w	y1(pc), d1
	bsr.w	plot_point
	
	;move.w	x2(pc), d0
	;move.w	#SCREEN_VOFFSET/ScrBpl/bpls, d1
	;bsr.w	plot_point
	
	move.w	w_x0(pc), d0	
	lsl	#4, d0	
	move.w	#SCREEN_VOFFSET/ScrBpl/bpls, d1
	bsr.w	plot_point
	
	;move.w	w_x2(pc), d0	
	;lsl	#4, d0	
	;move.w	#SCREEN_VOFFSET/ScrBpl/bpls, d1
	;bsr.w	plot_point
	
	rts
	
	
****************************************************
*
*
*	-----------------------------------
*	x0/xd0		x1		 x2
*			 |
*		(y0)  	 |
*			 |
*			y1
*
****************************************************
	
x0:	dc.w	0
x1:	dc.w	0	; pixel between left margin and x1
x2:	dc.w	0	; pixel between x1 and right margin
xd0:	dc.w	0	; delta x (xe = x0 >= 0 ? 0 : abs(x)/2) **
y1:	dc.w	0	; vertical distance between y1 and x1 in pixel

w_x0:	dc.w	0	; x0 in word


s_x0:	dc.w	0	; x point where sine starts
s_x1:	dc.w	0	; x point where delta change
s_x2:	dc.w	0	; x point where sine ends

w_sine_length:	dc.w	0	; sine length in word


;** y0 advance of 1 every 2pixel

compute_offset:

	move.w	sprite_x(pc), x1
	addi.w	#MOUSEX_SPRITE_POINTER, x1
	move.w	sprite_y(pc), d0
	addi.w	#MOUSEY_SPRITE_POINTER, d0
	subi.w	#TEXT_V_OFFSET, d0
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
	move.w	d0, x2		; x2
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
		
	;move.w	#ScrBpl*bpls, d1	; const delta y	
	
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
	lea	OFFSET_TAB, a1
	add.w	d0, d0
	move.w	(a1,d0.w), d0	; if x0 is <0, xd0 starts from 
	
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
*	clear area routiner
*	
*     clear possible dirty area
*
********************************************

old_y1:			dc.w	0,0	; we store 2 values of old_y1, one for each buffer.
					; Once we use the correct old_y1
					; we swap the 2 words in order to work
					; with the correct old_y1 value

clear_area:

	move.l	draw_buffer(pc), a0
	addi.w	#(TEXT_V_OFFSET+FONT_HEIGHT)*ScrBpl*bpls, a0
	
	move.l	old_y1(pc), d3	; old_y1
	
	tst.w	d3
	beq	clear_text_sine_involved
	
	BLTWAIT BWT4	
	; clear below text area
		
	move.l	#$01000000,BLTCON0(a5)	; BLTCON0 / BLTCON1 delete (only D)
	move.l	#$ffffffff,BLTAFWM(a5)	; BLTAFWM / BLTALWM
	move.l	#0,BLTAPT(a5)		; BLTAPT - source	
	move.l	a0,BLTDPT(a5)	; BLTDPT - dest
	move.w	#0, BLTAMOD(a5)	; BLTAMOD
	move.w	#0, BLTDMOD(a5)	; BLTDMOD
	
	;lsl	#6, d3	; UNCOMMENT IF BPLS=1
	lsl	#7, d3	; UNCOMMENT IF BPLS=2
	addi.w	#20, d3
	move.w	d3, BLTSIZE(a5)
	
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
	
	move.w	#ScrBpl, d0
	sub.w	d1, d0
	sub.w	d1, d0
	move.w	d0, BLTDMOD(a5)		; BLTDMOD
	
	move.w	#(FONT_HEIGHT*bpls*64), d0
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
	
	;lea	SCREEN+SCREEN_VOFFSET, a2
	move.l	draw_buffer(pc), a2
	addi.w	#SCREEN_VOFFSET, a2
	
	lea	(a2,d0.w), a2
	
	move.w	xd0(pc), d0	
	move.w	#ScrBpl*bpls, d1	; const delta y		
	moveq	#0, d2		; sine counter
	move.w	s_x0(pc), d3	; move s_x0 to d3
	lea	s_x1, a4	; load s_x1 to a4
	move.w	s_x2(pc), d4	; move s_x2 to d4		
	move.w	#$C000, d5
	
	BLTWAIT BWT7

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
	move.w	#(FONT_HEIGHT*bpls*64)+1, BLTSIZE(a5)	; BLTSIZE
	
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

sprite_move:

	lea	sprite, a1
	move.w	sprite_y(pc), d0
	move.w	sprite_x(pc), d1 	
	moveq   #SPRITE_HEIGHT, d2
	
	bsr.s	generic_sprite_move

exit_sprite_move:   
    rts
    

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
	addi.w  #128,d1     ; 128 - sprite center
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

	
swap_buffer:
	move.l	draw_buffer(pc), d0
	move.l	view_buffer(pc), draw_buffer
	move.l	d0, view_buffer
				
	lea	BPLPOINTERS, a1
	moveq	#bpls-1, d1
POINTBP:
	move.w	d0,6(a1)
	swap	d0
	move.w	d0,2(a1)
	swap	d0
	add.l	#ScrBpl, d0
	addq.w	#8, a1
	dbra	d1, POINTBP

	rts

view_buffer	dc.l	SCREEN		; displayed buffer
draw_buffer	dc.l	SCREEN_2	; drawn buffer

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
	dc.w	$92,$38		; DdfStart
	dc.w	$94,$d0		; DdfStop
	dc.w	$102,0		; BplCon1
	dc.w	$104,0		; BplCon2
	dc.w	$108,(ScrBpl*(bpls-1)) 	; Bpl1Mod  INTERLEAVED MODE+2!
	dc.w	$10a,(ScrBpl*(bpls-1))	; Bpl2Mod  INTERLEAVED MODE+2!

	dc.w	$100,bpls*$1000+$200	; bplcon0 - bitplane lowres

BPLPOINTERS:
	dc.w $e0,$0000,$e2,$0000	;first bitplane
	dc.w $e4,$0000,$e6,$0000	;second bitplane
	
	dc.w	$0180,$0000	; color0
	dc.w	$0182,$08f6	; color1
	dc.w	$0184,$04b2	; color2
	dc.w	$0186,$0270	; color3
	
	
	dc.w	$1A2,$ddd	; color17
	dc.w	$1A4,$e00	; color18
	dc.w	$1A6,$f00	; color19


	
	dc.w $FFFF,$FFFE	; End of copperlist

*****************************************************************************

	SECTION	Data,DATA_C


sprite:
	dc.w	$0000,$0000
	dc.w	%0000001111000000,%0000000000000000
	dc.w	%0000001111000000,%0000000000000000
	dc.w	%0000001111000000,%0000000000000000
	dc.w	%0000001111000000,%0000000000000000
	dc.w	%0000001111000000,%0000000000000000
	dc.w	%0000001111000000,%0000000000000000
	dc.w	%0000001111000000,%0000000000000000
	dc.w	%0000001111000000,%0000000000000000
	dc.w	%0000111111110000,%0001000000001000
	dc.w	%1111111111111111,%1000000000000001
	dc.w	%0011111111111100,%0010000000000100
	dc.w	%0000111111110000,%0000100000010000
	dc.w	%0000001111000000,%0000001001000000
	dc.w	0,0	
	
FONT:
	incdir  "dh1:own/demo/repository/resources/fonts/"	
	;incbin  "16X16-F2_944_16_1.raw"		; BPLS=1
	incbin  "16X16-F2_944_16_2.blt.raw"	; BPLS=2
	
*****************************************************************************

	SECTION	Screen,BSS_C	

OFFSET_TAB:	; contains the effective address pointer for each line
	ds.w	256
		; for standard lores bitplane is 0=0, 1=40, 2=80, etc
		; for interleaved lores bitplane is 0=0, 1=40*bpls, 2=80*bpls, etc
	
SCREEN:
	ds.b	ScrBpl*h*bpls		; 2 bitplane
SCREEN_2:
	ds.b	ScrBpl*h*bpls		; 2 bitplane
BUFFER:
	ds.b	(ScrBpl+2)*bpls*FONT_HEIGHT

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
