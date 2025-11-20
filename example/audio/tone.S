*****************************************
*					*
*	TONE GENERATION (PAL)		*
*					*
*****************************************

DMACON	= $DFF096	; DMA control
AUD0LCH = $DFF0A0  	; table address HI
AUD0LCL = AUD0LCH+2  	; table address LO
AUD0LEN = AUD0LCH+4   	; table length
AUD0PER = AUD0LCH+6     ; read in rate
AUD0VOL = AUD0LCH+8    	; loudness level

; A = AGNUS, D = DENISE, P = PAULA

;DMACON     096      W     A D P   DMA control write (clear or set)
;DMACONR    002      R     A   P   DMA control (and blitter status) read
DMASET=	%1000001000000001
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

; type 'j' for playing tone
; type 'j stop' for stop playing tone

A	= 403
Ad	= 380
B	= 359
C	= 339
Cd	= 320
D	= 302
Dd	= 285
E	= 269
F	= 254
Fd	= 240
G	= 226
Gd	= 214


NOTE = C
VOLUME = 32

	SECTION	MAIN, CODE

RUN:                 	; * Produce a steady tone

	LEA	$DFF000,A1

	MOVE.L  #TRIANGLE,$A0(A1)			; sample data
	MOVE.W  #(TRIANGLE_END-TRIANGLE)/2,$A4(A1)	; sample length in word
	MOVE.W  #NOTE,$A6(A1)			; period
	MOVE.W  #VOLUME,$A8(A1)			; loudness level (volume)
	MOVE.W  #DMASET,$96(A1)   		; start DMA (Sound)

.LMOUSE
	BTST	#6,$BFE001
	BNE.B	.LMOUSE

STOP:
	MOVE	#1,$96(A1)			; turn off tone
	RTS

	SECTION AUDIO, DATA_C

	CNOP	0,2				; align data in a word boundary

TRIANGLE:  				
	DC.B	0,  20,  40,  60,  80, 100,  80,  60,  40,  20
	DC.B	0, -20, -40, -60, -80,-100, -80, -60, -40, -20
TRIANGLE_END

SINE:  					
	DC.B	0,  39,  75, 103, 121, 127, 121, 103,  75,  39
	DC.B	0, -39, -75,-103,-121,-127,-121,-103, -75, -39
SINE_END

SQUARE:
	DC.B	100, 100, 100, 100, 100, 100, 100, 100, 100, 100
	DC.B	-100,-100,-100,-100,-100,-100,-100,-100,-100,-100
SQUARE_END

	END











   Table 5-7: Equal-tempered Octave for a 16 Byte Sample

  NTSC     PAL             Ideal   Actual NTSC  Actual PAL
 Period  Period   Note   Frequency  Frequency   Frequency
 ------  ------   ----   --------- -----------  ----------
  254     252      A       880.0      880.8       879.7
  240     238      A#      932.3      932.2       931.4
  226     224      B       987.8      989.9       989.6
  214     212      C      1046.5     1045.4      1045.7
  202     200      C#     1108.7     1107.5      1108.4
  190     189      D      1174.7     1177.5      1172.9
  180     178      D#     1244.5     1242.9      1245.4
  170     168      E      1318.5     1316.0      1319.5
  160     159      F      1396.9     1398.3      1394.2
  151     150      F#     1480.0     1481.6      1477.9
  143     141      G      1568.0     1564.5      1572.2
  135     133      G#     1661.2     1657.2      1666.8

 To generate the tones in the lower octaves, there are two methods you can use, 
 doubling the period value or doubling the sample size.



 TIME    SINE    SQUARE   TRIANGLE
 ----    ----    ------   --------
   0        0      100        0
   1       39      100       20
   2       75      100       40
   3      103      100       60
   4      121      100       80
   5      127      100      100
   6      121      100       80
   7      103      100       60
   8       75      100       40
   9       39      100       20
  10        0     -100        0
  11      -39     -100      -20
  12      -75     -100      -40
  13     -103     -100      -60
  14     -121     -100      -80
  15     -127     -100     -100
  16     -121     -100      -80
  17     -103     -100      -60
  18      -75     -100      -40
  19      -39     -100      -20


       DMACON  Register
       ---------------
 
 Bit     Name      Function
 ---     ----      --------
 15    SET/CLR   When this bit is written as a 1, it
 	sets any bit in DMACONW for which
 	the corresponding bit position is
 	also a 1, leaving all other bits alone.
 
 9    DMAEN     Only while this bit is a 1 can
 	any direct memory access occur.
 
 3    AUD3EN    Audio channel 3 enable.
 2    AUD2EN    Audio channel 2 enable.
 1    AUD1EN    Audio channel 1 enable.
 0    AUD0EN    Audio channel 0 enable.
 
clock constant 
NTSC = 3579545 ticks per second
 PAL = 3546895 ticks per second
 
                 desired interval     clock constant
   Period value = ---------------- = ------------------
                   clock interval    samples per second


Period value = clock / (sample len in bytes * Hz)

Note Frequency (Ftarget) PAL Period (3546895 / (Fª20)) NTSC Period (3579545 / (Fª20))
---- --------- --------------------------------------- ------------------------------
A4   440.00 Hz              round(403,06)=403                round(406,77)=407
A#4  466.16 Hz              round(380,44)=380                round(383,94)=384
B4   493.88 Hz              round(359,08)=359                round(362,39)=362
C5   523.25 Hz              round(338,93)=339                round(342,05)=342
C#5  554.37 Hz              round(319,90)=320                round(322,85)=323
D5   587.33 Hz              round(301,95)=302                round(304,73)=305
D#5  622.25 Hz              round(285,01)=285                round(287,63)=288
E5   659.26 Hz              round(269,01)=269                round(271,48)=271
F5   698.46 Hz              round(253,91)=254                round(256,25)=256
F#5  739.99 Hz              round(239,66)=240                round(241,86)=242
G5   783.99 Hz              round(226,21)=226                round(228,29)=228
G#5  830.61 Hz              round(213,51)=214                round(215,48)=215

