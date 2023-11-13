************************************
*				   *
*    Call to intuition example	   *
*				   *
************************************

OpenLibrary	= -408
CloseLibrary	= -414
DisplayBeep	= -96
OpenWindow	= -204

SCR_WIDTH=320
SCR_HEIGHT=256

START:
	MOVEM.L	D0-D7/A0-A6,-(SP)

	MOVE.L	$4.W,A6
	LEA	Intuiname(PC),A1
	MOVEQ	#0,D0
	JSR	OpenLibrary(A6)
	MOVE.L	D0,A6
	MOVE.L	D0,IntuiLibPtr
	BEQ	PROBLEM

	JSR	BEEP
;	JSR	OPENWIN

.CLOSE
	MOVE.L	IntuiLibPtr(PC),A1
	MOVE.L	$4.W,A6
	JSR	CloseLibrary(A6)
PROBLEM:
	MOVEM.L (SP)+,D0-D7/A0-A6
	RTS

BEEP:
	SUB.L	A0,A0
	JSR	DisplayBeep(A6)
	RTS

OPENWIN:
	LEA	mynewwindow(PC),A0
	JSR	OpenWindow(A6)
	TST.L	D0
	BEQ	PROBLEM
	RTS
	

IntuiName:
	dc.b	'intuition.library',0
IntuiLibPtr:
	dc.l	0
ScreenPtr:
	dc.l	0
MyNewWindow: 
	dc.w 0,12 
	dc.w 200,100 
	dc.b -1,-1 
	dc.l $200
	dc.l 8!4!2!1!$1000
	dc.l 0 
	dc.l 0 
	dc.l WindowTitle 
	dc.l 0 
	dc.l 0 
	dc.w 80,24 
	dc.w -1,-1 
	dc.w 1

WindowTitle:
	dc.b	'hello',0

