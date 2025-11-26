*************************************************
*						*
*	System OFF with PORTS Interrupt		*
*	bset/bclr method and raster wait	*
*	for keyboard handshake			*
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

; A = AGNUS, D = DENISE, P = PAULA

;DMACON     096      W     A D P   DMA control write (clear or set)
;DMACONR    002      R     A   P   DMA control (and blitter status) read
DMASET=	%1000000000000000
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
INTENA=	%1100000000001000
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

	BSR	WAITVB			; Wait for VBLANK

	MOVE.W	#DMASET,$96(A6)		; set bits of DMACON state

;--- Program Interrupt ---

	MOVE.L	$68.W,OldInter		; store old INTER PTR

	MOVE.L	#INTER,$68.W		; set interrupt pointer
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
	
	MOVE.B	$0D00(A5),D0		; Ciaa icr - reset the intreq

	BTST.L	#7,D0			; bit IR, check if inter is allowed
	BEQ.B	END_INTER	
	BTST.L	#3,D0			; bit SP, check if inter is allowed
	BEQ.B	END_INTER

	MOVE.W	$1C(A6),D0		; INTENAR
	BTST.L	#14,D0			; Check if INTENA Bit Master enabled 
	BEQ.B	END_INTER		
	
	BTST.L	#3,D0			; INTREQR - PORTS?
	BEQ.B	END_INTER		; 
	
	MOVE.B	$0C00(A5),D0  		; read a byte from CIAA sdr register
	NOT.B	D0          		; negate a byte in D0
	ROR.B	#1,D0       		; rotate right 1 bit

	CMPI.B	#$80,D0
	BCC.B	.OUTMODE

	MOVE.B	D0,KeyPressed

.OUTMODE
	BSET.B	#6,$0E00(A5)		; CIAA cra - SPMODE output

	MOVEQ	#4-1,D1			; wait 4 raster lines (at least 90us)
.WAITLINES				; for the handshake
	MOVE.B	$06(A6),D0		; some Amiga keyboards (i.e. A1200)
.CHECKLINE				; requires more time than others
	CMP.B	$06(A6),D0
	BEQ.B	.CHECKLINE
	DBF	D1,.WAITLINES

	BCLR.B	#6,$0E00(A5)		; CIAA cra - SPMODE input

END_INTER	
	MOVE.W	#$4008,$9C(A6)		; clear interrupt request
	MOVEM.L	(SP)+,D0-D7/A0-A6

	RTE
	

OldCopper:
	DC.L	0
OldIntena:
	DC.W	0
OldDma:
	DC.W	0
OldInter:
	DC.L	0
KeyPressed:
	DC.B	0
	EVEN
END

