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
h_H 	= 16
ScrHBpl	=w_H/8	

w_L	=320
h_L	=256-h_H
ScrLBpl	=w_L/8	


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
   	moveq   #bpls-1,d1  ; 2 BITPLANE
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
   	moveq   #bpls-1,d1  ; 2 BITPLANE
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
		
	lea	$dff000,a5


Main:
	WAITVB  Main

	

	
Wait    WAITVB2 Wait

WaitRm:
	RMOUSE2 continue
	bsr.w	scroll_text
continue:	
	LMOUSE Main

	rts		; exit

	
draw_chessboard:

	lea	SCREEN_H, a0
	move.w	#((ScrHBpl/4)*(h_H/2))-1, d7	; (w/32px)*h/2
draw_cb_loop:
	
	move.l	#%11111111000000001111111100000000, (a0)+
	
	dbra	d7, draw_cb_loop

	move.w	#((ScrHBpl/4)*((h_H/2)))-1, d7	; (w/32px)*h/2
draw_cb_loop_alt:
	
	move.l	#%00000000111111110000000011111111, (a0)+
	
	dbra	d7, draw_cb_loop_alt

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

	dc.w	$100,bpls*$1000+$8200	; bplcon0 - bitplane hires

BPLPOINTERS_H:
	dc.w	$e0,$0000,$e2,$0000	;first bitplane
	dc.w	$e4,$0000,$e6,$0000	;second bitplane
	
	dc.w	$0180,$000f	; color0
	dc.w	$0182,$0027	; color1
	dc.w	$0184,$0ff0	; color2
	dc.w	$0186,$0ff0	; color3
	
	dc.w	$3b07,$fffe	; Here start lowres

*********** LORES **************	
	
	dc.w	$0180,$0f00
	dc.w	$3c07,$fffe	
	
	dc.w	$92,$0038	; DdfStart
	dc.w	$94,$00d0	; DdfStop
	dc.w	$102,0	; BplCon1
	dc.w	$108,0	; Bpl1Mod
	dc.w	$10a,0	; Bpl2Mod
	
	dc.w	$100,bpls*$1000+$200	; bplcon0 - bitplane lores
	
BPLPOINTERS_L:
	dc.w	$e0,$0000,$e2,$0000	;first bitplane
	dc.w	$e4,$0000,$e6,$0000	;second bitplane
	
	
	dc.w	$0180,$0000	; color0
	dc.w	$0182,$00af	; color1
	dc.w	$0184,$0000	; color2
	dc.w	$0186,$0000	; color3
	
	dc.w	$FFFF,$FFFE	; End of copperlist

*****************************************************************************

	SECTION	Data,DATA_C


FONT:
	incdir	"dh1:own/demo/repository/resources/fonts/"
	incbin	"nice-8x8.fnt"
	
*****************************************************************************

	SECTION	SCREEN, BSS_C	

SCREEN_H:
	ds.b	ScrHBpl*h_H*bpls		
SCREEN_L:
	ds.b	ScrLBpl*h_L*bpls

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
