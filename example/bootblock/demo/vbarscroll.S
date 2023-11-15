***********************************
*
*
*	VERTICAL BAR SCROLLER
*
*
***********************************

; attached with bblocktrd code
; note: all addresses must be relative referenced (i.e. with PC)

Standalone	; left mouse change bar color, right mouse exit

OldOpenLibrary = -408
CloseLibrary = -414
AllocRaster=	-492
FreeRaster=	-498

; A = AGNUS, D = DENISE, P = PAULA

;DMACON     096      W     A D P   DMA control write (clear or set)
;DMACONR    002      R     A   P   DMA control (and blitter status) read
DMASET=	%1000001110000000 ($8380)
;	 fedcba9876543210

;	f: Set/Clear control bit
;	e: Blitter busy status bit (read only)
;	d: Blotter logic zero status bit (read only)
;	c: X
;	b: X
;	a: Blitter DMA priority (blitter nasty)
;	9: Enable all DMA below
;	8: Bitplane DMA enable
;	7: Copper DMA enable
;	6: Blitter DMA enable
;	5: Sprite DMA enable
;	4: Disk DMA enable
;	3: Audio channel 3 DMA enable
;	2: Audio channel 2 DMA enable
;	1: Audio channel 1 DMA enable
;	0: Audio channel 0 DMA enable
			

;INTENA     09A      W       P    Interrupt enable bits (clear or set bits)
;INTENAR    01C      R       P    Interrupt enable bits (read)
INTENA=	%1100000000100000 ($C020)
;	 fedcba9876543210

;	f: Set/Clear control bit 
;	e: Master interrupt
;	d: External interrupt
;	c: Disk sync register ( DSKSYNC ) matches disk data
;	b: Serial port receive buffer full
;	a: Audio channel 3 block finished
;	9: Audio channel 2 block finished
;	8: Audio channel 1 block finished
;	7: Audio channel 0 block finished
;	6: Blitter finished
;	5: Start of vertical blank
;	4: Copper
;	3: I/O ports and timers
;	2: Reserved for software -initalited interrupt
;	1: Disk block finished
;	0: Serial port transmit buffere empty

SCR_WIDTH=320
SCR_HEIGHT=256

START:
	IFD	Standalone
	MOVEM.L	D0-D7/A0-A6,-(SP)
	ENDC
	
	MOVE.L	$4.W,A6
	LEA	GFXNAME(PC),A1
	JSR	OldOpenLibrary(A6)	; load graphics library
	MOVE.L	D0,A6
	
	IFD	Standalone
	LEA	OldCopper(PC),A0
	MOVE.L	$26(A6),(A0)
	ENDC
	
;---  Allocate Raster  ---

	MOVE.L	#SCR_WIDTH,D0		; Width
	MOVE.L	#SCR_HEIGHT,D1		; Higth
	JSR	AllocRaster(A6)		; Allocate memory for bitplane WxH
	LEA	ScreenPtr(PC),A0	
	MOVE.L	D0,(A0)			; Write btpl ptr on ScreenPtr
	
;--- Clear screen  ---

	MOVE.L	(A0),A0			; Point A0 to bitplane address
	MOVE.W	#SCR_WIDTH/8*SCR_HEIGHT/4-1,D1	; Clear 320/8 bytes wide
	MOVEQ	#0,D2			; times 260 bytes high
	
.LOOPC	
	MOVE.L	D2,(A0)+		; in longwords / 4
	DBF	D1,.LOOPC

;---  Set BPL ptrs  ---

	LEA.L	BITPLANES+2(PC),A0
	MOVEQ	#40,D1
	ADD.L	D0,D1
	SWAP	D0		; High word of pointer
	MOVE.W	D0,(A0)		; Store high 1
	ADDQ.W	#4,A0
	SWAP	D0		; Low word of pointer
	MOVE.W	D0,(A0)		; Store low 1

	LEA	$DFF000,A6

	IFD 	Standalone

	LEA	OldIntena(PC),A0
	MOVE.W	$1C(A6),(A0)		; store old INTENA (INTENAR)
	LEA	OldDma(PC),A0
	MOVE.W	$02(A6),(A0)		; store old DMACON (DMACONR)	
	LEA	OldInter(PC),A0		
	MOVE.L	$6C.W,(A0)		; store old INTER

	ENDC

;--- Disable Interrupt

	MOVE.W	#$7FFF,$9A(A6)		; Clear interrupt enable
	BSR.L	WAITVB			; Wait for VBLANK

;--- Disable Dma

	MOVE.W	#$7FFF,$96(A6)		; Dma disable	

;--- Set Interrupt request ---

	LEA	INTER(PC),A0
	MOVE.L	A0,$6C.W

;--- Set Interrupt

	MOVE.W	#$7FFF,$9C(A6)		; Clear request
	MOVE.W	#INTENA,$9A(A6)		; Interrupt enable

;--- Set copperlist ---

	LEA	COPPERLIST(PC),A0	
	MOVE.L	A0,$80(A6)		; write our copperlist to COP1 loc reg
	MOVEQ	#0,D0
	MOVE.W	D0,$88(A6)		; Launch COPJMP1
	MOVE.W	D0,$1FC(A6)		; FMODE - BLP32
	MOVE.W	#$C00,$106(A6)

;--- Set Dma ---

	MOVE.W	#DMASET,$96(A6)		; set bits of DMACON state

.LEFTMOUSE
	BTST	#6,$BFE001
	IFND	Standalone
	BNE.S	.LEFTMOUSE
	
	ELSE
	BEQ.S	.CHANGECOLOR
.RIGHTMOUSE
	BTST	#2,$DFF016
	BNE	.LEFTMOUSE
	
	LEA	$DFF000,A6
	
	MOVE.W	#$7FFF,$9A(A6)		; disable interrupts

	BSR.W	WAITVB

	MOVE.W	#$7FFF,$96(A6)		; disable DMA
	
	MOVE.W	OldDma(PC),D0
	OR.W	#$8000,D0		; set bits of DMACON state
	MOVE.W	D0,$96(A6)		; restore original DMACON

	MOVE.L	OldCopper(PC),$80(A6)	; restore original COPPERLIST
	MOVE.W	D0,$88(A6)		; activate original COPPERLIST

	MOVE.L	OldInter(PC),$6C.W	; restore inter pointer

	MOVE.W	#$7FFF,$9C(A6)		; clear requests

	MOVE.W	OldIntena(PC),D0
	OR.W	#$C000,D0		; set bits of INTENA state
	MOVE.W	D0,$9A(A6)		; restore original INTENA

	MOVEM.L (SP)+,D0-D7/A0-A6

	RTS
	
	ENDC
	
.CHANGECOLOR	
	LEA	COLOR01+2(PC),A0
	MOVE.W	(A0),D0			; read $0182 (COLOR1) 
	ROR	#4,D0			; change color
	MOVE.W	D0,(A0)			; write color to $0182
	BRA.S	.LEFTMOUSE

WAITVB:
	TST.B	$DFF005
	BEQ.B	WAITVB
.LOOP
	TST.B	$DFF005
	BNE.S	.LOOP
	RTS

INTER:
	MOVEM.L	D0-D7/A0-A6,-(SP)
	
	MOVE.L	ScreenPtr(PC),A0
	LEA	LinePos(PC),A1
	
	MOVEQ	#0,D1
	MOVE.B	(A1),D1
	MOVE.L	D1,D2			; Set vline position to D2

	MULU.W	#40,D1
	ADD.L	D1,A0			; Point to screen according to line pos

	MOVEQ	#10-1,D0
.DELLINE
	MOVE.L	#$00000000,(A0)+
	DBF	D0,.DELLINE		; Delete line at screen position
	
	MOVEQ	#10-1,D0
.WRTLINE
	MOVE.L	#$FFFFFFFF,(A0)+
	DBF	D0,.WRTLINE		; Write line at screen position

	ADDQ	#1,D2
	MOVE.B	D2,(A1)			; Update LinePos+1
	
	MOVE.W	#$4020,$9C(A6)		; Clear interrupt request
	MOVEM.L	(SP)+,D0-D7/A0-A6
	
	RTE
	
ScreenPtr:	
	DC.L	0
LinePos:	
	DC.B	$FF
	EVEN
OldCopper:
	DC.L	0
OldIntena:
	DC.W	0
OldDma:
	DC.W	0
OldInter:
	DC.L	0
GFXNAME:
	DC.B	'graphics.library',0
	EVEN
COPPERLIST:
	DC.L	$01800000
COLOR01:
	DC.L	$01820FFF
BITPLANES:
	DC.L	$00E00000	; Bitplane 1 pointer high bits
	DC.L	$00E20000	; Bitplane 1 pointer low bits
	DC.L	$00E40000	; Bitplane 2 pointer hight bits
	DC.L	$00E60000	; Bitplane 2 pointer low bits
	DC.L	$01001200	; BPLCON0 Bitplane control register
	DC.L	$01020000	; BPLCON1
	DC.L	$01040000	; BPLCON2
	DC.L	$01080000	; Bitplane modulo (odd planes)
	DC.L	$010A0000	; Bitplane modulo (even planes)
	DC.L	$008E2C78	; DIWSTRT
	DC.L	$00902CC8	; DIWSTOP
	DC.L	$00920038	; DDFSTRT
	DC.L	$009400D0	; DDFSTOP
	DC.L	$FFFFFFFE

