
	SECTION	Code,CODE	; This command will run the below code
				; on FAST RAM (if enough) or CHIP RAM

DMASET	= %1000001010000000
;	  %-----axbcdefghij
;	a: Blitter Nasty
;	x: Enable DMA
;	b: Bitplane DMA (if this isn't set, sprites disappear!)
;	c: Copper DMA
;	d: Blitter DMA
;	e: Sprite DMA
;	f: Disk DMA
;	g-j: Audio 3-0 DMA

INTENA=	    %1100000000100000
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

bpls = 1

	
;*****************************************************************************
	incdir	SOURCES:
	include	"startup/borchen/startup.s"
;*****************************************************************************

WAITVB	MACRO
	move.l	$dff004,d0		; wait
	and.l	#$0001ff00,d0		; for
	cmp.l	#303<<8,d0		; rasterline 303
	bne.s	\1
	ENDM

	
Start:	
	
	bsr.w	Wait_Vert_Blank

	move.w	#DMASET,$dff096		; enable necessary bits in DMACON
	move.l	#COPPERLIST,$dff080	; COP1LCH set custom copperlist

	move.l	$6C.W,OldInter		; Store old inter pointer
	move.l	#INTER,$6C.W		; Set interrupt pointer

	move.w	#$7FFF,$dff09c		; Clear request
	clr.w	$dff088			; Start copper1
	move.w  #INTENA,$dff09a		; INTENA
	
loop	
	btst	#6,$bfe001		; check for left mouse button
	bne.s	loop			; if not, repeat the above line

	move.l	OldInter(PC),$6C.W	; Restore inter pointer
	
	rts

Wait_Vert_Blank:
	tst.b	$dff005
	beq.s	Wait_Vert_Blank
.loop	
	tst.b	$dff005
	bne.s	.loop
	rts

INTER:
	movem.l	D0-D7/A0-A6,-(A7)	; Put registers on stack
	lea.l	$DFF000,A6
	move.l	#SCREEN,$E0(A6)

;---  Place your interrupt routine here  ---

	;bsr.s	some_routine

	move.w	#$4020,$9C(A6)		; Clear interrupt request
	movem.l	(A7)+,D0-D7/A0-A6 	; Get registers from stack
	rte
	
OldInter	dc.l	0

		
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
	dc.w $0182,$0000
	
	dc.w	$FFFF,$FFFE	; End of copperlist

	
*****************************************************************************

	SECTION	Data,DATA_C
	
		
;*****************************************************************************

	SECTION	Screen,BSS_C	

SCREEN:
	ds.b	40*256*bpls	; 

	end
