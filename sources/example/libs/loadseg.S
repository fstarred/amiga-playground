*********************************
*				*
*	LoadSeg example		*
*				*
*********************************


DEBUG		;decomment to unload seg instead of jmp

*** Remember to replace <hunk> with hunk filename! ***

; look at http://amigadev.elowar.com/ Includes_and_Autodocs_2


	INCDIR	"INCLUDE:"
	INCLUDE	"exec/exec.i"
	INCLUDE	"exec/exec_lib.i"
	INCLUDE	"libraries/dos.i"
	INCLUDE	"libraries/dos_lib.i"


LOADGAME:
	MOVE.L	4.W,A6			;GET EXECBASE
	LEA	DosLibName(PC),A1	;POINTER TO 'DOS.LIBRARY'
	CALLEXEC	OldOpenLibrary
	TST.L	D0			;IF D0 = 0 THEN LIBRAY OPEN FAILED
	BEQ.B	PROBLEM

	MOVE.L	D0,DosLibPtr		;STORE DOS LIBRARY TO VAR
	MOVE.L	D0,A6			;PUT DOS.LIBRARY BASE ADDRESS IN A6
	
	LEA	Filename(PC),A0		;GET FILENAME PC RELATIVE
	MOVE.L	A0,D1			;MOVE FILENAME INTO D1
	CALLEXEC	LoadSeg
	TST.L	D0
	BEQ.B	PROBLEM
	LSL.L	#2,D0			;MULTIPLY D0 * 4 TO GET CORRECT ADDRESS
	MOVE.L	D0,A0			;MOVE ADDRESS INTO A0

	IFND	DEBUG
	MOVEQ	#1,D0
	MOVE.L	A0,D1
	JMP	4(A0)			;EXECUTE FILE LOADED BY LOADSEG
	ELSE
	CALLEXEC	UnLoadSeg
	ENDC

	BRA.B	CLOSELIB

PROBLEM:
	MOVEQ	#0,D0
	RTS

CLOSELIB:
	MOVE.L	DosLibPtr,A1
	MOVE.L	4.W,A6			;GET EXECBASE
	CALLEXEC	CloseLibrary
	RTS

;-----------------------------------------------
DosLibName:
	DOSNAME

Filename:
	dc.b	'df0:<hunk>',0
	EVEN

;*** WAIT VERTICAL BLANK ***

DosLibPtr	DC.L	0

