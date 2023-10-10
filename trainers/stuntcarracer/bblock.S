***************************************************
*
*	  	 STARRED MEDIASOFT
*
*		STUNT CAR RACER TRAINER
*	Stunt_Car_Racer_1989_MicroStyle_cr_QTX_h_TFS
*
*		VER 1.0 (2023)
*
*
***************************************************

DoIo	= -456

TRAINER_SECTORS=3
TRAINER_SECSIZE=$200*TRAINER_SECTORS

	AUTO	WS\START\0\2\CC\

RewriteFinalJmp

	IFD RewriteFinalJmp

	PRINTT	"READING SECTOR 110.."
	AUTO	RS\$70000\110\1\
	PRINTT	"MODIFYING JMP ADDRESS.."
	AUTO	F.L\$7004A\$7004E\TRAINER_ADDRESS+2\
	PRINTT	"WRITING SECTOR 110.."
	AUTO	WS\$70000\110\1\

	ENDC

TRAINER_ADDRESS=$500

START:
LB_0000	
	DC.B	'DOS',0
	DC.L	0
	DC.L	880
	MOVEM.L	D0-A6,-(A7)
	MOVE.L	$00000004,A6
	MOVE.W	#$0002,$001C(A1)
	MOVE.L	#$00010000,$0028(A1)
	MOVE.L	#$00000E00,$0024(A1)
	MOVE.L	#$00074400,$002C(A1)
	JSR	-$01C8(A6)
	LEA	$00010000,A0
	MOVE.L	#$00000E00,D0
LB_0044	NOT.B	(A0)+
	DBF	D0,LB_0044
;	JMP	$00010000
	BRA	LOAD_TRAINER
	DC.B	'TELSTARJ',$10,')',$00
	DC.B	$1F,'f',$D6,'3|',$00
	DC.B	$09,$00
	DC.B	$1C,'#|',$00
	DC.B	$00
	DC.B	$00
	DC.B	$00
	DC.B	$00
	DC.B	'$,x',$00
	DC.B	$04,'N',$AE,$FE,'8,x',$00
	DC.B	$04,'N',$AE,$FF,'jO',$FA,$01,$82,'N',$D3,'Protectio'
	DC.B	'n (C)Copyright 1989 Rob Northen Computing. All R'
	DC.B	'ights Reserved'

;--- custom part ---

	EVEN
LOAD_TRAINER:
	MOVE.L	#TRAINER_ADDRESS,$0028(A1)
	MOVE.L	#TRAINER_SECSIZE,$0024(A1)
	MOVE.L	#$00073C00,$002C(A1)
	JSR	DoIo(A6)

	MOVE.W	#$4EF9,$1000C	; replace jsr with jmp
				; so program return here
	JSR	$10000		; load cracktro

	JSR	TRAINER_ADDRESS	; load trainer
	JMP	$10012		; continue loading game
END
	DS.B	1024-(END-START)

	PRINTT	"BOOTBLOCK REAL SIZE..."
	PRINTV	END-START
