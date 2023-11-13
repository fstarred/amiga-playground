************************************
*
*	Call to libs example
*
*
************************************

OpenLibrary=-408
CloseLibrary=-414
AllocRaster=-492
FreeRaster=-498

SCR_WIDTH=320
SCR_HEIGHT=256

START:
	MOVEM.L	D0-D7/A0-A6,-(SP)

	MOVE.L	$4.W,A6
	LEA	Graphname(PC),A1
	MOVEQ	#0,D0
	JSR	OpenLibrary(A6)
	MOVE.L	D0,A6
	MOVE.L	D0,GraphLibPtr
	BEQ	PROBLEM

	MOVE.W	#SCR_WIDTH,D0
	MOVE.W	#SCR_HEIGHT,D1
	JSR	AllocRaster(A6)
	MOVE.L	D0,ScreenPtr
	BEQ	PROBLEM

	MOVE.L	GraphLibPtr(PC),A6
	MOVE.L	ScreenPtr,A0
	MOVE.L	#SCR_WIDTH,D0
	MOVE.L	#SCR_HEIGHT,D1
	JSR	FreeRaster(A6)

CLOSELIB:
	MOVE.L	GraphLibPtr(PC),A1
	MOVE.L	$4.W,A6
	JSR	CloseLibrary(A6)


PROBLEM:
	MOVEM.L (SP)+,D0-D7/A0-A6
	RTS

GraphName:
	dc.b	'graphics.library',0
	EVEN
GraphLibPtr:
	dc.l	0
ScreenPtr:
	dc.l	0


