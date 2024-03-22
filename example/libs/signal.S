*****************************************
*					*
*	Call to signal example		*
*					*
*****************************************

OpenLibrary	=-408
CloseLibrary	=-414
AllocSignal	=-330
FreeSignal	=-336
FindTask	=-294

START:
	MOVEM.L	D0-D7/A0-A6,-(SP)

	MOVE.L	$4.W,A6

	MOVEQ	#-1,D0
	JSR	AllocSignal(A6)
	TST.L	D0
	BMI	PROBLEM

	MOVE.B	D0,SignalNum

	SUB.L	A1,A1
	JSR	FindTask(A6)

	MOVE.B	SignalNum,D0
	JSR	FreeSignal(A6)	

;	LEA	Graphname(PC),A1
;	MOVEQ	#0,D0
;	JSR	OpenLibrary(A6)
;	MOVE.L	D0,A6
;	MOVE.L	D0,GraphLibPtr
;	BEQ	PROBLEM

CLOSELIB:
;	MOVE.L	GraphLibPtr(PC),A1
;	MOVE.L	$4.W,A6
;	JSR	CloseLibrary(A6)


PROBLEM:
	MOVEM.L (SP)+,D0-D7/A0-A6
	RTS

SignalNum:
	DC.B	0

GraphName:
	dc.b	'graphics.library',0
	EVEN
GraphLibPtr:
	dc.l	0
ScreenPtr:
	dc.l	0


