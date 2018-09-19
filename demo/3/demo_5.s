*****************************************************************************
*									    *
*    This is scrolling text example					    *
*									    *
*    Notice the screen modulo with + 2 					    *
*    so we can print the char onto not visible screen area (byte 40)	    *
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
	incdir	"dh1:own/demo/repository/example/blitter/"	
	include "hardware/custom.i"
*****************************************************************************


;;    ---  screen buffer dimensions  ---

w	=320
h	=256
bplsize	=w*h/8
ScrBpl	=w/8+2	; standard screen width + 2 bytes
		; where we'll place the char data

bpls = 2

;wbl = $2c (for copper monitor only)
wbl = 303

FONTSET_WIDTH   = 944   ; pixel
FONTSET_HEIGHT  = 16    ; pixel

FONT_WIDTH  = 16 ; pixel
FONT_HEIGHT = 16 ; pixel

SCREEN_VOFFSET = 180*ScrBpl*bpls


WAITVB MACRO
   	move.l  $dff004,d0      ; wait
 	and.l   #$0001ff00,d0   ; for
   	cmp.l   #wbl<<8,d0      ; rasterline 303
	bne.s   \1
	ENDM

WAITVB2 MACRO
	move.l  $dff004,d0      ; wait
 	and.l   #$0001ff00,d0    for
	cmp.l   #wbl<<8,d0      ; rasterline 303
	beq.s   \1
	ENDM

BLTWAIT	MACRO
	tst DMACONR(a6)			;for compatibility
\1
	btst #6,DMACONR(a6)
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
    	move.l  #SCREEN,d0  ; point to bitplane
    	lea BPLPOINTERS,a1  ; 
   	MOVEQ   #bpls-1,d1  ; 2 BITPLANE
POINTBP:
    	move.w  d0,6(a1)    ; copy low word of pic address to plane
    	swap    d0          ; swap the the two words
   	move.w  d0,2(a1)    ; copy the high word of pic address to plane
    	swap    d0          ; swap the the two words

	add.l   #ScrBpl,d0      ; BITPLANE point to next byte line data
                        ; instead of the standard raw
                        ; where bitplane is immediately
                        ; after the previous bitplane
                        ; standard raw (40*256)
                        ; blitter raw (40)
			; notice the +2 bytes where to place char data
			
	addq.w  #8,a1   ; the next bpl starts one row
                	; after the previous one	
	dbra    d1,POINTBP
    
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

Main:
	WAITVB  Main
	
	bsr.s	print_char
	bsr.w	scroll_text
	bsr.w	copy_text_buffer_to_screen
	bsr.w	compute_offset
	bsr.w	clear_area
	bsr.w	make_sine
	bsr.w	draw_point	
	
	bsr.w	sprite_animation
	bsr.w	sprite_move

Wait    WAITVB2 Wait

WaitRm:
	RMOUSE WaitRm
	
	LMOUSE Main

	rts		; exit

	
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
* Print char over the right screen margin
* 
*
*
*****************************************************************************

SCROLL_COUNT = 16	; (FONT_WIDTH / pixel shift)
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
	move.w	#ScrBpl-FONT_WIDTH/8,BLTDMOD(a5)	  ; BLTDMOD: modulo bit planes
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

	move.w	#$19f0,BLTCON0(a5)	; BLTCON0 copy from A to D ($F) 
					; 1 pixel shift, LF = F0
	move.w	#$0002,BLTCON1(a5)	; BLTCON1 use blitter DESC mode
					

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
	
	BLTWAIT BWT3

	move.w	#$09f0,BLTCON0(a5)	; BLTCON0 copy from A to D ($F) 
					; 1 pixel shift, LF = F0
	move.w	#$0000,BLTCON1(a5)	; BLTCON1 use blitter ASC mode
					

	move.l	#$ffffffff,BLTAFWM(a5)	; BLTAFWM / BLTALWM
					; BLTAFWM = $ffff  
					; BLTALWM = $ffff 
					

	move.l	#BUFFER,BLTAPT(a5)			; BLTAPT - source
	move.l	#SCREEN+SCREEN_VOFFSET,BLTDPT(a5)	; BLTDPT - dest

	; scroll an image of the full screen width * FONT_HEIGHT

	move.l	#$00000000,BLTAMOD(a5)	; BLTAMOD + BLTDMOD 
	move.w	#(FONT_HEIGHT*bpls*64)+21,BLTSIZE(a5)	; BLTSIZE
	rts			



draw_point:

	move.w	x0, d0
	move.w	#SCREEN_VOFFSET/ScrBpl/bpls, d1
	bsr.w	plot_point
	
	move.w	x1, d0	
	move.w	#SCREEN_VOFFSET/ScrBpl/bpls, d1
	addi.w	y1, d1
	bsr.w	plot_point
	
	move.w	x2, d0
	move.w	#SCREEN_VOFFSET/ScrBpl/bpls, d1
	bsr.w	plot_point
	
	move.w	w_x0, d0	
	lsl	#4, d0	
	move.w	#SCREEN_VOFFSET/ScrBpl/bpls, d1
	bsr.w	plot_point
	
	move.w	w_x2, d0	
	lsl	#4, d0	
	move.w	#SCREEN_VOFFSET/ScrBpl/bpls, d1
	bsr.w	plot_point

	rts
	
	
********************************************
;	
;
;	-----------------------------------
;	x0		x1		 x2
;			 |
;		y0	 |
;			 |
;			y1
;
********************************************
	
	
x0:	dc.w	0
x1:	dc.w	199	; pixel between left margin and x1
x2:	dc.w	0
            
y0:	dc.w	0
y1:	dc.w	10	; vertical distance between y1 and x1 in pixel
            
w_x0:	dc.w	0	; x0 in word
w_x1:	dc.w	0	; x1 in word
w_x2:	dc.w	0	; x2 in word

sine_length:	dc.w	0	; sine length in byte
w_sine_length:	dc.w	0	; sine length in word


compute_offset:

	move.w	y1, d0
	btst	#0, d0
	beq.s	get_w_x1
	addq	#1, y1		; if y1 is odd, add 1
get_w_x1:
	
	move.w	x1, d0
	lsr	#3, d0		
	move.w	d0, w_x1	; w_x1
	
	move.w	x1, d0
	sub.w	y1, d0
	btst	#0, d0
	beq.s	save_x0
	subq	#1, d0		; if x0 is odd, subtract by 1
save_x0:
	move.w	d0, x0		; x0
	lsr	#4, d0	
	move.w	d0, w_x0	; w_x0
	;; TODO handle case if y1 > x1
	
	move.w	x1, d0
	add.w	y1, d0
	move.w	d0, x2		; x2
	move.w	d0, d1
	lsr	#4, d0
	and.w	#%1111, d1	; check if mod 16 > 0
	tst	d1
	beq.s	save_w_x2
	addq	#1, d0
save_w_x2:
	move.w	d0, w_x2	; w_x2	
	
	sub.w	w_x0, d0
	tst	d0
	bne.s	w_x0_not_negative
	moveq	#1, d0			; w_sine_length is min 1
w_x0_not_negative:
	move.w	d0, d1
	move.w	d1, d2
	add.w	w_x0, d1
	cmpi.w	#20, d1			; check if w_x0 + sine_length 
	ble.s	set_word_loop_cnt	; goes beyond screen right margin
	sub.w	#20, d2			; force sine_length = 20 - w_x0
	add.w	w_x0, d2		; 
set_word_loop_cnt:
	move.w	d2, d0
	move.w	d0, w_sine_length	; w_sine_length
	add.w	d0, d0			
	move.w	d0, sine_length		; sine_length
	
	rts


********************************************
*
*	CLEAR AREA UNDER TEXT
*
********************************************

clear_area:

	BLTWAIT BWT4
	
	; clear under text area
	
	move.w	#$0100,BLTCON0(a5)	; BLTCON0 delete (only D)
	move.w	#$0000,BLTCON1(a5)	; BLTCON1 use blitter ASC mode
	move.l	#$ffffffff,BLTAFWM(a5)	; BLTAFWM / BLTALWM
	move.l	#0,BLTAPT(a5)		; BLTAPT - source	
	move.l	#SCREEN+SCREEN_VOFFSET+(FONT_HEIGHT*ScrBpl*bpls),BLTDPT(a5)	; BLTDPT - dest
	move.w	#0, BLTAMOD(a5)	; BLTAMOD
	move.w	#ScrBpl-40, BLTDMOD(a5)	; BLTAMOD
	move.w	#(FONT_HEIGHT*3*bpls*64)+20, BLTSIZE(a5)	; BLTSIZE
	
	BLTWAIT BWT5
	
	; clear text where sine is involved
		
	lea	SCREEN+SCREEN_VOFFSET, a0	
	move.w	w_x0, d0
	add.w	d0, d0			; in bytes
	lea	(a0,d0.w), a0	
	move.l	a0, BLTDPT(a5)		; BLTDPT
	
	move.w	#ScrBpl, d0
	sub.w	sine_length, d0
	move.w	d0, BLTDMOD(a5)		; BLTDMOD
	
	move.w	#(FONT_HEIGHT*bpls*64), d1
	add.w	w_sine_length, d1	; BLTAMOD
	move.w	d1, BLTSIZE(a5)		; BLTSIZE
		
	rts

temp:	dc.w	0

s_x0:	dc.w	0	; x0 point - w_x0 point
s_x1:	dc.w	0	; x1 pixel from x0
s_x2:	dc.w	0	; x2 pixel from x0

make_sine:
	
	lea	BUFFER, a1
	move.w	w_x0, d0
	add.w	d0,d0
	lea	(a1,d0.w), a1
	
	lea	SCREEN+SCREEN_VOFFSET, a2
	lea	(a2,d0.w), a2
	
	moveq	#0, d0
	move.w	#ScrBpl*bpls*2, d1	; delta y
	move.w	#$C000, d5
	
	move.w	x0, d2
	and.w	#%1111, d2	; modulo 16 of x0
	
	move.w	d2, s_x0	; s_x0	
	add.w	y1, d2
	move.w	d2, s_x1	; s_x1
	add.w	y1, d2	
	move.w	d2, s_x2	; s_x2
	
	moveq	#0, d2	
	
	move.w	w_sine_length, d6	; word loop cnt
	subq	#1, d6	
word_loop:
	moveq	#8-1, d7	; slice loop cnt
slice_loop:	
	cmp.w	s_x0, d2	; check if x0 is reached	
	blt.s	start_slice	
	cmp.w	s_x1, d2	; check if x1 is reached	
	bne.s	add_delta
	neg.w	d1	
add_delta:
	cmp.w	s_x2, d2	; check if x2 is reached	
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

	move.w	#$0028, BLTCMOD(a5)	; BLTCMOD=42-2=$28
	move.l	#$00280028, BLTAMOD(a5)	; BLTAMOD=42-2=$28
					; BLTDMOD=42-2=$28

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

	
	


; this routine animate the sprite
; by scrolling each frame on top, then placing
; the first frame on last position
; doing a continue rotation cycle

ANIMATION_FRAME_DELAY = 5

sprite_frame_offset = $88 ; distance between frames

sprite_animation:
	addq.b  #1,animation_counter ; increase animation_counter
	cmp.b   #ANIMATION_FRAME_DELAY,animation_counter 
	bne.w   do_nothing     ; do not cycle next animation frame
	clr.b   animation_counter

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
	;swap   d0

do_nothing:
	rts

animation_counter:
	dc.w    0

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
    

BALL_HEIGHT = 32
BALL_WIDTH = 32



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
    
    move.l  FRAMETAB(PC),a1 ; sprite 0 address
    move.w  d4,d0       ; copy Y to D0
    move.w  d3,d1       ; copy X to D1
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

TABX:
	dc.w	$0
ENDTABX

TABY:
    	dc.b	$0
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
	dc.w	$92,$38		; DdfStart
	dc.w	$94,$d0		; DdfStop
	dc.w	$102,0		; BplCon1
	dc.w	$104,0		; BplCon2
	dc.w	$108,(ScrBpl*(bpls-1))+2 ; Bpl1Mod  INTERLEAVED MODE+2!
	dc.w	$10a,(ScrBpl*(bpls-1))+2 ; Bpl2Mod  INTERLEAVED MODE+2!

	dc.w	$100,bpls*$1000+$200	; bplcon0 - bitplane lowres

BPLPOINTERS:
	dc.w $e0,$0000,$e2,$0000	;first bitplane
	dc.w $e4,$0000,$e6,$0000	;second bitplane
	
	; ball sprite color palette (from 17 to 31)

	dc.w $01a2,$0887,$01a4,$0900,$01a6,$0555
	dc.w $01a8,$0600,$01aa,$0955,$01ac,$0222,$01ae,$0ed4
	dc.w $01b0,$0e01,$01b2,$0a69,$01b4,$0eaa,$01b6,$0eee
	dc.w $01b8,$0e54,$01ba,$0e6c,$01bc,$0aaa,$01be,$0777


	dc.w	$0180,$0000	; color0
	dc.w	$0182,$08f6	; color1
	dc.w	$0184,$04b2	; color2
	dc.w	$0186,$0270	; color3
	
	dc.w $FFFF,$FFFE	; End of copperlist

*****************************************************************************

	SECTION	Data,DATA_C


*****************************************
*             BALL SPRITE               *
*                                       *
*        4 sprites, 8 anim frames       *
*                                       *
*****************************************
    
frame1:

    dc.w $0000,$0000
    dc.w $0000,$0000,$0000,$0000,$0007,$0007,$003f,$003f
    dc.w $00ff,$00ff,$03ff,$03ff,$07fe,$07ff,$0ffe,$07ff
    dc.w $07fe,$07ff,$03fe,$07ff,$03fe,$01ff,$003d,$00fe
    dc.w $000f,$0000,$0001,$000e,$0000,$40ff,$0000,$03ff
    dc.w $0000,$3ffe,$0000,$5ffe,$0000,$4ff8,$0000,$01e0
    dc.w $0000,$0000,$2000,$2000,$0000,$1000,$0000,$1800
    dc.w $0400,$0600,$0100,$0780,$0000,$0382,$0000,$01c2
    dc.w $0000,$00fe,$0000,$003f,$0000,$0007,$0000,$0000
    dc.w 0,0




frame1a:
    dc.w $0000,$0080
    dc.w $0000,$0000,$0000,$0007,$0004,$003b,$0040,$00ff
    dc.w $0100,$01ff,$0000,$03ff,$0000,$07ff,$0800,$0fff
    dc.w $0800,$1fff,$0000,$1fff,$0201,$3fff,$0102,$3fff
    dc.w $0030,$3fff,$0001,$7ff0,$0000,$3f00,$4000,$3c00
    dc.w $0001,$0000,$2001,$0000,$1007,$0000,$261f,$0000
    dc.w $21ff,$0000,$0c3f,$0000,$1f07,$0000,$1f82,$0000
    dc.w $0380,$0000,$0680,$0000,$0382,$0000,$01c2,$0000
    dc.w $00fe,$0000,$003f,$0000,$0007,$0000,$0000,$0000
    dc.w 0,0

    
frame1b:


    dc.w $0000,$0000
    dc.w $0000,$0000,$e000,$e000,$1800,$1c00,$0200,$0d00
    dc.w $0080,$0f00,$0000,$1f80,$0000,$3f80,$0000,$7f90
    dc.w $8000,$7f18,$8010,$7e18,$8070,$7e7c,$81e0,$7dfc
    dc.w $ffe0,$03fc,$ffc0,$0ffe,$ff80,$1ffe,$ff00,$3ffc
    dc.w $fe00,$fffc,$f000,$fffa,$e000,$f3f2,$c000,$fff0
    dc.w $4000,$fff0,$0000,$f1e0,$0000,$e1f0,$0000,$e1e0
    dc.w $0000,$e180,$0000,$e000,$0000,$0000,$0000,$0000
    dc.w $0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000
    dc.w 0,0



frame1c:
    dc.w $0000,$0080
    dc.w $0000,$0000,$0000,$e000,$1400,$ec00,$0300,$f100
    dc.w $0080,$f000,$0040,$e000,$0060,$c000,$0070,$8000
    dc.w $80f8,$8000,$81e8,$0000,$818c,$0000,$821c,$0000
    dc.w $fc1c,$0000,$8c3e,$0c00,$987e,$1800,$b0fc,$3000
    dc.w $61fc,$6000,$0ffa,$0000,$13f2,$0000,$3ff0,$0000
    dc.w $bff0,$0000,$f1e0,$0000,$e1f0,$0000,$e1e0,$0000
    dc.w $e180,$0000,$e000,$0000,$0000,$0000,$0000,$0000
    dc.w $0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000
    dc.w 0,0


frame2:


    dc.w $0000,$0000
    dc.w $0000,$0000,$0007,$0007,$003f,$003f,$0080,$0080
    dc.w $0100,$0100,$0200,$0200,$0400,$0400,$0800,$0c00
    dc.w $1800,$1800,$1800,$1803,$3006,$301f,$301c,$307f
    dc.w $0a70,$31ff,$07e0,$0fff,$0f00,$0fff,$0c01,$0ffe
    dc.w $0807,$0ff8,$13bf,$6f41,$14ff,$6f8f,$0ffe,$37df
    dc.w $0ffe,$10ff,$0e7e,$1fff,$0438,$077f,$0608,$077f
    dc.w $0200,$03be,$0000,$0780,$0000,$0200,$0000,$0000
    dc.w $0000,$0080,$0000,$0000,$0000,$0000,$0000,$0000
    dc.w 0,0


frame2a:
    dc.w $0000,$0080
    dc.w $0000,$0000,$0000,$0007,$0000,$003f,$0001,$00ff
    dc.w $0000,$01ff,$0000,$03ff,$0000,$07ff,$0070,$0fff
    dc.w $0079,$1fff,$007c,$1fff,$0861,$3fff,$0883,$3fff
    dc.w $0e0f,$3fff,$101f,$7fff,$10ff,$7fff,$13fe,$7ffe
    dc.w $1ff8,$77f8,$1f41,$0f41,$1f0e,$0c0e,$04dd,$04dc
    dc.w $28f9,$00f8,$0581,$0400,$1b47,$0000,$0977,$0000
    dc.w $0dbe,$0000,$0780,$0000,$0200,$0000,$0000,$0000
    dc.w $0080,$0000,$0000,$0000,$0000,$0000,$0000,$0000
    dc.w 0,0

    
frame2b:

    dc.w $0000,$0000
    dc.w $0000,$0000,$e000,$e000,$fc00,$f800,$7400,$fb00
    dc.w $1000,$3f80,$0800,$0780,$0c00,$1380,$4600,$3980
    dc.w $0300,$fc00,$0700,$f800,$0f80,$f180,$1f80,$e3c0
    dc.w $3f80,$c7c0,$7f00,$8fc0,$fe00,$3f00,$f800,$7ec4
    dc.w $e000,$f986,$c000,$e706,$0000,$8f06,$0000,$9f04
    dc.w $0000,$fe04,$0000,$c004,$0000,$8000,$0000,$8000
    dc.w $0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000
    dc.w $0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000
    dc.w 0,0




frame2c:
    dc.w $0000,$0080
    dc.w $0000,$0000,$0000,$e000,$0000,$fc00,$0800,$fc00
    dc.w $4800,$f800,$1840,$f000,$3460,$f800,$3a70,$fc00
    dc.w $fdf0,$fe00,$f9e0,$f800,$f160,$f100,$e360,$e300
    dc.w $c640,$c600,$8cc0,$8c00,$3900,$3800,$76c4,$7000
    dc.w $d986,$c000,$a706,$8000,$8f06,$0000,$9f04,$0000
    dc.w $fe04,$0000,$c004,$0000,$8000,$0000,$8000,$0000
    dc.w $0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000
    dc.w $0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000
    dc.w 0,0


frame3:


    dc.w $0000,$0000
    dc.w $0000,$0000,$0007,$0007,$003e,$003c,$00f0,$00f8
    dc.w $00e0,$00e0,$0080,$0040,$0000,$00c0,$01c0,$01e0
    dc.w $03e0,$07f0,$07e8,$0ff1,$0fe8,$1ff3,$1fe8,$3ff7
    dc.w $3fd8,$3feb,$7fbc,$7ffd,$7ede,$7f7e,$793f,$7fff
    dc.w $347e,$7afe,$09f8,$7df8,$53e0,$6e70,$13c0,$3ee0
    dc.w $3b80,$0fc0,$3800,$3f00,$1800,$1c00,$1800,$1c00
    dc.w $0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000
    dc.w $0000,$0000,$0000,$0000,$0000,$0001,$0000,$0000
    dc.w 0,0


frame3a:
    dc.w $0000,$0080
    dc.w $0000,$0000,$0000,$0007,$0002,$003f,$0000,$00ff
    dc.w $0190,$017f,$0080,$03ff,$0020,$07ff,$0210,$0fff
    dc.w $0008,$1fff,$0008,$1ffe,$000c,$3ffc,$0000,$3ff8
    dc.w $0024,$3fe0,$0062,$7fe0,$0121,$7f00,$06c0,$7e00
    dc.w $4a81,$7800,$7cc7,$78c0,$6c5f,$6040,$3ebe,$3280
    dc.w $0478,$0000,$17e0,$1000,$1400,$1000,$0404,$0000
    dc.w $0c00,$0000,$0000,$0000,$0000,$0000,$0000,$0000
    dc.w $0000,$0000,$0000,$0000,$0001,$0000,$0000,$0000
    dc.w 0,0


frame3b:

    dc.w $0000,$0000
    dc.w $0000,$0000,$0000,$8000,$0000,$0400,$0000,$0f00
    dc.w $0000,$0f80,$0000,$1800,$0000,$3000,$0000,$4000
    dc.w $0000,$8018,$0000,$0878,$0000,$01e4,$0180,$c3cc
    dc.w $0200,$c79c,$0000,$ce7e,$0000,$b8fe,$6000,$7bfe
    dc.w $7000,$7ffe,$3400,$7ffe,$0800,$7ffe,$0000,$7ffc
    dc.w $0000,$1ffc,$0000,$0ff8,$0000,$07f0,$0000,$07c0
    dc.w $0000,$0380,$0000,$0100,$0000,$0000,$0000,$0700
    dc.w $0000,$1f00,$0000,$3c00,$0000,$e000,$0000,$0000
    dc.w 0,0

frame3c:    
    dc.w $0000,$0080
    dc.w $0000,$0000,$4000,$e000,$0000,$f800,$0000,$f000
    dc.w $0000,$f000,$07c0,$e000,$08e0,$c000,$33b0,$8000
    dc.w $4e18,$0000,$f478,$0000,$fde4,$0000,$3e4c,$0000
    dc.w $3d9c,$0000,$3e7e,$0000,$78fe,$0000,$9bfe,$0000
    dc.w $8ffe,$0000,$cbfe,$0000,$f7fe,$0000,$7ffc,$0000
    dc.w $1ffc,$0000,$0ff8,$0000,$07f0,$0000,$07c0,$0000
    dc.w $0380,$0000,$0100,$0000,$0000,$0000,$0700,$0000
    dc.w $1f00,$0000,$3c00,$0000,$e000,$0000,$0000,$0000
    dc.w 0,0

frame4:

    dc.w $0000,$0000
    dc.w $0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000
    dc.w $0000,$0007,$0000,$0001,$0000,$002c,$0010,$0180
    dc.w $0037,$021f,$007f,$0033,$2044,$2d7f,$00b1,$2e7b
    dc.w $2166,$07bd,$6398,$67f7,$6620,$737f,$7ec1,$67be
    dc.w $7f07,$63f8,$6e0f,$11f1,$443f,$37c7,$06ff,$051f
    dc.w $03ff,$067f,$01ff,$03ff,$00ff,$00ff,$007c,$007f
    dc.w $0010,$003e,$0000,$0018,$0000,$0000,$0000,$001c
    dc.w $0000,$003f,$0000,$003f,$0000,$0007,$0000,$0000
    dc.w 0,0



frame4a:
    dc.w $0000,$0080
    dc.w $0000,$0000,$0000,$0007,$0000,$003f,$0000,$00ff
    dc.w $0000,$01f8,$001e,$03e0,$0073,$0780,$00ff,$0e20
    dc.w $1168,$1cc0,$0652,$1992,$00fb,$3278,$019a,$3070
    dc.w $0099,$3881,$0067,$5807,$457f,$483f,$353e,$2c3e
    dc.w $7bf8,$63f8,$29f1,$01f1,$0fc7,$07c7,$391e,$011e
    dc.w $3478,$0078,$32f0,$00f0,$1f00,$0000,$1f83,$0000
    dc.w $0fee,$0000,$03f8,$0000,$0000,$0000,$001c,$0000
    dc.w $003f,$0000,$003f,$0000,$0007,$0000,$0000,$0000
    dc.w 0,0

frame4b:

    dc.w $0000,$0000
    dc.w $0000,$0000,$0000,$0000,$0000,$0400,$0100,$0e00
    dc.w $0080,$8f00,$0040,$df80,$1fe0,$e060,$e1c0,$9e40
    dc.w $f3e0,$ece0,$3fe0,$e1e0,$7fe0,$e1f0,$dfe0,$a3f0
    dc.w $3fe0,$c7f0,$7fc0,$8ff0,$ff80,$1ff0,$ff00,$7ff0
    dc.w $fe00,$fff0,$fc00,$fff0,$f800,$fff0,$f000,$ff8c
    dc.w $e000,$fc0c,$8000,$f00c,$0000,$c018,$0000,$8018
    dc.w $0000,$0030,$0000,$0020,$0000,$0040,$0000,$0080
    dc.w $0000,$0100,$0000,$fc00,$0000,$e000,$0000,$0000
    dc.w 0,0


frame4c:
    dc.w $0000,$0080
    dc.w $0000,$0000,$0000,$e000,$0000,$f800,$0100,$f000
    dc.w $0080,$7000,$0040,$2000,$1980,$0600,$5e70,$1e40
    dc.w $2cd0,$2cc0,$c190,$0180,$a190,$2180,$a310,$a300
    dc.w $c610,$c600,$8c30,$8c00,$1870,$1800,$70f0,$7000
    dc.w $e1f0,$e000,$c3f0,$c000,$07f0,$0000,$0f8c,$0000
    dc.w $1c0c,$0000,$700c,$0000,$c018,$0000,$8018,$0000
    dc.w $0030,$0000,$0020,$0000,$0040,$0000,$0080,$0000
    dc.w $0100,$0000,$fc00,$0000,$e000,$0000,$0000,$0000
    dc.w 0,0

frame5:

    dc.w $0000,$0000
    dc.w $0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000
    dc.w $0000,$0000,$0000,$0000,$003e,$067f,$01fe,$0dff
    dc.w $07fe,$13ff,$0dff,$1ffe,$17fd,$1ffe,$0ffd,$27fe
    dc.w $0ff1,$1ffe,$5fe1,$7ffe,$3f01,$7ffe,$3c03,$7ffc
    dc.w $7007,$7ff8,$000f,$7ff1,$003f,$7fc7,$00fc,$3f1c
    dc.w $0780,$3800,$3e00,$0400,$1c00,$1c00,$1800,$1800
    dc.w $0000,$0800,$0000,$0000,$0000,$0000,$0000,$0100
    dc.w $0000,$00c0,$0000,$0038,$0000,$0007,$0000,$0000
    dc.w 0,0


frame5a:
    dc.w $0000,$0080
    dc.w $0000,$0000,$0001,$0007,$0001,$003f,$0001,$00ff
    dc.w $0001,$01ff,$000f,$03ff,$0080,$01ff,$0200,$03ff
    dc.w $0e00,$01ff,$1f01,$0eff,$1c00,$17ff,$2002,$27ff
    dc.w $100e,$1fff,$601e,$7fff,$40ff,$3ffe,$43fd,$7ffc
    dc.w $0ff9,$7ff8,$7ff0,$7ff0,$7fc6,$7fc6,$3f23,$3f00
    dc.w $39ff,$3800,$07ff,$0400,$1bff,$1800,$07fe,$0000
    dc.w $0ff8,$0000,$07e0,$0000,$0000,$0000,$0100,$0000
    dc.w $00c0,$0000,$0038,$0000,$0007,$0000,$0000,$0000
    dc.w 0,0

frame5b:


    dc.w $0000,$0000
    dc.w $0000,$0000,$6000,$e000,$7800,$fc00,$7000,$ff00
    dc.w $7180,$ff80,$0180,$3ec0,$83c0,$3d60,$0070,$3c70
    dc.w $0000,$7c18,$8000,$7e00,$8000,$7e00,$8000,$7c00
    dc.w $8000,$7800,$8000,$7000,$8000,$6000,$0000,$0000
    dc.w $0000,$0000,$0000,$0000,$0000,$0000,$0000,$f800
    dc.w $6000,$fe00,$0000,$ff80,$0000,$ffe0,$0000,$ffe0
    dc.w $0000,$ffe0,$0000,$ffe0,$0000,$ffc0,$0000,$ff00
    dc.w $0000,$fc00,$0000,$e000,$0000,$0000,$0000,$0000
    dc.w 0,0



frame5c:

    dc.w $0000,$0080
    dc.w $0000,$0000,$0000,$e000,$4400,$bc00,$4f00,$bf00
    dc.w $4f80,$bf80,$dec0,$fe80,$8320,$c100,$8380,$c000
    dc.w $83f8,$8000,$0180,$8000,$81c0,$0000,$83e0,$0000
    dc.w $87e0,$0000,$8fe0,$0000,$9fc0,$0000,$ff80,$0000
    dc.w $ff00,$0000,$fe00,$0000,$fc00,$0000,$f800,$0000
    dc.w $9e00,$0000,$ff80,$0000,$ffe0,$0000,$ffe0,$0000
    dc.w $ffe0,$0000,$ffe0,$0000,$ffc0,$0000,$ff00,$0000
    dc.w $fc00,$0000,$e000,$0000,$0000,$0000,$0000,$0000
    dc.w 0,0

frame6:

    dc.w $0000,$0000
    dc.w $0000,$0000,$0007,$0007,$003f,$003f,$007f,$007f
    dc.w $00fe,$01ff,$01ff,$01ff,$0400,$003f,$0807,$0c08
    dc.w $1c00,$1808,$1000,$1808,$3800,$3004,$3800,$3002
    dc.w $2000,$3007,$6000,$700f,$6000,$70ff,$7000,$63ff
    dc.w $7000,$6fff,$1000,$6ffe,$1000,$6ff8,$0e00,$31e0
    dc.w $0fc0,$3040,$0ff0,$31f0,$07f8,$07fc,$07fc,$07ff
    dc.w $03f0,$03ff,$0380,$03ff,$0000,$01ff,$0000,$00ff
    dc.w $0000,$007f,$0000,$0000,$0000,$0000,$0000,$0000
    dc.w 0,0


frame6a:
    dc.w $0000,$0080
    dc.w $0000,$0000,$0000,$0007,$0020,$001f,$0080,$00ff
    dc.w $0081,$017f,$0200,$03ff,$07c3,$07ff,$0077,$0ff0
    dc.w $0477,$1ff0,$0074,$1ff0,$0862,$3ff8,$0801,$3ffc
    dc.w $0800,$3ff8,$0000,$7ff0,$0000,$7f00,$1000,$7c00
    dc.w $1000,$7000,$6001,$7000,$6007,$7000,$061f,$0800
    dc.w $08bf,$0000,$09cf,$01c0,$1f87,$0780,$1803,$0000
    dc.w $0c0f,$0000,$047f,$0000,$01ff,$0000,$00ff,$0000
    dc.w $007f,$0000,$0000,$0000,$0000,$0000,$0000,$0000
    dc.w 0,0

frame6b:

    dc.w $0000,$0000
    dc.w $0000,$0000,$e000,$e000,$f800,$fc00,$f000,$ff00
    dc.w $a080,$ff00,$64c0,$ef40,$d9e0,$2b60,$fcf0,$f6f0
    dc.w $0670,$1ff8,$0030,$21f8,$0020,$00f8,$0000,$00f8
    dc.w $0000,$80f8,$0000,$e038,$0000,$e018,$0000,$8000
    dc.w $0000,$0000,$0000,$0000,$0000,$0000,$0000,$0004
    dc.w $0000,$0034,$0000,$007c,$0000,$0078,$0000,$01f8
    dc.w $0000,$83f0,$0000,$e7e0,$0000,$e7c0,$0000,$c780
    dc.w $0000,$0300,$0000,$0000,$0000,$0000,$0000,$0000
    dc.w 0,0

 
frame6c:
    dc.w $0000,$0080
    dc.w $0000,$0000,$0000,$e000,$0400,$fc00,$0f00,$ff00
    dc.w $5f00,$1f00,$cf40,$c740,$2360,$2160,$1240,$1040
    dc.w $f988,$0000,$d1c8,$0000,$38d8,$0000,$8cf8,$0000
    dc.w $60f8,$0000,$1838,$0000,$1c18,$0000,$7e00,$0000
    dc.w $ff00,$0000,$fe00,$0000,$fc00,$0000,$f804,$0000
    dc.w $f034,$0000,$c07c,$0000,$8078,$0000,$01f8,$0000
    dc.w $83f0,$0000,$e7e0,$0000,$e7c0,$0000,$c780,$0000
    dc.w $0300,$0000,$0000,$0000,$0000,$0000,$0000,$0000
    dc.w 0,0

frame7:

    dc.w $0000,$0000
    dc.w $0000,$0000,$0006,$0006,$003f,$003f,$00ff,$00ff
    dc.w $01ff,$01ff,$035f,$03ff,$06af,$077f,$09ab,$0ff7
    dc.w $0719,$1be7,$0060,$02df,$0030,$056f,$0030,$102f
    dc.w $0018,$0807,$000c,$0413,$0007,$0309,$0001,$038f
    dc.w $0000,$0fc4,$0000,$7ff0,$0000,$7ff0,$0000,$3fe3
    dc.w $2006,$1f87,$200f,$1e0f,$100f,$101f,$1c0c,$1c1f
    dc.w $0e00,$0e3f,$0600,$077f,$0000,$03ff,$0000,$011f
    dc.w $0000,$0007,$0000,$0001,$0000,$0000,$0000,$0000
    dc.w 0,0

frame7a:
    dc.w $0000,$0080
    dc.w $0000,$0000,$0001,$0007,$0000,$003f,$0000,$00ff
    dc.w $0000,$01ff,$00e0,$027f,$0150,$071f,$0674,$0fe7
    dc.w $04e6,$00e7,$19df,$045f,$10ef,$222f,$03cf,$200f
    dc.w $05f7,$3007,$03eb,$7803,$00f7,$7c01,$0070,$7c00
    dc.w $003b,$7000,$000f,$0000,$000e,$0000,$001f,$0000
    dc.w $2079,$0000,$01f0,$0000,$1ff0,$1000,$0bf3,$0800
    dc.w $01ff,$0000,$01ff,$0000,$03ff,$0000,$011f,$0000
    dc.w $0007,$0000,$0001,$0000,$0000,$0000,$0000,$0000
    dc.w 0,0

frame7b:

    dc.w $0000,$0000
    dc.w $0000,$0000,$0000,$0000,$c000,$8400,$e000,$ef00
    dc.w $f080,$ff00,$e7c0,$fc40,$c2e0,$fde0,$8670,$f9f0
    dc.w $0c10,$f318,$1800,$e608,$3800,$c604,$7000,$fc00
    dc.w $e000,$7000,$c000,$e000,$8000,$e000,$8000,$c000
    dc.w $0000,$c000,$0000,$c000,$0000,$7000,$0000,$7800
    dc.w $0000,$fc00,$0000,$fe00,$0000,$ff00,$0000,$fe00
    dc.w $0000,$fc30,$0000,$fe20,$0000,$ffc0,$0000,$ff80
    dc.w $0000,$ff00,$0000,$fc00,$0000,$6000,$0000,$0000
    dc.w 0,0


frame7c:
    dc.w $0000,$0080
    dc.w $0000,$0000,$0000,$e000,$4000,$f800,$1000,$f000
    dc.w $0880,$f800,$1b40,$fc40,$3ee0,$fce0,$7a00,$fc00
    dc.w $f4e8,$f800,$e1f8,$f800,$d9f4,$c000,$c3f0,$c000
    dc.w $5fe0,$4000,$a3e0,$8000,$60c0,$0000,$4000,$0000
    dc.w $c000,$0000,$c000,$0000,$7000,$0000,$7800,$0000
    dc.w $fc00,$0000,$fe00,$0000,$ff00,$0000,$fe00,$0000
    dc.w $fc30,$0000,$fe20,$0000,$ffc0,$0000,$ff80,$0000
    dc.w $ff00,$0000,$fc00,$0000,$6000,$0000,$0000,$0000
    dc.w 0,0

frame8:

    dc.w $0000,$0000
    dc.w $0000,$0000,$0000,$0000,$0000,$0000,$00e0,$00c0
    dc.w $01e1,$01e3,$03e7,$03ff,$07f3,$07e7,$0fe0,$0fc1
    dc.w $0f40,$0f80,$1e80,$0f00,$3d00,$3e01,$3a00,$1c03
    dc.w $1400,$3d07,$1400,$3c8f,$0800,$187f,$1800,$281f
    dc.w $0000,$6807,$0000,$6980,$0400,$7dc0,$3700,$1fc0
    dc.w $1f80,$2f80,$1fc0,$27c0,$1fe0,$1ff0,$1f80,$1ff0
    dc.w $0f80,$0fe2,$0780,$07f1,$0000,$03fc,$0000,$01ff
    dc.w $0000,$00ff,$0000,$003f,$0000,$0007,$0000,$0000
    dc.w 0,0


frame8a:
    dc.w $0000,$0080
    dc.w $0000,$0000,$0000,$0007,$0020,$003f,$0021,$00ff
    dc.w $0015,$01fe,$0000,$03ff,$0018,$07ff,$0032,$0fff
    dc.w $0079,$0fff,$00f0,$0fff,$0160,$1ffe,$0600,$1ffc
    dc.w $2e00,$3cf8,$6900,$3870,$7c80,$3800,$4720,$1000
    dc.w $1f98,$0000,$1e67,$0000,$1a31,$0000,$2a30,$0200
    dc.w $0370,$0300,$04b0,$0480,$1c10,$1c00,$0c70,$0c00
    dc.w $0062,$0000,$0071,$0000,$03fc,$0000,$01ff,$0000
    dc.w $00ff,$0000,$003f,$0000,$0007,$0000,$0000,$0000
    dc.w 0,0


frame8b:

    dc.w $0000,$0000
    dc.w $0000,$0000,$0000,$0000,$0000,$0400,$7000,$ff00
    dc.w $f000,$ff80,$e080,$ff00,$c0c0,$ff40,$81c0,$fe40
    dc.w $83e0,$7ce0,$67e0,$99e0,$0fe0,$f5f0,$03e0,$fff0
    dc.w $0000,$f870,$0000,$f00e,$0000,$e00e,$0000,$800e
    dc.w $0000,$000e,$0000,$0006,$0000,$000e,$0000,$000c
    dc.w $0000,$000c,$0000,$0008,$0000,$0000,$0000,$0010
    dc.w $0000,$0030,$0000,$f000,$0000,$f180,$0000,$e000
    dc.w $0000,$fe00,$0000,$fc00,$0000,$e000,$0000,$0000
    dc.w 0,0

frame8c:
    dc.w $0000,$0080
    dc.w $0000,$0000,$0000,$e000,$0000,$f800,$4e00,$be00
    dc.w $0f00,$ff00,$1f40,$ff00,$3f60,$ff40,$7e70,$fe40
    dc.w $7cd0,$fcc0,$5990,$3980,$0d90,$0580,$0010,$0000
    dc.w $07f0,$0000,$0fee,$0000,$1fce,$0000,$7f8e,$0000
    dc.w $ff0e,$0000,$fe06,$0000,$fc0e,$0000,$000c,$0000
    dc.w $000c,$0000,$0008,$0000,$0000,$0000,$0010,$0000
    dc.w $0030,$0000,$f000,$0000,$f180,$0000,$e000,$0000
    dc.w $fe00,$0000,$fc00,$0000,$e000,$0000,$0000,$0000
    dc.w 0,0

	
FONT:
	incdir  "dh1:own/demo/repository/resources/fonts/"
	incbin  "16X16-F2_944_16_2.blt.raw"
	
*****************************************************************************

	SECTION	Screen,BSS_C	

OFFSET_TAB:
	ds.w	256
	
SCREEN:
	ds.b	ScrBpl*h*bpls		; 2 bitplane

BUFFER:
	ds.b	ScrBpl*bpls*FONT_HEIGHT

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
