; Enter the debugger and AddWatch (A key+A)  on the BUFFER of String type

	MOVE.L	#655, D0
	LEA	BUFFER, A0

	DIVU	#100, D0
	ADD.B	#'0', D0
	MOVE.B	D0, (A0)+
	CLR.W	D0
	SWAP	D0
	DIVU	#10, D0
	ADD.B	#'0', D0
	MOVE.B	D0, (A0)+
	SWAP	D0
	ADD.B	#'0', D0
	MOVE.B	D0, (A0)+
	RTS

BUFFER
	DC.L 0
