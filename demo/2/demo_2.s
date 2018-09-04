*****************************************************************************
*									    *
*    									    *
*									    *
*    				 					    *
*    									    *
*    									    *
*    									    *
*    									    *
*									    *
*****************************************************************************

	SECTION Code,CODE


DMASET  = %1000001111110000
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
	incdir	"dh1:own/demo/repository/demo/2/"	
	include "hardware/custom.i"
*****************************************************************************


;;    ---  screen buffer dimensions  ---

w	=320
h	=256
bplsize	=w*h/8
ScrBpl	=w/8+4	; standard screen width + 4 bytes
		; where we'll place the char data

bpls = 3

;wbl = $2c (for copper monitor only)
wbl = 303

SCREEN_VOFFSET = 180*ScrBpl


WAITVB MACRO
   	move.l  $dff004,d0      ; wait
 	and.l   #$0001ff00,d0       ; for
   	cmp.l   #wbl<<8,d0      ; rasterline 303
	bne.s   \1
	ENDM

WAITVB2 MACRO
	move.l  $dff004,d0      ; wait
 	and.l   #$0001ff00,d0   ; for
	cmp.l   #wbl<<8,d0      ; rasterline 303
	beq.s   \1
	ENDM

BLTWAIT	MACRO
	tst $dff002			;for compatibility
\1
	btst #6,$dff002
	bne.s \1
	ENDM

LMOUSE	MACRO
	btst	#6,$bfe001	; check L MOUSE btn
	bne.s	\1
	ENDM

RMOUSE	MACRO
\1
	btst	#2,$dff016	; check L MOUSE btn
	bne.s	\1
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

	add.l   #ScrBpl*h,d0      ; BITPLANE point to next byte line data
                        ; instead of the standard raw
                        ; where bitplane is immediately
                        ; after the previous bitplane
                        ; standard raw (40*256)
                        ; blitter raw (40)
			; notice the +2 bytes where to place char data
			
	addq.w  #8,a1   ; the next bpl starts one row
                	; after the previous one	
	dbra    d1,POINTBP
    
    

	move.w  #DMASET,$dff096     ; enable necessary bits in DMACON
	move.w  #INTENASET,$dff09a     ; INTENA
    
	move.l  #COPPERLIST,$dff080 ; COP1LCH set custom copperlist
   	move.w  #0,$dff088      ; COPJMP1 activate copperlist

	lea	$dff000,a5
	
	bsr.s	display_logo
	
Main:
	WAITVB  Main
	
	bsr.s	print_char
	bsr.w	scroll_text

Wait    WAITVB2 Wait
	
	LMOUSE Main

	rts		; exit

	
*****************************************************************************
* Display logo
* 
* 
*
*****************************************************************************

LOGO_WIDTH = 128
LOGO_HEIGHT = 80


display_logo:
	
	
	moveq	#bpls-1, d7
	
	lea	LOGO, a0
	lea	SCREEN, a1
	
blit_logo:

	BLTWAIT BWT4

	move.w	#$09f0,BLTCON0(a5)	; BLTCON0 copy from A to D ($F) 
	move.w	#$0000,BLTCON1(a5)	; BLTCON1					
	move.l	#$ffffffff,BLTAFWM(a5)	; BLTAFWM / BLTALWM
	move.l	a0,BLTAPT(a5)	; BLTAPT - source
	move.l	a1,BLTDPT(a5)	; BLTDPT - dest

	move.l	#$0000001C,BLTAMOD(a5)	; BLTAMOD + BLTDMOD 
	move.w	#(LOGO_HEIGHT*64)+LOGO_WIDTH/16,BLTSIZE(a5)	; BLTSIZE
	
	lea	LOGO_HEIGHT*LOGO_WIDTH/8(a0),a0	
	lea	ScrBpl*h(a1),a1
	
	dbra	d7, blit_logo
	
	rts
	

*****************************************************************************
* Print char over the right screen margin
* 
* 
*
*****************************************************************************

FONTSET_WIDTH   = 320   ; pixel
FONTSET_HEIGHT  = 192    ; pixel

FONT_WIDTH  = 32 ; pixel
FONT_HEIGHT = 32 ; pixel

SCROLL_COUNT = 32	; (FONT_WIDTH / pixel shift)
counter:	dc.w	SCROLL_COUNT	;

	
print_char:
	subq.w	#1,counter	; decrease counter 
	bne.s	no_print	; if counter != 0 do nothing
	move.w	#SCROLL_COUNT,counter	; if counter = 0 reset counter

	moveq	#0,d2		; clear D2
	move.b	(a0)+,d2	; go next char 
	bne.s	noreset		; if D2 != 0 print char
	lea	TEXT(PC),a0	; if D2 == 0 restart TEXT
	move.b	(a0)+,d2	; go next char 
	
noreset:		
	subi.b	#$20,d2		; retrieve font position
	lsl.w	#2,d2		; in charset by multipling
				; 4 bytes (font is 32 pixel)
				
	lea	FONT_ADDRESS_LIST(PC),a2
	move.l	0(a2,d2.w),a2		
	
	;BLTWAIT BWT1
	
	moveq	#-1,d1
	move.l	d1,BLTAFWM(a5)	 	; BLTALWM, BLTAFWM
	move.l	#$09F00000,BLTCON0(a5)	; BLTCON0/1 - copia normale
	move.l	#$00240028,BLTAMOD(a5)	; BLTAMOD = 36, BLTDMOD = 40
					; 320/8-4, 44-4
	lea	SCREEN+SCREEN_VOFFSET+40,a1	; Destination

	moveq	#bpls-1,d7		; bitplanes
CopyCharL:

	BLTWAIT BWT2

	move.l	a2,BLTAPT(a5)		; BLTAPT (fontset)
	move.l	a1,BLTDPT(a5)		; BLTDPT (bitplane)
	move.w	#FONT_HEIGHT*64+(FONT_WIDTH/16),BLTSIZE(a5)	; BLTSIZE
	
	;addi.w	#ScrBpl*h,a1
	lea	ScrBpl*h(a1),a1
	;addi.w	#44*32,a1			; NEXT BITPLANE SCREEN
	lea	40*FONTSET_HEIGHT(a2),a2	; NEXT BITPLANE FONTSET

	dbra	d7,copycharL

no_print:
	rts

*****************************************************************************
*	
*	Scroll text routine
* 
*	Use BLITTER in DESC mode
*	basically copies the whole screen with
*	full screen width * FONT HEIGHT
*	and shift it by x pixels
*
*****************************************************************************

scroll_text:

; source and dest are the same (point to SCREEN)
; we shift by left so we use DESC mode 
; therefore blitter starts copying
; from right word and ends to left word

	move.l	#SCREEN+SCREEN_VOFFSET+(FONT_HEIGHT*ScrBpl)-6,d0 ; source and dest address

	moveq	#bpls-1,d7

scroll_loop:

	BLTWAIT BWT3

	move.w	#$19f0,BLTCON0(a5)	; BLTCON0 copy from A to D ($F) 
					; 1 pixel shift, LF = F0
	move.w	#$0002,BLTCON1(a5)	; BLTCON1 use blitter DESC mode
					

	move.l	#$ffffffff,BLTAFWM(a5)	; BLTAFWM / BLTALWM
					; BLTAFWM = $ffff - 
					; BLTALWM = $ffff 


	move.l	d0,BLTAPT(a5)			; BLTAPT - source
	move.l	d0,BLTDPT(a5)			; BLTDPT - dest

	; scroll an image of the full screen width * FONT_HEIGHT

	move.l	#$00000000,BLTAMOD(a5)	; BLTAMOD + BLTDMOD 
	move.w	#(FONT_HEIGHT*64)+22,BLTSIZE(a5)	; BLTSIZE

	add.w	#ScrBpl*h,d0

	dbra	d7, scroll_loop

	rts					
	
	
TEXT:
	dc.b	"THIS IS A SCROLLING TEXT EXAMPLE..."
	dc.b	"HOPE YOU LIKE IT !!!    "
	EVEN

	

FONT_ADDRESS_LIST:
	dc.l FONT	
	dc.l FONT+4	
	dc.l FONT+8
	dc.l FONT+12,FONT+16,FONT+20,FONT+24,FONT+28,FONT+32,FONT+36

	; 2nd COLUMN (40 bytes*32)
	dc.l FONT+1280		
	dc.l FONT+1284
	dc.l FONT+1288
	dc.l FONT+1292
	dc.l FONT+1296,FONT+1300,FONT+1304,FONT+1308,FONT+1312,FONT+1316

	; 3rd COLUMN (40 bytes*32*2)
	dc.l FONT+2560,FONT+2564,FONT+2568,FONT+2572,FONT+2576,FONT+2580
	dc.l FONT+2584,FONT+2588,FONT+2592,FONT+2596

	; 4th COLUMN (40 bytes*32*3)
	dc.l FONT+3840,FONT+3844,FONT+3848,FONT+3852,FONT+3856,FONT+3860
	dc.l FONT+3864,FONT+3868,FONT+3872,FONT+3876

	; 5th COLUMN (40 bytes*32*4)
	dc.l FONT+5120,FONT+5124,FONT+5128,FONT+5132,FONT+5136,FONT+5140
	dc.l FONT+5144,FONT+5148,FONT+5152,FONT+5156
	
	; 6th COLUMN (40 bytes*32*5)
	dc.l FONT+6400,FONT+6404,FONT+6408,FONT+6412,FONT+6416,FONT+6420
	dc.l FONT+6424,FONT+6428,FONT+6432,FONT+6436

	
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
	dc.w	$108,+4 ; Bpl1Mod  +4
	dc.w	$10a,+4 ; Bpl2Mod  +4

	dc.w	$100,bpls*$1000+$200	; bplcon0 - bitplane lowres

BPLPOINTERS:
	dc.w $e0,$0000,$e2,$0000	; bitplane 1
	dc.w $e4,$0000,$e6,$0000	; bitplane 2
	dc.w $e8,$0000,$ea,$0000	; bitplane 3

TEXT_COLOR:

	dc.w	$2c07,$fffe
        
	dc.w	$0180,$0000
	dc.w	$0182,$00af
	dc.w	$0184,$0148
	dc.w	$0186,$0567
	dc.w	$0188,$007e
	dc.w	$018a,$0aaa
	dc.w	$018c,$0eee
	dc.w	$018e,$068a	
	
	dc.w	$d307,$fffe
	dc.w	$0180,$000f
	dc.w	$d407,$fffe
	
	dc.w	$0180,$0000
	dc.w	$0182,$08ab
	dc.w	$0184,$0acd
	dc.w	$0186,$0cef
	dc.w	$0188,$0689
	dc.w	$018a,$0467
	dc.w	$018c,$0245
	dc.w	$018e,$0134
	
	dc.w	$ffdf,$fffe
	
	dc.w	$0207,$fffe
	dc.w	$180,$004
        
	dc.w	$184,$023	; dark color
	dc.w	$186,$118
	dc.w	$188,$25b
	dc.w	$18a,$38e
	dc.w	$18c,$acf
        
	dc.w	$182,$550	
	dc.w	$18e,$155	
	dc.w	$108,-84
	dc.w	$10A,-84
        
	dc.w	$0707,$fffe
	dc.w	$108,-172
	dc.w	$10A,-172
	dc.w	$180,$005
        
	dc.w	$0a07,$fffe
	dc.w	$108,-84
	dc.w	$10A,-84
	dc.w	$180,$006
        
	dc.w	$0c07,$fffe
	dc.w	$108,-172
	dc.w	$10A,-172
	dc.w	$180,$007
        
	dc.w	$0f07,$fffe
	dc.w	$108,-84
	dc.w	$10A,-84
	dc.w	$180,$008
        
	dc.w	$1207,$fffe
	dc.w	$108,-172
	dc.w	$10A,-172
	dc.w	$180,$009
        
	dc.w	$1407,$fffe
	dc.w	$108,-84
	dc.w	$10A,-84
	dc.w	$180,$00A
        
	dc.w	$1607,$fffe
	
	
	
	dc.w $FFFF,$FFFE	; End of copperlist

*****************************************************************************

	SECTION	Data,DATA_C

LOGO:
	incdir	"dh1:own/demo/repository/resources/images/"
	incbin	"logo_SM_128_80_3.raw"


FONT:
	incdir  "dh1:own/demo/repository/resources/fonts/"
	incbin  "32x32-FL.raw"

MT_DATA:
	incdir	"dh1:own/demo/repository/resources/mod/"	
	incbin	"mod.broken"
	
	
*****************************************************************************

	SECTION	Screen,BSS_C	

SCREEN:
	ds.b	ScrBpl*h*bpls		; 3 bitplane

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
