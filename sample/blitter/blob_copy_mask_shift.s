*****************************************************************************
*
*    This is a sample that show how to perform a blob shift by 0-15 pixels
*
*    For each blit a PICTURE binary rapresentation show
*    how picture data is processed before blitting
*    The blitter operation order is:
*    module, masking, shifting
*    
*
*****************************************************************************

	SECTION Code,CODE


*****************************************************************************
	incdir	"dh1:own/demo/repository/startup/borchen/"
	include	"startup.s"	; 
	incdir	"dh1:own/demo/blitter/"	
	include "hardware/custom.i"
*****************************************************************************

		;5432109876543210
DMASET	EQU	%1000001111000000	; copper,bitplane,blitter DMA



;;    ---  screen buffer dimensions  ---

w	=320
h	=256
bplsize	=w*h/8
ScrBpl	=w/8

bpls = 2

ImageWidth	= 16	; pixel
ImageHeight	= 4	; pixel

blitw	=ImageWidth/16			;sprite width in words
blith	=ImageHeight			;sprite height in lines


BLTWAIT	MACRO
	tst DMACONR(a6)			;for compatibility
\1
	btst #6,DMACONR(a6)
	bne.s \1
	ENDM

LMOUSE	MACRO
\1
	btst	#6,$bfe001	; check L MOUSE btn
	bne.s	\1
	ENDM

RMOUSE	MACRO
\1
	btst	#2,$dff016	; check L MOUSE btn
	bne.s	\1
	ENDM
	
START:
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

	lea	$dff000,a5		; CUSTOM REGISTER in a5
	MOVE.W	#DMASET,$96(a5)		; DMACON - enable bitplane, copper
	move.l	#COPPERLIST,$80(a5)	; Point to COP
	move.w	d0,$88(a5)		; STROBE COP
	move.w	#0,$1fc(a5)		; AGA FMODE - OCS compatible
	move.w	#$c00,$106(a5)		; AGA BPLCON3 - OCS compatible
	move.w	#$11,$10c(a5)		

	bsr.s	blit

	LMOUSE	MOUSE1

	rts		; exit

blit:
	lea	SCREEN,a1

	addi.w	#(128-ImageHeight)*40*bpls,a1

	BLTWAIT BWT1
	
	lea $dff000,a6
	move.w	#$09f0,BLTCON0(a6)	;A->D copy
	move.w	#$0000,BLTCON1(a6)	
	move.w	#$ffff,BLTAFWM(a6)	;
	move.w  #$ffff,BLTALWM(a6)	;	
	
	; rectangle 1	(original)
	
	move.w	#0,BLTAMOD(a6)	;A modulo=bytes to skip between lines
	move.w	#w/8-blitw*2,BLTDMOD(a6)	;D modulo=bytes to skip between lines
	move.l	#PICTURE,BLTAPT(a6)	;source graphic top left corner
	move.l	a1,BLTDPT(a6)	;destination top left corner
	move.w	#(bpls*blith*64)+blitw,BLTSIZE(a6)	;rectangle size, starts blit

	BLTWAIT	BWT2
	
	addi	#40*bpls*(ImageHeight+1)+2,a1

	; rectangle 2	(original 16 pixel forward)

	move.w	#$09f0,BLTCON0(a6)	;A->D copy
	move.w	#$0000,BLTCON1(a6)	
	move.w	#$ffff,BLTAFWM(a6)	;
	move.w  #$ffff,BLTALWM(a6)	;
	
	
	move.w	#$0000,BLTAMOD(a6)	;A modulo=bytes to skip between lines
	move.w	#w/8-blitw*2,BLTDMOD(a6)	;D modulo=bytes to skip between lines
	move.l	#PICTURE,BLTAPT(a6)	;source graphic top left corner
	move.l	a1,BLTDPT(a6)	;destination top left corner
	move.w	#(bpls*blith*64)+blitw, BLTSIZE(a6)	;rectangle size, starts blit

	
	BLTWAIT BWT3

	addi	#40*bpls*(ImageHeight+1)-2,a1

	; rectangle 3	(BLTAMOD -2 BLTSIZE + 1)

	move.w	#$09f0,BLTCON0(a6)	;A->D copy
	move.w	#$0000,BLTCON1(a6)	
	move.w	#$ffff,BLTAFWM(a6)	;
	move.w  #$ffff,BLTALWM(a6)	;
	
	
	move.w	#$fffe,BLTAMOD(a6)	;A modulo=bytes to skip between lines
	move.w	#w/8-(blitw*2+2),BLTDMOD(a6)	;D modulo=bytes to skip between lines
	move.l	#PICTURE,BLTAPT(a6)	;source graphic top left corner
	move.l	a1,BLTDPT(a6)	;destination top left corner
	move.w	#(bpls*blith*64)+blitw+1, BLTSIZE(a6)	;rectangle size, starts blit
    
	BLTWAIT	BWT4

	addi	#40*bpls*(ImageHeight+1),a1

	; rectangle 4	
	; (binary representation of rectangle 3)

	move.w	#$09f0,BLTCON0(a6)	;A->D copy
	move.w	#$0000,BLTCON1(a6)	
	move.w	#$ffff,BLTAFWM(a6)	;
	move.w  #$ffff,BLTALWM(a6)	;	
	
	move.w	#$0,BLTAMOD(a6)	;A modulo=bytes to skip between lines
	move.w	#w/8-(blitw*2+2),BLTDMOD(a6)	;D modulo=bytes to skip between lines
	move.l	#PICTURE_MOD_2_BTLSIZE_x2,BLTAPT(a6)	;source graphic top left corner
	move.l	a1,BLTDPT(a6)	;destination top left corner
	move.w	#(bpls*blith*64)+blitw+1, BLTSIZE(a6)	;rectangle size, starts blit

	BLTWAIT	BWT5
	
	addi	#40*bpls*(ImageHeight+1),a1
	
	; rectangle 5	
	; (BLTAMOD -2 BLTSIZE + 1) + last word masking

	move.w	#$09f0,BLTCON0(a6)	;A->D copy
	move.w	#$0000,BLTCON1(a6)	
	move.w	#$ffff,BLTAFWM(a6)	;
	move.w  #$0000,BLTALWM(a6)	;	
	
	move.w	#$fffe,BLTAMOD(a6)	;A modulo=bytes to skip between lines
	move.w	#w/8-(blitw*2+2),BLTDMOD(a6)	;D modulo=bytes to skip between lines
	move.l	#PICTURE,BLTAPT(a6)	;source graphic top left corner
	move.l	a1,BLTDPT(a6)	;destination top left corner
	move.w	#(bpls*blith*64)+blitw+1, BLTSIZE(a6)	;rectangle size, starts blit
	
	BLTWAIT	BWT6
	
	addi.w	#40*bpls*(ImageHeight+1),a1
	
	; rectangle 6
	; (binary representation of rectangle 5)

	move.w	#$09f0,BLTCON0(a6)	;A->D copy, ascending mode, 8 pixel shifts
	move.w	#$0000,BLTCON1(a6)	
	move.w	#$ffff,BLTAFWM(a6)	;
	move.w  #$ffff,BLTALWM(a6)	; clear last word masking
	
	
	move.w	#0,BLTAMOD(a6)	;A modulo = 2 bytes backward
	move.w	#w/8-(blitw*2+2),BLTDMOD(a6)	;D modulo=bytes to skip between lines
	move.l	#PICTURE_MOD_2_BTLSIZE_x2_MASKED,BLTAPT(a6)	;source graphic top left corner
	move.l	a1,BLTDPT(a6)	;destination top left corner
	move.w	#(bpls*blith*64)+blitw+1,BLTSIZE(a6)	;rectangle size, starts blit
    
	
	BLTWAIT	BWT7

	addi.w	#40*bpls*(ImageHeight+1),a1
	
	; rectangle 7
	; (BLTAMOD -2 BLTSIZE + 1) + last word masking + 8 bit shift

	move.w	#$89f0,BLTCON0(a6)	;A->D copy, ascending mode, 8 pixel shifts
	move.w	#$0000,BLTCON1(a6)	
	move.w	#$ffff,BLTAFWM(a6)	;
	move.w  #$0000,BLTALWM(a6)	; clear last word masking
	
	
	move.w	#$fffe,BLTAMOD(a6)	;A modulo = 2 bytes backward
	move.w	#w/8-(blitw*2+2),BLTDMOD(a6)	;D modulo=bytes to skip between lines
	move.l	#PICTURE,BLTAPT(a6)	;source graphic top left corner
	move.l	a1,BLTDPT(a6)	;destination top left corner
	move.w	#(bpls*blith*64)+blitw+1,BLTSIZE(a6)	;rectangle size, starts blit
	
	BLTWAIT	BWT8
	
	addi.w	#40*bpls*(ImageHeight+1),a1
	
	; rectangle 8
	; (binary representation of rectangle 7)

	move.w	#$09f0,BLTCON0(a6)	;A->D copy, ascending mode, 8 pixel shifts
	move.w	#$0000,BLTCON1(a6)	
	move.w	#$ffff,BLTAFWM(a6)	;
	move.w  #$ffff,BLTALWM(a6)	; clear last word masking
	
	
	move.w	#0,BLTAMOD(a6)	;A modulo = 2 bytes backward
	move.w	#w/8-(blitw*2+2),BLTDMOD(a6)	;D modulo=bytes to skip between lines
	move.l	#PICTURE_MOD_2_BTLSIZE_x2_MASKED_SHIFTED,BLTAPT(a6)	;source graphic top left corner
	move.l	a1,BLTDPT(a6)	;destination top left corner
	move.w	#(bpls*blith*64)+blitw+1,BLTSIZE(a6)	;rectangle size, starts blit
	
	BLTWAIT	BWT9
	
	rts	


	
;*****************************************************************************

	SECTION	GRAPHIC,DATA_C

COPPERLIST:
	dc.w	$8E,$2c81	; DiwStrt
	dc.w	$90,$2cc1	; DiwStop
	dc.w	$92,$38		; DdfStart
	dc.w	$94,$d0		; DdfStop
	dc.w	$102,0		; BplCon1
	dc.w	$104,0		; BplCon2
	dc.w	$108,ScrBpl*(bpls-1)	; Bpl1Mod  INTERLEAVED MODE!
	dc.w	$10a,ScrBpl*(bpls-1)	; Bpl2Mod  INTERLEAVED MODE!

	dc.w	$100,bpls*$1000+$200	; bplcon0 - bitplane lowres

BPLPOINTERS:
	dc.w $e0,$0000,$e2,$0000	;first bitplane
	dc.w $e4,$0000,$e6,$0000	;second bitplane
	


	dc.w $0180,$0000	; color0
	dc.w $0182,$0eca	; color1
	dc.w $0184,$055f	; color2
	dc.w $0186,$0f80	; color3
	dc.w $0188,$0fff	; color4
	dc.w $018a,$0aaa	; color5
	
	
;	dc.w	$ab07,$fffe
;	dc.w	$0180,$e00
;	dc.w	$ab89,$fffe
;	dc.w	$0180,$0e0
;	dc.w	$ac07,$fffe
;	dc.w	$0180,$000

	dc.w	$FFFF,$FFFE	; End of copperlist

*****************************************************************************

	SECTION	Data,DATA_C

PICTURE:
	dc.w	%1111111111111111	; BITPLANE 0
	dc.w	%1111111100000000	; BITPLANE 1
	dc.w	%1111111111111111	; BITPLANE 0
	dc.w	%1111111100000000	; BITPLANE 1
	dc.w	%0000000000000000	; BITPLANE 0
	dc.w	%1111111100000000	; BITPLANE 1
	dc.w	%0000000000000000	; BITPLANE 0
	dc.w	%1111111100000000	; BITPLANE 1

PICTURE_MOD_2_BTLSIZE_x2:
	dc.w	%1111111111111111,%1111111100000000	; BITPLANE 0
	dc.w	%1111111100000000,%1111111111111111	; BITPLANE 1
	dc.w	%1111111111111111,%1111111100000000	; BITPLANE 0
	dc.w	%1111111100000000,%0000000000000000	; BITPLANE 1
	dc.w	%0000000000000000,%1111111100000000	; BITPLANE 0
	dc.w	%1111111100000000,%0000000000000000	; BITPLANE 1
	dc.w	%0000000000000000,%1111111100000000	; BITPLANE 0
	dc.w	%1111111100000000,%1111111111111111	; BITPLANE 1
	
PICTURE_MOD_2_BTLSIZE_x2_MASKED:
	dc.w	%1111111111111111,%0000000000000000	; BITPLANE 0
	dc.w	%1111111100000000,%0000000000000000	; BITPLANE 1
	dc.w	%1111111111111111,%0000000000000000	; BITPLANE 0
	dc.w	%1111111100000000,%0000000000000000	; BITPLANE 1
	dc.w	%0000000000000000,%0000000000000000	; BITPLANE 0
	dc.w	%1111111100000000,%0000000000000000	; BITPLANE 1
	dc.w	%0000000000000000,%0000000000000000	; BITPLANE 0
	dc.w	%1111111100000000,%0000000000000000	; BITPLANE 1
	
PICTURE_MOD_2_BTLSIZE_x2_MASKED_SHIFTED:
	dc.w	%0000000011111111,%1111111100000000	; BITPLANE 0
	dc.w	%0000000011111111,%0000000000000000	; BITPLANE 1
	dc.w	%0000000011111111,%1111111100000000	; BITPLANE 0
	dc.w	%0000000011111111,%0000000000000000	; BITPLANE 1
	dc.w	%0000000000000000,%0000000000000000	; BITPLANE 0
	dc.w	%0000000011111111,%0000000000000000	; BITPLANE 1
	dc.w	%0000000000000000,%0000000000000000	; BITPLANE 0
	dc.w	%0000000011111111,%0000000000000000	; BITPLANE 1
	
	
*****************************************************************************

	SECTION	Screen,BSS_C	

SCREEN:
	ds.b	40*256*bpls		; 2 bitplane

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
