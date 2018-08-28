************************************************************************
*
*	This example show an use of direct access to SPRITE REGISTER
*
*	Opposing to DMA access, with properly use of copper is possible to 
*	reuse sprite on the same line.
*	The columns on the example are so composed:
*
*	SPRITE0	SPRITE1	SPRITE0	SPRITE1
*
*************************************************************************


	SECTION	Code,CODE	; This command will run the below code
				; on FAST RAM (if enough) or CHIP RAM

DMASET	= %1000001110100000
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

w	=320
h	=256
ScrBpl	=w/8+4	; standard screen width
bpls = 1

;wbl = $2c (for copper monitor only)
wbl = 303

	
;*****************************************************************************
	incdir	"dh1:own/demo/repository/startup/borchen/"
	include	"startup.s"	; 
;*****************************************************************************

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

	move.w	#DMASET,$dff096		; enable necessary bits in DMACON
	move.w  #INTENA,$dff09a		; INTENA
	
	move.l	#COPPERLIST,$dff080	; COP1LCH set custom copperlist
	move.w	#0,$dff088		; COPJMP1 activate copperlist
	
Main:
	WAITVB	Main
	
	
Wait    WAITVB2 Wait
	
	LMOUSE Main
	
	rts


****************************************************************
		
;*****************************************************************************

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
	dc.w	$108,0		; Bpl1Mod
	dc.w	$10a,0		; Bpl2Mod

	dc.w	$100,bpls*$1000+$200	; bplcon0 - bitplane lowres

BPLPOINTERS:
	dc.w $e0,$0000,$e2,$0000	;first bitplane
	
	dc.w $0180,$0000
	;dc.w $0182,$0000

	dc.w	$3c07,$fffe
	
	dc.w	$1A2,$f00
	dc.w	$1A4,$0f0
	dc.w	$1A6,$fff

	;dc.w	$140,$00d8
	;dc.w	$140,$003c

COL1=$07
COL2=$47

POS1=$0040
POS2=$0046
POS3=$004D
POS4=$0053
SPRDATA=$000f
SPRDATB=$000f

	dc.w	$140,POS1
	dc.w	$142,$0000	;SPR0CTL
	dc.w	$146,SPRDATA
	dc.w	$144,SPRDATA

	dc.w	$148,POS2	;SPR1POS
	dc.w	$14a,$0001	;SPR1CTL
	dc.w	$14e,SPRDATA
	dc.w	$14c,SPRDATA
	
	dc.w	$3c47,$fffe	
	dc.w	$0140,POS3	;SPR0POS
	
	dc.w	$148,POS4	;SPR1POS
	
	dc.w	$3d07,$fffe	; start row
	dc.w	$140,POS1	; SPR0POS
	dc.w	$148,POS2	; SPR1POS
	dc.w	$3d47,$fffe	; middle row
	dc.w	$140,POS3	; SPR0POS
	dc.w	$148,POS4	; SPR1POS
	
	
	dc.w	$3e07,$fffe	; start r
	dc.w	$140,POS1	; SPR0POS
	dc.w	$148,POS2	; SPR1POS
	dc.w	$3e47,$fffe	; middle 
	dc.w	$140,POS3	; SPR0POS
	dc.w	$148,POS4	; SPR1POS
	
	
	dc.w	$3f07,$fffe	; start r
	dc.w	$140,POS1	; SPR0POS
	dc.w	$148,POS2	; SPR1POS
	dc.w	$3f47,$fffe	; middle 
	dc.w	$140,POS3	; SPR0POS
	dc.w	$148,POS4	; SPR1POS
	
	dc.w	$4007,$fffe	; start r
	dc.w	$140,POS1	; SPR0POS
	dc.w	$148,POS2	; SPR1POS
	dc.w	$4047,$fffe	; middle 
	dc.w	$140,POS3	; SPR0POS
	dc.w	$148,POS4	; SPR1POS
	
	dc.w	$4107,$fffe	; start r
	dc.w	$140,POS1	; SPR0POS
	dc.w	$148,POS2	; SPR1POS
	dc.w	$4147,$fffe	; middle 
	dc.w	$140,POS3	; SPR0POS
	dc.w	$148,POS4	; SPR1POS
	
	dc.w	$4207,$fffe	; start r
	dc.w	$140,POS1	; SPR0POS
	dc.w	$148,POS2	; SPR1POS
	dc.w	$4247,$fffe	; middle 
	dc.w	$140,POS3	; SPR0POS
	dc.w	$148,POS4	; SPR1POS
	
	dc.w	$4307,$fffe	; start r
	dc.w	$140,POS1	; SPR0POS
	dc.w	$148,POS2	; SPR1POS
	dc.w	$4347,$fffe	; middle 
	dc.w	$140,POS3	; SPR0POS
	dc.w	$148,POS4	; SPR1POS
	
	dc.w	$4407,$fffe	; start r
	dc.w	$140,POS1	; SPR0POS
	dc.w	$148,POS2	; SPR1POS
	dc.w	$4447,$fffe	; middle 
	dc.w	$140,POS3	; SPR0POS
	dc.w	$148,POS4	; SPR1POS
	
	dc.w	$4507,$fffe	; start r
	dc.w	$140,POS1	; SPR0POS
	dc.w	$148,POS2	; SPR1POS
	dc.w	$4547,$fffe	; middle 
	dc.w	$140,POS3	; SPR0POS
	dc.w	$148,POS4	; SPR1POS

	dc.w	$4607,$fffe	; start r
	dc.w	$140,POS1	; SPR0POS
	dc.w	$148,POS2	; SPR1POS
	dc.w	$4647,$fffe	; middle 
	dc.w	$140,POS3	; SPR0POS
	dc.w	$148,POS4	; SPR1POS	
	
	dc.w	$4707,$fffe	; start r
	dc.w	$140,POS1	; SPR0POS
	dc.w	$148,POS2	; SPR1POS
	dc.w	$4747,$fffe	; middle 
	dc.w	$140,POS3	; SPR0POS
	dc.w	$148,POS4	; SPR1POS
	
	dc.w	$4807,$fffe	; start r
	dc.w	$140,POS1	; SPR0POS
	dc.w	$148,POS2	; SPR1POS
	dc.w	$4847,$fffe	; middle 
	dc.w	$140,POS3	; SPR0POS
	dc.w	$148,POS4	; SPR1POS
	
	dc.w	$4907,$fffe	; start r
	dc.w	$140,POS1	; SPR0POS
	dc.w	$148,POS2	; SPR1POS
	dc.w	$4947,$fffe	; middle 
	dc.w	$140,POS3	; SPR0POS
	dc.w	$148,POS4	; SPR1POS
	
	dc.w	$4a07,$fffe	; start r
	dc.w	$140,POS1	; SPR0POS
	dc.w	$148,POS2	; SPR1POS
	dc.w	$4a47,$fffe	; middle 
	dc.w	$140,POS3	; SPR0POS
	dc.w	$148,POS4	; SPR1POS
	
	dc.w	$4b07,$fffe	; start r
	dc.w	$140,POS1	; SPR0POS
	dc.w	$148,POS2	; SPR1POS
	dc.w	$4b47,$fffe	; middle 
	dc.w	$140,POS3	; SPR0POS
	dc.w	$148,POS4	; SPR1POS
	
	dc.w	$4c07,$fffe	; start r
	dc.w	$140,POS1	; SPR0POS
	dc.w	$148,POS2	; SPR1POS
	dc.w	$4c47,$fffe	; middle 
	dc.w	$140,POS3	; SPR0POS
	dc.w	$148,POS4	; SPR1POS

	dc.w	$3d07,$fffe
	dc.w	$142,$0000
	dc.w	$14a,$0000

	dc.w	$FFFF,$FFFE	; End of copperlist

	
*****************************************************************************

	SECTION	Data,DATA_C

MT_DATA:
	incdir  "dh1:own/demo/repository/resources/mod/"
	incbin	"mod.broken"

	
*****************************************************************************

	SECTION	Screen,BSS_C	

SCREEN:
	ds.b	40*256*bpls	; 

	end

