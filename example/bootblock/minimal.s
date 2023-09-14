;************************************************
;
;		BootBlock minimal example
;
;************************************************

WriteFlag = 1	; 1 to write bootblock

;*****************
;*   Constants   *
;*****************

DupLock= -96

	IF	WriteFlag=1
	AUTO	WS\BEGIN\0\2\CC\
	ENDC


	SECTION	FIRST,CODE_C

;*******  Boot block  *******

BEGIN:
	IF	WriteFlag=1
	DC.B	'DOS',0
	DC.L	0		; checksum
	DC.L	880
	ENDC
	
	IF WriteFlag=1
	MOVE.L	$0004.W,A6
	LEA	DOSNAME(PC),A1
	JSR	DupLock(A6)
	MOVE.L	D0,A0
	MOVE.L	22(A0),A0
	MOVEQ	#0,D0
	ENDC
	RTS

DOSNAME	DC.B 'dos.library'

END:

	DS.B	1024-(END-BEGIN)

	IF	END-BEGIN>1024
	FAIL
	ENDC
