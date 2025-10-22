*********************************************
*
*	CIAA/CIAB TOD ALARM example
*
*********************************************

; Run this example and wait 5.12 secs. Then type:
; m Status
; output should be $12344321; this mean interrupt was properly triggered


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

;--- Disable Intena/Intreq/Dmacon ---

	MOVE.L	#$7FFF7FFF,$9A(A6)	; disable INTENA/INTREQ

;--- Set Register Settings ---

	BSR	WAITVB			; Wait for VBLANK

;--- Program Interrupt ---

	MOVE.L	$68.W,OldInter		; store old INTER PTR

	MOVE.L	#INTER,$68.W		; set interrupt pointer
	MOVE.W	#INTENA,$9A(A6)		; set bit of INTENA

	BSR.W	CIAA		; call CIAA TOD routine

.WAITMOUSE
	BTST.B	#6,$BFE001
	BNE.B	.WAITMOUSE



**** EXIT - RESTORE OLD REG SETTINGS ****

	LEA	$DFF000,A6

	MOVE.W	#$7FFF,$9A(A6)		; disable interrupts	

	BSR.S	WAITVB

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
	LEA	$DFF000,A6	

	BTST	#3,$1F(A6)		; check level 2 interrupt
	BEQ.B	.EXIT

	LEA	$BFE001,A1		; acknowledge interrupt
	MOVE.B	$D00(A1),D0		; read icr to clear interrupt
	BTST	#2,D0			; check if is TOD ALARM event
	BEQ.B	.EXIT

.ALARMEV
	MOVE.L	#$12344321,Status
.EXIT
	MOVE.W	#$0008,$9C(A6)		; clear interrupt request
	MOVEM.L	(SP)+,D0-D7/A0-A6
	RTE	

CIAA:
	LEA	$BFE001,A1	; CIAA base

	BSET.B	#7,$F00(A1)	; set alarm (crb bit 7)

	MOVE.B	#0,$A00(A1)	; Alarm TODHI
	MOVE.B	#1,$900(A1)	; Alarm TODMID
	MOVE.B	#0,$800(A1)	; Alarm TODLOW stops the clock (Event LSB)
	
	MOVE.B	#%10000100,$D00(A1)	; enable ALARM bit (icr)

	BCLR.B	#7,$F00(A1)	; clear alarm (crb bit 7)

	MOVE.B	#0,$A00(A1)	; reset TODHI
	MOVE.B	#0,$900(A1)	; reset TODMID	
	MOVE.B	#0,$800(A1)	; starts the clock (Event LSB)
	RTS


OldIntena:
	DC.W	0
OldInter:
	DC.L	0
Status:
	DC.L	0

	END








CIAA / CIAB TOD tick duration

CIAA TOD is clocked by the VSync pulse (one frame) in most models, 
so the tick duration depends on the system. It is used by the timer.device

------------------------------------------------

System	Vsync Frequency	Timer per tick

PAL	50 Hz		20 us (0.02s)
NTSC	59.94 Hz	16.683 us (0.01668s)

------------------------------------------------

CIAB TOD is clocked by the HSync (raster line) and it is used by the
graphics.library; thus a tick is related to a raster line duration.

------------------------------------------------

System	Timer per tick (equivalent of raster line duration)

PAL	63.9996 us
NTSC	63.5556 us

------------------------------------------------

About latching fuction

If you need to read ONLY one register, there's no need to read
TODHI only for latching the value.
Latching function ensure that reading the TOD value keeps consistent through
the next reads from the TO* registers.
For instance, let's say that a certain moment the TOD Clock value is $01FF.
If you read the TODLO, you would see the output $FF, then you read the TODMID
register, but meanwhile the clock increased by 1 tick ($0200), so you would
get as output $02; Combining the 2 values you would get $02FF, which is wrong!
The MSB Event (read TODHI) instead latch the 24 bit value, so the value you
get on the next read is blocked until you read the TODLOW register, 
which unblock the value.
Notice that, regardless the latch function, the TOD clock still continue to 
work.

	
CIAA Address Map
---------------------------------------------------------------------------
 Byte    Register                  Data bits
Address    Name     7     6     5     4     3     2     1    0
---------------------------------------------------------------------------
BFE001    pra     /FIR1 /FIR0  /RDY /TK0  /WPRO /CHNG /LED  OVL
BFE101    prb     Parallel port
BFE201    ddra    Direction for port A (BFE001);1=output (set to 0x03)
BFE301    ddrb    Direction for port B (BFE101);1=output (can be in or out)
BFE401    talo    CIAA timer A low byte (.715909 Mhz NTSC; .709379 Mhz PAL)
BFE501    tahi    CIAA timer A high byte
BFE601    tblo    CIAA timer B low byte (.715909 Mhz NTSC; .709379 Mhz PAL)
BFE701    tbhi    CIAA timer B high byte
BFE801    todlo   50/60 Hz event counter bits 7-0 (VSync or line tick)
BFE901    todmid  50/60 Hz event counter bits 15-8
BFEA01    todhi   50/60 Hz event counter bits 23-16
BFEB01            not used
BFEC01    sdr     CIAA serial data register (connected to keyboard)
BFED01    icr     CIAA interrupt control register
BFEE01    cra     CIAA control register A
BFEF01    crb     CIAA control register B

Note:  CIAA can generate interrupt INT2.


CIAB Address Map
---------------------------------------------------------------------------
 Byte     Register                   Data bits
Address     Name     7     6     5     4     3     2     1     0
---------------------------------------------------------------------------
BFD000    pra     /DTR  /RTS  /CD   /CTS  /DSR   SEL   POUT  BUSY
BFD100    prb     /MTR  /SEL3 /SEL2 /SEL1 /SEL0 /SIDE  DIR  /STEP
BFD200    ddra    Direction for Port A (BFD000);1 = output (set to 0xFF)
BFD300    ddrb    Direction for Port B (BFD100);1 = output (set to 0xFF)
BFD400    talo    CIAB timer A low byte (.715909 Mhz NTSC; .709379 Mhz PAL)
BFD500    tahi    CIAB timer A high byte
BFD600    tblo    CIAB timer B low byte (.715909 Mhz NTSC; .709379 Mhz PAL)
BFD700    tbhi    CIAB timer B high byte
BFD800    todlo   Horizontal sync event counter bits 7-0
BFD900    todmid  Horizontal sync event counter bits 15-8
BFDA00    todhi   Horizontal sync event counter bits 23-16
BFDB00            not used
BFDC00    sdr     CIAB serial data register (unused)
BFDD00    icr     CIAB interrupt control register
BFDE00    cra     CIAB Control register A
BFDF00    crb     CIAB Control register B

Note:  CIAB can generate INT6.

------------------------------------------------

REG  NAME
---  ----
 8   LSB Event    E7   E6   E5   E4   E3   E2   E1   E0
 9   Event 8-15   E15  E14  E13  E12  E11  E10  E9   E8
 A   MSB Event    E23  E22  E21  E20  E19  E18  E17  E16

WRITE
CRB7 = 0
CRB7 = 1 ALARM
		
------------------------------------------------
CIAA
TOD (Time of Day) Clock: The main 50/60 Hz timer used by the timer.device 
to provide system time and clock events. 

CIAB
TOD (Time of Day) Clock: Used by the graphics library to sync events 
to the video beam by counting at the horizontal sync rate. 
	
A specific sequence of events must be followed for proper setting and
reading of TOD.  TOD is automatically stopped whenever a write to the
register occurs.  The clock will not start again until after a write to
the  LSB event  register.  This assures that TOD will always start at the
desired time.

Since a carry from one stage to the next can occur at any time with
respect to a read operation, a latching function is included to keep all
TOD information constant during a read sequence. All TOD registers latch
on a read of  MSB event  and remain latched until after a read of
 LSB event . The TOD clock continues to count when the output registers
are latched. If only one register is to be read, there is no carry problem
and the register can be read "on the fly" provided that any read of
 MSB event  is followed by a read of  LSB Event  to disable the latching.

------------------------------------------------

ICR (write)		CIAA base + $D00


REG  NAME       D7   D6   D5   D4   D3   D2   D1  D0
---  ----       ---- ---- ---- ---- ---- ---- --- ---
D     ICR       S/C   x    x   FLG  SP   ALRM TB  TA

ICR (read)		CIAA base + $D00

REG  NAME       D7   D6   D5   D4   D3   D2   D1  D0
---  ----       ---- ---- ---- ---- ---- ---- --- ---
D    ICR        IR    0    0   FLG  SP   ALRM TB  TA


------------------------------------------------

CRB				CIAA base + $F00

   CONTROL REGISTER B:

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

