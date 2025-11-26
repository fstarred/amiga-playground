*************************************************
*						*
*	System OFF with VBLANK Interrupt	*
*						*
*************************************************

; If you want to debug with Assembler (i.e. ASM-One),
; comment the following lines:
;
; MOVE.L #$7FFF7FFF,$9A(A6)	; disable INTENA/INTREQ ; at least disable
;				INTREQ
; MOVE.W #$7FFF, $96(A6)	; disable DMACON
; MOVE.L #COPPERLIST, $80(A6)	; this trigger our custom copperlist
;
; MOVE.L #INTER,$6C.W		: set interrupt pointer
; MOVE.W #INTENA,$9A(A6)	; set bit of INTENA



OldOpenLibrary = -408
CloseLibrary = -414

; A = AGNUS, D = DENISE, P = PAULA

;DMACON     096      W     A D P   DMA control write (clear or set)
;DMACONR    002      R     A   P   DMA control (and blitter status) read
DMASET=	%1000001110000000
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
INTENA=	%1100000000100000
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


START:

;--- Store Old Register Settings ---

	MOVEM.L	D0-D7/A0-A6,-(SP)

	LEA	$DFF000,A6
	MOVE.W	$1C(A6),OldIntena	; store old INTENA (INTENAR)
	MOVE.W	$02(A6),OldDma		; store old DMACON (DMACONR)	

;--- Disable Intena/Intreq/Dmacon ---

	MOVE.L	#$7FFF7FFF,$9A(A6)	; disable INTENA/INTREQ
	MOVE.W	#$7FFF, $96(A6)		; disable DMACON


;--- Set Register Settings ---

	BSR.W	WAITVB			; Wait for VBLANK

	MOVE.W	#DMASET,$96(A6)		; set bits of DMACON state
	MOVEQ	#0,D0
	MOVE.W	D0,$1FC(A6)		; FMODE - BPL32

;--- Program Interrupt ---

	MOVE.L	$6C.W,OldInter		; store old INTER PTR

	MOVE.L	#INTER,$6C.W		; set interrupt pointer
	MOVE.W	#INTENA,$9A(A6)		; set bit of INTENA
	
	BSR.W	mt_init

LEFTMOUSE
	BTST	#6,$BFE001
	BNE.S	LEFTMOUSE

**** EXIT - RESTORE OLD REG SETTINGS ****

	BSR.W	mt_end

	LEA	$DFF000,A6

	MOVE.W	#$7FFF,$9A(A6)		; disable interrupts	

	BSR.S	WAITVB

	MOVE.W	#$7FFF,$96(A6)		; disable DMA
	
	MOVE.W	OldDma(PC),D0
	OR.W	#$8000,D0		; set bits of DMACON state
	MOVE.W	D0,$96(A6)		; restore original DMACON

	MOVE.L	OldInter(PC),$6C.W	; restore inter pointer

	MOVE.W	#$7FFF,$9C(A6)		; clear requests

	MOVE.W	OldIntena(PC),D0
	OR.W	#$C000,D0		; set bits of INTENA state
	MOVE.W	D0,$9A(A6)		; restore original INTENA
	
	MOVEM.L (SP)+,D0-D7/A0-A6

	RTS

WAITVB:
	TST.B	$DFF005
	BEQ.B	WAITVB
.LOOP
	TST.B	$DFF005
	BNE.S	.LOOP
	RTS

INTER:
	MOVEM.L	D0-D7/A0-A6,-(SP)
	LEA	$DFF000,A6	

	BTST.B	#5,$1F(A6)
	BEQ.B	EXIT_INTER

	BSR.W	mt_music

EXIT_INTER:
	MOVE.W	#$4020,$9C(A6)		; clear interrupt request
	MOVEM.L	(SP)+,D0-D7/A0-A6
	RTE

	INCDIR	SOURCES:
	INCLUDE	"replay/protracker_v2.3a.s"
	

OldIntena:
	DC.W	0
OldDma:
	DC.W	0
OldInter:
	DC.L	0

	SECTION Music,DATA_C

mt_data:
	INCDIR	RESOURCES:
	INCBIN	"mod/mod.towards"

END

