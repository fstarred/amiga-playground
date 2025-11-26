*****************************************
*					*
*	Call to signal example		*
*					*
*****************************************

	INCDIR	"INCLUDE:"
	INCLUDE	"exec/exec.i"
	INCLUDE	"exec/exec_lib.i"


START:
	MOVEM.L	D0-D7/A0-A6,-(SP)

	MOVEQ	#-1,D0
	CALLEXEC	AllocSignal
	TST.L	D0
	BMI	.problem

	MOVE.B	D0,SignalNum

	SUB.L	A1,A1
	CALLEXEC	FindTask

	MOVE.B	SignalNum,D0
	CALLEXEC	FreeSignal

.problem:
	MOVEM.L (SP)+,D0-D7/A0-A6
	RTS

SignalNum:
	DC.B	0

