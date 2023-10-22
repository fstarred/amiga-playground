*********************************
*				*
*	LoadSeg example		*
*				*
*********************************


DEBUG		;decomment to unload seg instead of jmp

*** Remember to replace <hunk> with hunk filename! ***

; look at http://amigadev.elowar.com/ Includes_and_Autodocs_2

;*****************
;*   Constants   *
;*****************


OldOpenLibrary	= -408
CloseLibrary	= -414
LoadSeg		= -150
UnLoadSeg	= -156


LOADGAME:
	MOVE.L	4.W,A6			;GET EXECBASE
	LEA	DOSLIB(PC),A1		;POINTER TO 'DOS.LIBRARY'
	JSR	OldOpenLibrary(A6)	;OPEN DOS.LIBRARY
	TST.L	D0			;IF D0 = 0 THEN LIBRAY OPEN FAILED
	BEQ.B	PROBLEM

	MOVE.L	D0,DosLibPtr		;STORE DOS LIBRARY TO VAR
	MOVE.L	D0,A6			;PUT DOS.LIBRARY BASE ADDRESS IN A6
	
	LEA	FILENAME(PC),A0		;GET FILENAME PC RELATIVE
	MOVE.L	A0,D1			;MOVE FILENAME INTO D1
	JSR	LOADSEG(A6)		;CALL LOADSEG
	TST.L	D0
	BEQ.B	PROBLEM
	LSL.L	#2,D0			;MULTIPLY D0 * 4 TO GET CORRECT ADDRESS
	MOVE.L	D0,A0			;MOVE ADDRESS INTO A0

	IFND	DEBUG
	MOVEQ	#1,D0
	MOVE.L	A0,D1
	JMP	4(A0)			;EXECUTE FILE LOADED BY LOADSEG
	ELSE
	JSR	UNLOADSEG(A6)
	ENDC

	BRA.B	CLOSELIB

PROBLEM:
	MOVEQ	#0,D0
	RTS

CLOSELIB:
	MOVE.L	DosLibPtr,A1
	MOVE.L	4.W,A6			;GET EXECBASE
	JSR	CloseLibrary(A6)
	RTS

;-----------------------------------------------
doslib:
	dc.b	'dos.library',0


filename:
	dc.b	'df0:<hunk>',0
	EVEN

;*** WAIT VERTICAL BLANK ***

DosBase		DC.L	0
DosLibPtr	DC.L	0

