************************************
*				   *
*    Call to intuition example	   *
*				   *
************************************


	INCDIR  INCLUDE:
	INCLUDE "exec/exec.i"
	INCLUDE "exec/exec_lib.i"
	INCLUDE "intuition/intuition.i"
	INCLUDE "intuition/intuition_lib.i"

START:
	MOVEM.L	D0-D7/A0-A6,-(SP)

	LEA	IntuiLibName(PC),A1
	MOVEQ	#0,D0
	CALLEXEC	OpenLibrary
	MOVE.L	D0,A6
	MOVE.L	D0, _IntuitionBase
	BEQ	problem

	JSR	BEEP

.close
	MOVE.L	_IntuitionBase(PC),A1
	CALLEXEC	CloseLibrary
problem:
	MOVEM.L (SP)+,D0-D7/A0-A6
	RTS

BEEP:
	SUB.L	A0,A0
	CALLINT DisplayBeep
	RTS

IntuiLibName	
	INTNAME
_IntuitionBase
	dc.l	0

