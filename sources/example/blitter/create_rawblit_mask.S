************************************
*				   *
*  Create a rawblit mask starting  *
*       from a standard one	   *
*				   *
************************************

; Before running, you must set: 
; DEPTH (normal value is between 1 to 6) 
; WIDTH (in bytes)
; SOURCE (place your original non-interleaved mask under SOURCE label)
; 
; Once task is finished, from Asm-One:
; WB <filename> \DEST\DEST_END


DEPTH=2
WIDTH=2

START

	LEA	SOURCE(PC),A0
	LEA	DEST(PC),A1

.LOOP
	MOVEQ	#DEPTH-1,D7
	MOVE.W	#WIDTH-1,D6	

	BRA.B	.LOOP3
.LOOP2
	MOVE.W	#WIDTH-1,D6		
	SUBI.W	#WIDTH,A0
.LOOP3
	MOVE.B	(A0)+,(A1)+
	DBRA	D6,.LOOP3
	SUBQ.B	#1,D6
	DBRA	D7,.LOOP2
	CMP.L	#DEST,A0
	BEQ.B	.EXIT
	BRA.B	.LOOP

.EXIT
	RTS	


SOURCE
	DC.W	%1100000011110000
	DC.W	%0000110000110000
SOURCE_LEN=*-SOURCE
DEST
	DS.B		SOURCE_LEN*DEPTH
DEST_END
DEST_LEN=*-DEST
