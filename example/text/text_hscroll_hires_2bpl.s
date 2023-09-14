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
	incdir	"dh1:amiga-playground"
	include	"/startup/borchen/startup.s"	; 
	include "/shared/hardware/custom.i"
*****************************************************************************


;;    ---  SCREEN_H buffer dimensions  ---

w	=640+320
h	=256
ScrBpl	=w/8	


bpls = 2

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
 	and.l   #$0001ff00,d0   ; for
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
    	move.l  #SCREEN-2,d0  ; point to bitplane
    	lea BPLPOINTERS,a1  ; 
   	moveq   #bpls-1,d1  ; 2 BITPLANE
POINTBP:
    	move.w  d0,6(a1)    ; copy low word of pic address to plane
    	swap    d0          ; swap the the two words
   	move.w  d0,2(a1)    ; copy the high word of pic address to plane
    	swap    d0          ; swap the the two words

	add.l   #ScrBpl*h,d0      
			
	addq.w  #8,a1
                	
	dbra    d1,POINTBP
	
	move.w  #DMASET,$dff096     ; enable necessary bits in DMACON
	move.w  #INTENASET,$dff09a     ; INTENA
    
	move.l  #COPPERLIST,$dff080 ; COP1LCH set custom copperlist
   	move.w  #0,$dff088      ; COPJMP1 activate copperlist
	
	bsr.s	draw_chessboard
	
	lea	TEXT(pc),a0	; let a0 point to text to print
	lea	SCREEN+(ScrBpl*h),a3	; let a3 point to BITPLANE
	
	bsr.w	print_text
		
	lea	$dff000,a5

Main:
	WAITVB  Main
	
	bsr.s	scroll_text
	
Wait    WAITVB2 Wait

WaitRm:
	RMOUSE WaitRm
	
	LMOUSE Main

	rts		; exit


***********************************
*
*	draw chessboard routine
*	
*	
***********************************
draw_chessboard:

	moveq	#(h/16)-1, d6
	lea	SCREEN, a0

draw_cb_loop_2_lines:
	move.w	#((ScrBpl/4)*(8))-1, d7	; (w/32px)*h/2
draw_cb_loop:
	
	move.l	#%11111111000000001111111100000000, (a0)+
	
	dbra	d7, draw_cb_loop

	move.w	#((ScrBpl/4)*((8)))-1, d7	; (w/32px)*h/2
draw_cb_loop_alt:
	
	move.l	#%00000000111111110000000011111111, (a0)+
	
	dbra	d7, draw_cb_loop_alt

	dbra	d6, draw_cb_loop_2_lines

	rts
	
LINE_COUNT = 2

scroll_text:
	lea	BPLPOINTERS, a1	
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

	moveq	#2-1, d7
bpl_loop:	
	move.w	2(a1),d0 	; copy low word of pic address to plane
	swap	d0		 	; swap the two words
	move.w	6(a1),d0 	; copy high word of pic address to plane

	add.l	d1,d0		; point 16px forward

	move.w	d0,6(a1)	; copy low word of pic address to plane
	swap	d0			; swap the two words; 
	move.w	d0,2(a1)	; copy high word of pic address to plane 

	addi.l	#8, a1

	dbra	d7, bpl_loop

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
	
;	This routine print char of font 8x8 on 640x256 screen
	
*******************************
*
*	print text
*	<INPUT>
*	A0:	TEXT
*	A3:	BITPLANE
*
*******************************
print_text:	
	moveq	#LINE_COUNT-1,d3	; line count to print
print_row:
	moveq	#120-1,d0	; number of columns for line
print_char:
	moveq	#0,d2		; clean d2
	move.b	(a0)+,d2	; let d2 point to next character
	sub.b	#$20,d2		; subtract 32 ASCII chars to d2
	lsl	#3,d2		; font height eq 8, chars are disposed vertically
	move.l	d2,a2		; 8px * d2 find the char to print
	add.l	#FONT,a2	; put on a2 the character to print

	move.b	(a2)+,(a3)	; print line 1 font on BITPLANE
	move.b	(a2)+,120(a3)	; print line 2 font on BITPLANE
	move.b	(a2)+,120*2(a3)	; print line 3 font on BITPLANE
	move.b	(a2)+,120*3(a3)	; print line 4 font on BITPLANE
	move.b	(a2)+,120*4(a3)	; print line 5 font on BITPLANE
	move.b	(a2)+,120*5(a3)	; print line 6 font on BITPLANE
	move.b	(a2)+,120*6(a3)	; print line 7 font on BITPLANE
	move.b	(a2)+,120*7(a3)	; print line 8 font on BITPLANE

	addq.w	#1,a3		; move on next char (8bit)

	dbra	d0,print_char	; print 40 chars each line

	add.w	#120*7,a3	; go to next row
				; 
	dbra	d3,print_row	; cycle x LINE_COUNT

	rts


TEXT:		
	;tens	 0        1         2         3         4
	;units	 1234567890123456789012345678901234567890
	dc.b	'This is the first row ... a very long   ' ; 1a
	dc.b	'line this time, in HIRES!!              ' ; 1b
	dc.b	'Still not ended the first row  .wait EOF' ; 1a
	dc.b	'SECOND LINE!!!                          ' ; 2a
	dc.b	'..and this is the 2/3 of the second line' ; 2b
	dc.b	'                     ...here we are..EOF' ; 2c
		
	EVEN	

	
*****************************************************************************

	SECTION	GRAPHIC,DATA_C

COPPERLIST:
	dc.w	$120,$0000,$122,$0000,$124,$0000,$126,$0000,$128,$0000	; clear sprite pointers
	dc.w	$12a,$0000,$12c,$0000,$12e,$0000,$130,$0000,$132,$0000  ; clear sprite pointers
	dc.w	$134,$0000,$136,$0000,$138,$0000,$13a,$0000,$13c,$0000  ; clear sprite pointers
	dc.w	$13e,$0000

	dc.w	$8e,$2c81	; DiwStrt
	dc.w	$90,$2cc1	; DiwStop
	dc.w	$92,$3c-4	; DdfStart
	dc.w	$94,$d4		; DdfStop
       	        
	dc.w	$102		; BplCon1 reg address
	dc.b	0		; BplCon1 high byte value (unused)
OWNBPLCON1:
	dc.b	0		; BplCon1 low byte value (used)
	dc.w	$104,0		; BplCon2
	dc.w	$108,40-4	; Bpl1Mod (40 for large pic)
	dc.w	$10a,40-4	; Bpl2Mod -4 fits the DdfStart value

	dc.w	$100,bpls*$1000+$8200	; bplcon0 - bitplane hires



BPLPOINTERS:
	dc.w	$e0,$0000,$e2,$0000	; BPL0PT
	dc.w	$e4,$0000,$e6,$0000	; BPL1PT

	dc.w	$180,$004	; color background
	dc.w	$182,$00f	; color text
	dc.w	$184,$ee0	; color text
	dc.w	$186,$ee0	; color text

	dc.w	$FFFF,$FFFE	; End of copperlist

*****************************************************************************

	SECTION	Data,DATA_C


FONT:
	incbin	"/resources/fonts/nice-8x8.fnt"
	
*****************************************************************************

	SECTION	SCREEN, BSS_C	

SCREEN:
	ds.b	ScrBpl*h*bpls

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
