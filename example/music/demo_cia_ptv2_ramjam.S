

;*****************************************************************************
	
	SECTION	Code,CODE

	incdir 	"dh1:own/demo/repository/startup/ramjam/"
	include "Startup2.s"

Waitdisk	EQU	10

DMASET=	   %1000001110100000
;           -----axbcdefghij

;    a: Blitter Nasty
;    x: DMA below on
;    b: Bitplane DMA (if this isn't set, sprites disappear!)
;    c: Copper DMA
;    d: Blitter DMA
;    e: Sprite DMA
;    f: Disk DMA
;    g-j: Audio 3-0 DMA

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

bpls = 1

	
START:

	move.l	4.w,a6		; 
	JSR	-$7E(A6)		; enable sysinterrupts (CIA)
	
	lea	$dff000,a5		; CUSTOM REGISTER in a5
	move.w	#DMASET,$96(a5)		; DMACON 
	move.w  #INTENA,$9A(a5)		; INTENA
	
	move.l	#COPPERLIST,$80(a5)	; Point to COP
	move.w	d0,$88(a5)		; STROBE COP
	move.w	#0,$1fc(a5)		; AGA FMODE - OCS compatible
	move.w	#$c00,$106(a5)	; AGA BPLCON3 - OCS compatible
	move.w	#$11,$10c(a5)		
	
	bsr.s	SetCIAInt
	bsr	mt_init
	st	mt_Enable
	
Main:
	btst	#6,$BFE001
	bne.s	Main

theend
	
	bsr	mt_end
	bsr	ResetCIAInt
	rts
	

	incdir  "dh1:own/demo/repository/replay/"
	include	"PT2.3a_replay_cia.s"

;DOSname	dc.b "dos.library",0
;GfxName	dc.b "graphics.library",0,0

	
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
	dc.w	$108,0	; Bpl1Mod  
	dc.w	$10a,0	; Bpl2Mod  

	dc.w	$100,bpls*$1000+$200	; bplcon0 - bitplane lowres

BPLPOINTERS:
	dc.w $e0,$0000,$e2,$0000	;first bitplane
	
	dc.w $0180,$0000
	
	dc.w	$FFFF,$FFFE	; End of copperlist

;*****************************************************************************

	
	SECTION	Data, DATA_C

MT_DATA:
	incdir  "dh1:own/demo/repository/resources/mod/"
	incbin	"mod.broken"


;*****************************************************************************

	SECTION	Screen,BSS_C	

SCREEN:
	ds.b	40*256*bpls		; bitplane

	end
