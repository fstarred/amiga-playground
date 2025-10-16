*********************************************
*
*	CIAB Timer A One-Shot countdown
*
*********************************************

; This example show how to use CIAB Timer A in one-shot mode
; After you run this, on Asm-One type:
; m lines
; to see the lines occurred from the timer A start
; a raster line should take ~45.4 timer ticks
; thus 454 ticks should return $0A (10) lines

STARTLINE=$2C
TIME=454			; ticks

START:
	MOVE.L	4.W,A6
	JSR	-$84(A6)	; Forbid - prevent multitasking
	JSR	-$78(A6)	; Disable - Prevents system interrupts

	LEA	$DFF000,A1
	BSR.B	.DEBUG_LINE

	LEA	$BFD000,A4		; CIAB base
	MOVE.B	$E00(A4),D0		; CIAB Control register A (cra)
	ANDI.B	#%11000000,D0		; reset bits 0 - 5
	ORI.B	#%00001000,D0		; One-Shot mode
	MOVE.B	D0,$E00(A4)		; set cra
	MOVE.B	#%01111110,$D00(A4)	; disable all but TA interrupts (icr)
	MOVE.B	#(TIME&$FF),$400(A4)	; TIME lower byte value
	MOVE.B	#(TIME>>8),$500(A4)	; TIME upper byte value
	BSET.B	#0,$E00(A4)		; Start Timer A (* not sure if needed)
.WAIT
	BTST.B	#0,$D00(A4)	; check Timer A is finished
	BEQ.B	.WAIT

	MOVE.L	4(A1),D0	; VPOS / VHPOSR
	ANDI.L	#$1FF00,D0	; get vertical position
	SUB.W	#STARTLINE<<8,D0	; sub curr line with start line
	MOVE.W	D0,lines	; store the result


	MOVE.L	4.W,A6
	JSR	-$7E(A6)	; Enable - permit system interrupts to resume
	JSR	-$8A(A6)	; Permit - restore multitasking

.WAITMOUSE
	BTST.B	#6,$BFE001
	BNE.B	.WAITMOUSE

	RTS

.DEBUG_LINE
	MOVE.L	4(A1),D0	; VPOS / VHPOSR
	ANDI.L	#$1FF00,D0	; get vertical position
	CMPI.L	#STARTLINE<<8,D0	; wait for STARTLINE
	BNE.B	.DEBUG_LINE

	RTS

lines
	DC.W	0

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


