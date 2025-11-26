
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
wbl = 303

	
;*****************************************************************************
	incdir	SOURCES:
	include	"startup/borchen/startup.s"
	include	"replay/PT3.0b_replay_cia.s"
	
	
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
	beq.s	\1
	ENDM
	
Start:	

	move.w	#DMASET,$dff096		; enable necessary bits in DMACON
	move.w  #INTENA,$dff09a		; INTENA
	
	move.l	#COPPERLIST,$dff080	; COP1LCH set custom copperlist
	move.w	#0,$dff088		; COPJMP1 activate copperlist

	bsr.w	pt_init
	
Main:
	WAITVB	Main
	
	bsr.w	pt_play
	
Wait	WAITVB2	Wait
	
	RMOUSE WaitRM
	
	LMOUSE	Main

	bsr.w	pt_end
	
	rts
	
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
	dc.w 	$e0,$0000,$e2,$0000	; bitplane 1
	
	dc.w 	$0180, $0000		
	
	dc.w	$FFFF, $FFFE	; End of copperlist

	
*****************************************************************************

	SECTION	Data,DATA_C

pt_data:
	incdir	RESOURCES:
	incbin	"mod/mod.broken"

	
*****************************************************************************

	SECTION	Screen,BSS_C	

SCREEN:
	ds.b	40*256*bpls	; 

	end
