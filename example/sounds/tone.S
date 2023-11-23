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
DMASET=	%1000001000000001 ($8201)
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

RUN:                 	; * Produce a simple tone

	LEA	$DFF000,A1

	MOVE.L  #TABLE,$A0(A1)			; table beginning
	MOVE.W  #(TABLE_END-TABLE)/2,$A4(A1)	; table length in word
	MOVE.W  #212,$A6(A1)			; period (C)
	MOVE.W  #64,$A8(A1)			; loudness level (volume)
	MOVE.W  #DMASET,$96(A1)   		; start DMA (Sound)
	RTS
STOP:
	MOVE	#1,$96(A1)			; turn off tone
	RTS

TABLE:  				; 16 bit sample - TRIANGLE
	DC.B	0, 32, 64, 96, 128, 96, 64, 32
	DC.B	0,-32,-64,-96,-127,-96,-64,-32
TABLE_END

	PRINTT	"TYPE 'J STOP' TO TURN OFF SOUND"

;   Table 5-7: Equal-tempered Octave for a 16 Byte Sample

;  NTSC     PAL             Ideal   Actual NTSC  Actual PAL
; Period  Period   Note   Frequency  Frequency   Frequency
; ------  ------   ----   --------- -----------  ----------
;  254     252      A       880.0      880.8       879.7
;  240     238      A#      932.3      932.2       931.4
;  226     224      B       987.8      989.9       989.6
;  214     212      C      1046.5     1045.4      1045.7
;  202     200      C#     1108.7     1107.5      1108.4
;  190     189      D      1174.7     1177.5      1172.9
;  180     178      D#     1244.5     1242.9      1245.4
;  170     168      E      1318.5     1316.0      1319.5
;  160     159      F      1396.9     1398.3      1394.2
;  151     150      F#     1480.0     1481.6      1477.9
;  143     141      G      1568.0     1564.5      1572.2
;  135     133      G#     1661.2     1657.2      1666.8

; To generate the tones in the lower octaves, there are two methods you can use, 
; doubling the period value or doubling the sample size.



; TIME    SINE    SQUARE   TRIANGLE
; ----    ----    ------   --------
;   0        0      100        0
;   1       39      100       20
;   2       75      100       40
;   3      103      100       60
;   4      121      100       80
;   5      127      100      100
;   6      121      100       80
;   7      103      100       60
;   8       75      100       40
;   9       39      100       20
;  10        0     -100        0
;  11      -39     -100      -20
;  12      -75     -100      -40
;  13     -103     -100      -60
;  14     -121     -100      -80
;  15     -127     -100     -100
;  16     -121     -100      -80
;  17     -103     -100      -60
;  18      -75     -100      -40
;  19      -39     -100      -20


;       DMACON  Register
;       ---------------
; 
; Bit     Name      Function
; ---     ----      --------
; 15    SET/CLR   When this bit is written as a 1, it
; 	sets any bit in DMACONW for which
; 	the corresponding bit position is
; 	also a 1, leaving all other bits alone.
; 
; 9    DMAEN     Only while this bit is a 1 can
; 	any direct memory access occur.
; 
; 3    AUD3EN    Audio channel 3 enable.
; 2    AUD2EN    Audio channel 2 enable.
; 1    AUD1EN    Audio channel 1 enable.
; 0    AUD0EN    Audio channel 0 enable.
