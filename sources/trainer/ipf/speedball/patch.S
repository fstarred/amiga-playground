***************************************
*
*
*	 Speedball Trainer
*	    boot block part
*	Original IPF, Tosec 2012-04-10
*
***************************************

AllocMem	= -198	;$00C6
DoIo		= -456	;$01C8

DEPACK_ADDRESS = $40000
TRAINER_ADDRESS = $60000

	AUTO	WS\START\0\2\CC\

START:
	DC.B	'DOS',0
	DC.L	0
	DC.L	880

LB_000C	
	MOVE.L	A1,A4
	MOVE.L	$00000004,A6
	LEA	LB_0022(PC),A0
	MOVE.L	A0,$00000014
	MOVEQ	#$00,D0
	DIVU.W	D0,D0
LB_0022	
	MOVE.L	#$0007FFFC,A7
	MOVE.L	#$00019000,D7
	MOVE.L	D7,D0
	MOVE.L	#$00010002,D1	; MEMF_CLEAR!MEMF_CHIP
	JSR	AllocMem(A6)
	TST.L	D0
	BEQ.W	LB_006C
	MOVE.L	D0,A5		; store allocated mem on A5
	MOVEQ	#$40,D0
	ADD.L	D0,D0
	MOVE.L	D0,-(A7)
	PEA	LB_000C(PC)
	MOVE.L	A5,A3
	ADDA.L	#$0000C800,A5
	MOVE.L	#$0004E780,D0
	MOVE.L	#$00010004,D1	; MEMF_CLEAR!MEMF_FAST
	JSR	AllocMem(A6)
	MOVE.L	D0,$00000024
	BRA.B	LB_0084
LB_006C	
	JSR	-$0078(A6)
	JSR	-$0096(A6)
	MOVE.L	#$4E704EF9,$00000000
	JMP	$00000000
LB_0084	
	MOVE.L	#$00000001,$0024(A4)		; motor on
	MOVE.W	#$0009,$001C(A4)		; command: motor
	MOVE.L	A4,A1
	MOVE.L	$00000004,A6
	JSR	DoIo(A6)
	MOVE.L	#$00000400,$0024(A4)		; len

	MOVE.L	#DEPACK_ADDRESS,A3
	MOVE.L	A3,$0028(A4)			; buffer
	MOVE.W	#$0002,$001C(A4)		; command: read
	MOVE.L	#$00000400,$002C(A4)		; offset
	MOVE.L	$00000004,A6
	MOVE.L	A4,A1
	MOVE.L	A5,A0
	JSR	DoIo(A6)			; do a jsr instead of a jmp
						; because we need to modify
						; the code

	MOVE.L	(SP)+,A4			; pop the stack or game
						; will crash on Amiga 512K

	LEA	DO_TRAINER(PC),A4		; replace original
	MOVE.B	#$0C,$2B(A3)			; move.l a0,-(a7)
						; with a4 so 
						; patch address
						; is pushed on stack
						; and used at rts
						
	MOVE.L	A5,-(SP)			; store alloc.mem to sp


	MOVE.L	#$00000600,$0024(A1)		; len
	MOVE.L	#TRAINER_ADDRESS,$0028(A1)	; buffer
	MOVE.W	#$0002,$001C(A1)		; command: read
	MOVE.L	#$00000800,$002C(A1)		; offset
	JSR	DoIo(A6)			; load trainer
	
	JMP	(A3)				; jmp to depack address
	
	MOVEM.L	A3/A5,-(A7)
	MOVE.L	A5,A0
	MOVE.L	A3,A5
	BSR.W	LB_0120
	MOVEM.L	(A7)+,A3/A5
	MOVE.L	#$00000000,$0024(A4)
	MOVE.W	#$0009,$001C(A4)
	MOVE.L	$00000004,A6
	MOVE.L	A4,A1
	MOVE.L	A5,A6
	MOVE.W	#$2BFF,D0
LB_00F6	
	CLR.L	(A6)+
	DBF	D0,LB_00F6
	MOVE.L	A4,A6
	MOVE.W	$00DFF002,D0
	ORI.W	#$83C0,D0
	MOVE.W	D0,$00DFF096
	MOVE.W	$00DFF01C,D0
	ORI.W	#$8070,D0
	MOVE.W	D0,$00DFF09A
	JSR	(A3)
LB_0120	
	MOVE.L	A5,A2
	MOVE.L	(A1)+,D3
	ADD.L	D2,$00(A2,D3.L)
	SUBQ.L	#1,D0
	RTS	
DO_TRAINER:
	NOP
	JSR	TRAINER_ADDRESS		; jmp to trainer menu
	JSR	TRAINER_ADDRESS+2	; jmp to patch code
	RTS				; rts to allocated mem
END
	IF END-START>1024
	FAIL
	ENDC

	PRINTT	"BOOT BLOCK SIZE.."
	PRINTV	END-START
