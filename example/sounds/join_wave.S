*************************************************
*						*
*	JOIN WAVEFORM 	EXAMPLE			*
*						*
*************************************************

; this example show how to join 2 waveforms.
; each time sound data is finished to read, an interrupt occurs
; every interrupt the waveform switch between sine and triange
; see http://amigadev.elowar.com/read/ADCD_2.1/Hardware_Manual_guide/node00E5.html


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
DMASET=	%1000001010000001 ($8201)
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
INTENA=	%1100000010000000 ($C008)
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

DMACON	= $DFF096	; DMA control
AUD0LCH = $DFF0A0  	; table address HI
AUD0LCL = AUD0LCH+2  	; table address LO
AUD0LEN = AUD0LCH+4   	; table length
AUD0PER = AUD0LCH+6     ; read in rate
AUD0VOL = AUD0LCH+8    	; loudness level

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

;	MOVE.W	#DMASET,$96(A6)		; set bits of DMACON state
	MOVE.L	#COPPERLIST,$80(A6)	; set custom COPPERLIST
	MOVEQ	#0,D0
	MOVE.W	D0,$88(A6)		; activate COPPERLIST
	MOVE.W	D0,$1FC(A6)		; FMODE - BPL32

;--- Program Interrupt ---

	MOVE.L	$70.W,OldInter		; store old INTER PTR

	MOVE.L	#INTER,$70.W		: set interrupt pointer
	MOVE.W	#INTENA,$9A(A6)		; set bit of INTENA	
	
MAIN:
	MOVE.L  #SINE,$A0(A6)			; table beginning
	MOVE.W  #(SINE_END-SINE)/2,$A4(A6)	; table length in word
	MOVE.W  #212,$A6(A6)			; period (C)
	MOVE.W  #64,$A8(A6)			; loudness level (volume)
	MOVE.W  #DMASET,$96(A6)   		; start DMA (Sound)

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

	MOVE.L	OldCopper(PC),$80(A6)	; restore original COPPERLIST
	MOVE.W	D0,$88(A6)		; activate original COPPERLIST

	MOVE.L	OldInter(PC),$70.W	; restore inter pointer

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

	BTST.B	#7,$1F(A6)		; check if is level 4 interrupt
	BEQ.B	END_INTER
	
	NOT.B	WAVE_VAL
	BNE.B	.TRIANGLE

	MOVE.L  #SINE,$A0(A6)
	BRA.W	END_INTER
.TRIANGLE:
	MOVE.L  #TRIANGLE,$A0(A6)
	
END_INTER	
	MOVE.W	#$4780,$9C(A6)		; clear interrupt request	
	MOVEM.L	(SP)+,D0-D7/A0-A6

	RTE


SINE:  				; 16 byte sample - SINE
	DC.B	0, 39, 75, 103, 127, 103, 75, 39
	DC.B	0,-39,-75,-103,-127,-103,-75,-39
SINE_END

TRIANGLE:  			; 16 byte sample - TRIANGLE
	DC.B	0, 32, 64, 96, 128, 96, 64, 32
	DC.B	0,-32,-64,-96,-127,-96,-64,-32
TRIANGLE_END



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

WAVE_VAL:
	DC.B	0	; 0 = SINE $FF = TRIANGLE

	SECTION Copper,DATA_C

COPPERLIST:
	DC.L	$01800000
	DC.L	$01820FFF
	DC.L	$FFFFFFFE
END

; This example details the system audio DMA action in a step-by-step
; fashion.
; 
; Suppose you wanted to join together a sine and a triangle waveform,
; end-to-end, for a special audio effect, alternating between them. The
; following sequence shows the action of your program as well as its
; interaction with the audio DMA system. The example assumes that the
;  period ,  volume , and  length  of the data set remains the same for the
; sine wave and the triangle wave.
; 
; 
;                          Interrupt Program
;                          -----------------
; If (wave = triangle)
;                write  AUD0LCL  with address of sine wave data.
; 
; Else if (wave = sine)
;                write  AUD0LCL  with address of triangle wave data.
; 
; 
;                           Main Program
;                           ------------
; 
; 1. Set up  volume ,  period , and  length .
; 2. Write  AUD0LCL  with address of sine wave data.
; 3. Start DMA.
; 4. Continue with something else.
; 
; 
;                          System Response
;                          ---------------
; 
; As soon as DMA starts,
; 
;    a. Copy to "back-up" length register from  AUD0LEN .
;    b. Copy to "back-up" location register from  AUD0LCL  (will be used
;       as a pointer showing current data word to fetch).
;    c. Create an  interrupt  for the 680x0 saying that it has completed
;       retrieving working copies of  length  and  location registers .
;    d. Start retrieving audio data each allocated DMA time slot.