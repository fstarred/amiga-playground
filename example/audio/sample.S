*************************************************
*						*
*	     AUDIO SAMPLE EXAMPLE		*
*						*
*	playback once using CIAB Timer A	*
*		and empty sample		*
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
DMASET=	%1000001010000001
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

DMACON	= $DFF096	; DMA control
AUD0LCH = $DFF0A0  	; table address HI
AUD0LCL = AUD0LCH+2  	; table address LO
AUD0LEN = AUD0LCH+4   	; table length
AUD0PER = AUD0LCH+6     ; read in rate
AUD0VOL = AUD0LCH+8    	; loudness level

TICKS = 45	; ~1 raster

	SECTION	MAIN, CODE

START:

;--- Store Old Register Settings ---

	MOVEM.L	D0-D7/A0-A6,-(SP)

	LEA	$DFF000,A6

MAIN:
	MOVE.L  #SAMPLE_1,$A0(A6)			; table beginning
	MOVE.W  #SAMPLE_1_LEN,$A4(A6)	; table length in word
	MOVE.W  #424,$A6(A6)			; period (C)
	MOVE.W  #64,$A8(A6)			; loudness level (volume)
	MOVE.W  #DMASET,$96(A6)   		; start DMA (Sound)

	BSR.B	WAIT_CIAB_TA			; wait 1 raster

.EMPTY_SAMPLE					; load empty sample
	MOVE.L	#SAMPLE_E,$A0(A6)
	MOVE.W	#SAMPLE_E_LEN,$A4(A6)
	
LEFTMOUSE
	BTST	#6,$BFE001
	BNE.S	LEFTMOUSE

**** EXIT - RESTORE OLD REG SETTINGS ****

	LEA	$DFF000,A6
	
	MOVE.W #$0001,$96(A6)
	
	MOVEM.L (SP)+,D0-D7/A0-A6

	RTS

WAIT_CIAB_TA
	LEA	$BFD000,A4
	MOVE.B	$E00(A4),D0
	MOVE.B	#%0001000,$E00(A4)	; cra - one-shot mode
	MOVE.B	#%0111111,$D00(A4)	; icr - disable all
	MOVE.B	#TICKS,   $400(A4)	; talo - timer low (about 3 scanlines)
	MOVE.B	#0,$500(A4)		; tahi - start counting
.WAIT
	BTST.B	#0,$d00(A4)		; check timer A finish
	BEQ.B	.WAIT	
	RTS


WAITVB:
	TST.B	$DFF005
	BEQ.B	WAITVB
.LOOP
	TST.B	$DFF005
	BNE.S	.LOOP
	RTS

	SECTION	MUSIC, DATA_C

	CNOP	0,2		; align data on a word boundary

	INCDIR	"dh2:amiga-playground/resources/sounds/"
SAMPLE_1:
	INCBIN	"Alien"
SAMPLE_1_LEN=(*-SAMPLE_1)/2

SAMPLE_E:
	DCB.W	1	
SAMPLE_E_LEN=(*-SAMPLE_E)/2


	IF (SAMPLE_1_LEN*2)<>7800
	FAIL "SAMPLE NOT VALID"
	ENDC

	END

PAL Timing Reference

Timer A tick = ~1,41 us
Raster time  = ~63,9996 us

Time to wait for 1 raster =  TA tick * 1 / Raster time = 45.39

