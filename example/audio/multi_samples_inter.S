*************************************************
*						*
*	  MULTIPLE AUDIO SAMPLE EXAMPLE		*
*						*
*    The interrupt routine was ripped from	*
*		Wizball (1988).			*
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

; A = AGNUS, D = DENISE, P = PAULA

;DMACON     096      W     A D P   DMA control write (clear or set)
;DMACONR    002      R     A   P   DMA control (and blitter status) read
DMASET=	%1000001000000000
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
INTENA=	%1100000000000000
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

TICKS_WAIT=70		; ~1.4 secs (0.02s * 70 ticks)

	SECTION	MAIN, CODE

START:

;--- Store Old Register Settings ---

	MOVEM.L	D0-D7/A0-A6,-(SP)

	LEA	$DFF000,A6
	MOVE.W	$1C(A6),OldIntena	; store old INTENA (INTENAR)

;--- Disable Intena/Intreq/Dmacon ---

	MOVE.L	#$7FFF7FFF,$9A(A6)	; disable INTENA/INTREQ

;--- Set Register Settings ---

	BSR	WAITVB			; Wait for VBLANK

;--- Program Interrupt ---

	MOVE.L	$70.W,OldInter		; store old INTER PTR

	MOVE.L	#INTER,$70.W		; set interrupt pointer

	MOVE.W	#$C180,$9A(A6)		; enable audio 0 and 1 interrupts

PREPARE_SAMPLES:

	MOVE.L  #SAMPLE_1,$A0(A6)		; table beginning
	MOVE.W  #SAMPLE_1_LEN/2,$A4(A6)		; table length in word
	MOVE.W  #424,$A6(A6)			; period (C)
	MOVE.W  #64,$A8(A6)			; loudness level (volume)

	MOVE.L  #SAMPLE_2,$B0(A6)		; table beginning
	MOVE.W  #SAMPLE_2_LEN/2,$B4(A6)		; table length in word
	MOVE.W  #424,$B6(A6)			; period (C)
	MOVE.W  #64,$B8(A6)			; loudness level (volume)

CHECK1	; play 2 sounds with a time lag

	MOVE.W	#$80,$9A(A6)			; disable Audio 0 interrupt
	MOVE.W	#$80,$9C(A6)			; cancel  Audio 0 intreq
	MOVE.W	#$01,$96(A6)			; stop    Audio 0 dma

	MOVE.W	#1,Flag				; set     Audio 0 flag

	MOVE.W  #$8001,$96(A6)   		; start  Audio 0 dma
	MOVE.W	#$80,  $9C(A6)			; cancel Audio 0 intreq
	MOVE.W	#$8080,$9A(A6)			; enable Audio 0 interrupt

	MOVE.W	#$0100,$9A(A6)			; disable Audio 1 interrupt
	MOVE.W	#$0100,$9C(A6)			; cancel  Audio 1 intreq
	MOVE.W	#$0002,$96(A6)			; stop    Audio 1 dma

	MOVE.B	#10,D0
	BSR	WAIT_CIAA_TOD			; wait 10 VPOS (~0.2s)

	MOVE.W	#2,Flag				; set     Audio 1 flag

	MOVE.W  #$8002,$96(A6)   		; start  Audio 1 dma
	MOVE.W	#$0100,$9C(A6)			; cancel Audio 1 intreq
	MOVE.W	#$8100,$9A(A6)			; enable Audio 1 interrupt

	MOVE.B	#TICKS_WAIT,D0
	BSR	WAIT_CIAA_TOD			; wait 70 VPOS (~1.4s)

	SUB.B	#1,Count

	BNE.W	CHECK1

CHECK2	; play 2 sounds at same time

	MOVE.W	#$0180,$9A(A6)			; disable Audio 0/1 interrupt
	MOVE.W	#$0180,$9C(A6)			; cancel  Audio 0/1 intreq
	MOVE.W	#$0003,$96(A6)			; stop    Audio 0/1 dma

	MOVE.W	#3,Flag				; set     Audio 0/1 flag

	MOVE.W  #$8003,$96(A6)   		; start  Audio 0/1 dma
	MOVE.W	#$0180,$9C(A6)			; cancel Audio 0/1 intreq
	MOVE.W	#$8180,$9A(A6)			; enable Audio 0/2 interrupt

	MOVE.B	#TICKS_WAIT,D0
	BSR	WAIT_CIAA_TOD			; wait 70 VPOS (~1.4s)

**** EXIT - RESTORE OLD REG SETTINGS ****

EXIT
	LEA	$DFF000,A6

	MOVE.W	#$7FFF,$9A(A6)		; disable interrupts	

	BSR.S	WAITVB

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
	MOVEM.L	D0-D2,-(SP)
	LEA	$DFF000,A6		; base custom register in A6

	MOVE.W	$1E(A6),D0		; get involved intreqs
	AND.W	#$780,D0		; filter audio 0/1/2/3 bits
	MOVE.W	#$780,$9C(A6)		; disable involved intreq
	MOVE.W	D0,D1
	LSR.W	#7,D1			; shift right 7 positions
	MOVE.W	D1,D2
	AND.W	Flag,D2
	BNE.B	.END			; if flag is ON skip to the end
	MOVE.W	D0,$9A(A6)		; disable interrupt
	MOVE.W	D1,$96(A6)		; stop dma
.END
	EOR.W	D2,Flag			; disable flag

	MOVEM.L	(SP)+,D0-D2
	RTE

				; Parameters
				; D0 - ticks value
WAIT_CIAA_TOD
	MOVE.B	D1,-(SP)
	LEA	$BFE001,A4	; CIAA base
	MOVEQ	#0,D1
	MOVE.B	D1,$A00(A4)	; todhi
	MOVE.B	D1,$900(A4)	; todmid
	MOVE.B	D1,$800(A4)	; todlo - start the clock
.WAITCIA
	MOVE.B	$800(A4),D1
	CMPI.B	D0,D1
	BCS.S	.WAITCIA
	MOVE.B	(SP)+,D1
	RTS

CRITICAL_STOP:					; force dma to stop

	LEA	$DFF000,A6
	MOVE.W	#$01,$96(A6)
	MOVE.W	#$02,$96(A6)
	MOVE.W	#$03,$96(A6)
	MOVE.W	#$04,$96(A6)

	RTS

OldIntena:
	DC.W	0
OldInter:
	DC.L	0
Flag
	DC.W	0
Count
	DC.B	2
	
	SECTION	MUSIC, DATA_C

	CNOP	0,2		; align data on a word boundary

	INCDIR	"RESOURCES:sounds/"
SAMPLE_1:
	INCBIN	"Alien"
SAMPLE_1_LEN=*-SAMPLE_1

SAMPLE_2:
	INCBIN	"SyntheBass"
SAMPLE_2_LEN=*-SAMPLE_2


	IF SAMPLE_1_LEN<>7800
	FAIL "SAMPLE NOT VALID"
	ENDC

	IF SAMPLE_2_LEN<>7900
	FAIL "SAMPLE NOT VALID"
	ENDC


