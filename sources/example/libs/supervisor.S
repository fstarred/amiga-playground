*********************************************
*
*
*	SUPERVISOR MODE FUNCTION
*
*
*********************************************

;
; WARN: don't run with ASM-One !!!
;
; try to debug with emulator and place some breakpoints at:
;
; $30000
; $50000
; $70000

SuperVisor = -$1E

START
	JMP	PROGRAM
	
PROGRAM	ORG	$30000
	MOVEM.L	D0-D7/A0-A6,-(SP)
	MOVE.L	4.W,A6
	LEA	SUPERUSER,A5
	JSR	SuperVisor(A6)
EXIT
	MOVEM.L	(SP)+, D0-D7/A0-A6
	RTS
SUPERUSER	ORG	$50000 			; UNDER SUPERUSER MODE
	MOVEM.L	D0-D7/A0-A6,-(SP)
	PEA	TVD
	MOVE.L	(A7)+,$24.W	; TRACE VECTOR
	EORI.W	#$8000,SR	; SET TRACE BIT
	MOVEM.L	(SP)+,D0-D7/A0-A6
	RTE			; EXIT SUPERUSER AND CLEAR T BIT ALSO
	
TVD	ORG	$70000
	MOVE.L	A0,-(SP)
	MOVE.L	(SP)+,A0
	RTE
END


