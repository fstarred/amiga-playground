*********************************************
*
*	CIAA/CIAB TOD example
*
*********************************************

; CIAA / CIAB TOD example

; Run CIAA and wait ~5.12 secs for finish
; Run CIAB and wait ~4 secs for finish


START:
	MOVE.L	4.W,A6
	JSR	-$84(A6)	; Forbid - prevent multitasking
	JSR	-$78(A6)	; Disable - Prevents system interrupts

	BSR.B	CIAA		; call CIAA TOD routine
;	BSR.B	CIAB		; call CIAB TOD routine

	MOVE.L	4.W,A6
	JSR	-$7E(A6)	; Enable - permit system interrupts to resume
	JSR	-$8A(A6)	; Permit - restore multitasking

	RTS
	

CIAA:
	LEA	$BFE001,A1	; CIAA base
	MOVE.B	#0,$A00(A1)	; reset TODHI
	MOVE.B	#0,$900(A1)	; reset TODMID
	MOVE.B	#0,$800(A1)	; reset TODLOW and starts the clock (Event LSB)
.WAITCIA
	MOVE.B	$A00(A1),D0	; read TODHI to latch the 24 bit value (MSB Ev)
	MOVE.B	$800(A1),D0	; release the latch
	CMPI.B	#1,$900(A1)	; waits 256 VSYNC occurs (frames) - ~5.12s
	BCS.S	.WAITCIA
	RTS







CIAB:	
	LEA	$BFD000,A1	; CIAB base
	MOVE.B	#0,$A00(A1)	; reset TODHI
	MOVE.B	#0,$900(A1)	; reset TODMID
	MOVE.B	#0,$800(A1)	; reset TODLOW and starts the clock (Event LSB)
.WAITCIA:
	MOVE.B	$A00(A1),D0	; read TODHI to latch the 24 bit value (MSB Ev)
	MOVE.B	$800(A1),D0	; release the latch
	CMPI.B	#$F0,$900(A1)	; wait 61440 HSYNC occurs -  ~3.92s
	BCS.S	.WAITCIA
	RTS

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
