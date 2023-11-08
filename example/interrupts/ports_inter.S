*************************************************
*						*
*	System OFF with PORTS Interrupt		*
*		and/or method			*
*						*
*************************************************

; CIAA Address Map
; ---------------------------------------------------------------------------
;  Byte    Register                  Data bits
; Address    Name     7     6     5     4     3     2     1    0
; ---------------------------------------------------------------------------
; BFE001    pra     /FIR1 /FIR0  /RDY /TK0  /WPRO /CHNG /LED  OVL
; BFE101    prb     Parallel port
; BFE201    ddra    Direction for port A (BFE001);1=output (set to 0x03)
; BFE301    ddrb    Direction for port B (BFE101);1=output (can be in or out)
; BFE401    talo    CIAA timer A low byte (.715909 Mhz NTSC; .709379 Mhz PAL)
; BFE501    tahi    CIAA timer A high byte
; BFE601    tblo    CIAA timer B low byte (.715909 Mhz NTSC; .709379 Mhz PAL)
; BFE701    tbhi    CIAA timer B high byte
; BFE801    todlo   50/60 Hz event counter bits 7-0 (VSync or line tick)
; BFE901    todmid  50/60 Hz event counter bits 15-8
; BFEA01    todhi   50/60 Hz event counter bits 23-16
; BFEB01            not used
; BFEC01    sdr     CIAA serial data register (connected to keyboard)
; BFED01    icr     CIAA interrupt control register
; BFEE01    cra     CIAA control register A
; BFEF01    crb     CIAA control register B

; This example show how to check for keyboard button pressed
; Press F10 to switch power led on / off

OldOpenLibrary = -408
CloseLibrary = -414

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
INTENA=	%1100000000001000 ($C008)
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

	MOVE.L	$4.W,A6
	LEA	GFXNAME(PC),A1
	JSR	OldOpenLibrary(A6)	; load graphics library
	MOVE.L	D0,A1
	MOVE.L	38(A1),OldCopper	; store old copper 1
	JSR	CloseLibrary(A6)	; close graphics library

	LEA	$DFF000,A6
	MOVE.W	$1C(A6),OldIntena	; store old INTENA (INTENAR)
	MOVE.W	$02(A6),OldDma		; store old DMACON (DMACONR)	

;--- Disable Intena/Intreq/Dmacon ---

	MOVE.L	#$7FFF7FFF,$9A(A6)	; disable INTENA/INTREQ
	MOVE.W	#$7FFF, $96(A6)		; disable DMACON


;--- Set Register Settings ---

	BSR	WAITVB			; Wait for VBLANK

	MOVE.W	#DMASET,$96(A6)		; set bits of DMACON state
	MOVE.L	#COPPERLIST, $80(A6)	; set custom COPPERLIST

;--- Program Interrupt ---

	MOVE.L	$68.W,OldInter		; store old INTER PTR

	MOVE.L	#INTER,$68.W		: set interrupt pointer
	MOVE.W	#INTENA,$9A(A6)		; set bit of INTENA	

LEFTMOUSE
	BTST	#6,$BFE001
	BNE.S	LEFTMOUSE

**** EXIT - RESTORE OLD REG SETTINGS ****

	LEA	$DFF000,A6

	MOVE.W	#$7FFF,$9A(A6)		; disable interrupts	

	BSR.S	WAITVB

	MOVE.W	#$7FFF,$96(A6)		; disable DMA
	
	MOVE.W	OldDma(PC),D0
	OR.W	#$8000,D0		; set bits of DMACON state
	MOVE.W	D0,$96(A6)		; restore original DMACON

	MOVE.L	OldCopper,$80(A6)	; restore original COPPERLIST
	CLR.W	$88(A6)			; activate original COPPERLIST

	MOVE.L	OldInter(PC),$68.W	; restore inter pointer

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
	LEA	$DFF000,A6		; base custom register in A6
	LEA	$BFE001,A5		; base CIAA register in A5
	
	MOVEQ 	#$08,D0			
	
	MOVE.W	$1E(A6),D1		; check if is it level 2 interrupt
	AND.W	D0,D1
	BEQ.B	END_INTER
	
	MOVE.B	$0D00(A5),D1		; check if SP cause interrupt
	AND.B	D0,D1			; read from CIAA icr
	BEQ.B	END_INTER
	
	MOVE.B	$0C00(A5),D0  		; read a byte from CIAA sdr register
	NOT.B	D0          		; negate a byte in D0
	ROR.B	#1,D0       		; rotate right 1 bit

	CMP.B	#$59,D0     		; compare F10 key value with d0
	BNE.S	NOTF10    		; if not F10 pressed - goto exit
	BCHG	#1,(A5)			; Test bit and change. 					; Bit 1 is power LED

NOTF10:
	OR.B	#$40,$0E00(A5)		; CIAA cra - SPMODE output

	MOVEQ	#4-1,D1			; wait 4 raster lines (at least 90us)
.WAITLINES				; for the handshake
	MOVE.B	$06(A6),D0		; some Amiga keyboards (i.e. A1200)
.CHECKLINE				; requires more time than others
	CMP.B	$06(A6),D0
	BEQ.B	.CHECKLINE
	DBF	D1,.WAITLINES

	AND.B	#$BF,$0E00(A5)		; CIAA cra - SPMODE input

END_INTER	
	MOVE.W	#$4008,$9C(A6)		; clear interrupt request
	MOVEM.L	(SP)+,D0-D7/A0-A6

	RTE
	

GFXNAME:
	DC.B	'graphics.library',0
	EVEN
OldCopper:
	DC.L	0
OldIntena:
	DC.W	0
OldDma:
	DC.W	0
OldInter:
	DC.L	0


	SECTION Copper,DATA_C

COPPERLIST:
	DC.L	$01800000
	DC.L	$01820FFF
	DC.L	$FFFFFFFE
END

