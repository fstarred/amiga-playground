*********************************************
*
*	CIAB Timer A Continuos with interrupt
*
*********************************************

; Run this example, the Status counter increase every VSYNC event
; 1 second wait, Status = ~50 (on PAL)

TIME=14210 ; (PAL 45.4 ticks * 313 lines (one VSYNC))

;INTENA     09A      W       P    Interrupt enable bits (clear or set bits)
;INTENAR    01C      R       P    Interrupt enable bits (read)
INTENA=	%1110000000000000
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
	
	SECTION	PROGRAMCODE,CODE
	
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

	MOVE.L	$78.W,OldInter		; store old INTER PTR

	MOVE.L	#INTER,$78.W		; set interrupt pointer
	MOVE.W	#INTENA,$9A(A6)		; set bit of INTENA
	

	BSR.W	CIAB

.WAITMOUSE
	BTST.B	#6,$BFE001
	BNE.B	.WAITMOUSE

	BCLR.B	#0,$BFDE00
	

**** EXIT - RESTORE OLD REG SETTINGS ****

	LEA	$DFF000,A6

	MOVE.W	#$7FFF,$9A(A6)		; disable interrupts	

	BSR.S	WAITVB

	MOVE.L	OldInter(PC),$78.W	; restore inter pointer

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

	BTST	#13,$1F(A6)			; check is an external interrupt
	BEQ.B	.EXIT

	MOVE.B	$BFDD00,D0			; Acknowledge the interrupt (icr)

	ADDI.L	#1,Status

.EXIT
	MOVE.W	#$2000,$9C(A6)		; clear interrupt request
	MOVEM.L	(SP)+,D0-D7/A0-A6
	RTE

CIAB:
	LEA	$BFD000,A1

	MOVE.B	$E00(A1),D0		; CIAB cra
	ANDI.B	#%11000000,D0		; disable all but SPMODE
	ORI.B	#%00000000,D0		; continuos
	MOVE.B	D0,$E00(A1)		

	MOVE.B	#%10000001,$D00(A1)	; icr; set TA (bit 0)

	MOVE.B	#(TIME&$FF),$400(A1)
	MOVE.B	#(TIME>>8),$500(A1)
START_TA:
	BSET.B	#0,$E00(A1)		; start TA
	RTS
	

OldIntena:
	DC.W	0
OldInter:
	DC.L	0
Status:
	DC.L	0
	
	END


ICR (write)	- BFDD00

*********************************************************

REG  NAME       D7   D6   D5   D4   D3   D2   D1  D0
---  ----       ---- ---- ---- ---- ---- ---- --- ---
D     ICR       S/C   x    x   FLG  SP   ALRM TB  TA


CRA CONTROL REGISTER A/B - BFDE00

  BIT  NAME     FUNCTION
  ---  ----     --------
   0   START    1 = start Timer B, 0 = stop Timer B.
                    This bit is automatically reset (= 0) when
                    underflow occurs during one-shot mode.
   1   PBON     1 = Timer B output on PB7, 0 = PB7 is normal
                    operation.
   2   OUTMODE  1 = toggle, 0 = pulse.
   3   RUNMODE  1 = one-shot mode, 0 = continuous mode.
   4   LOAD     1 = force load (this is a strobe input, there is no
                    data storage;  bit 4 will always read back a
                    zero and writing a 0 has no effect.)
  6,5  INMODE   Bits CRB6 and CRB5 select one of four possible
                input modes for Timer B, as follows:

                CRB6  CRB5   Mode Selected
                ----  ----   ---------------------------------------
                 0     0     Timer B counts 02 pulses
                 0     1     Timer B counts positive CNT transitions
                 1     0     Timer B counts Timer A underflow pulses
                 1     1     Timer B counts Timer A underflow pulses
                               while CNT pin is held high.

   7   ALARM     1 = writing to TOD registers sets Alarm
                 0 = writing to TOD registers sets TOD clock.
                     Reading TOD registers always reads TOD clock,
                     regardless of the state of the Alarm bit.


REMINDER

control bit (CRx3) selects either timer mode.  In one-shot mode, the
timer will count down from the latched value to zero, generate an
interrupt, reload the latched value, then stop. In continuous mode, the
timer will count down from the latched value to zero, generate an
interrupt, reload the latched value, and repeat the procedure continuously.

* In one-shot mode, a write to timer-high (register 5 for timer A, register
7 for Timer B) will transfer the timer latch to the counter and initiate
counting regardless of the start bit.

VPOS / VPOSHR	- DFF004 / DFF006

   VPOSR:     Bit 15       Long frame/short frame.  0=short frame
              Bits 14-1    Chip ID code.  Do not depend on value!
              Bit 0        V8 (most significant bit of vertical position)

   VHPOSR:    Bits 15-8    V7-V0 (vertical position)
              Bits 7-0     H8-H1 (horizontal position)

Some tech details about timing

-----------------------------------------
System Frequencies (Master Oscillator)

Standard	System Clock Frequency

PAL		28.375160 MHz
NTSC		28.636360 MHz
-----------------------------------------


-----------------------------------------
Raster Line Duration

Standard	Cycles per Raster Line	Raster Line Duration

PAL		1816 cycles		~63.9996 us (1816/SCF)
NTSC		1820 cycles		~63.5555 us (1820/SCF)

-----------------------------------------


-----------------------------------------
CIA Timer A Tick Duration

Standard	CIA Clock Frequency	CIA Tick Duration

PAL		~709,379		~1.40968 us (1/CCF)
NTSC		~715.909		~1.39683 us (1/CCF)	
-----------------------------------------


-----------------------------------------
Raster line duration in ticks

Standard	Ticks
PAL		45.4 (RLD/CTD)
NTSC		45.5 (RLD/CTD)

-----------------------------------------
