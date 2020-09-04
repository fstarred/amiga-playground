*********************************************
*
*	   STARRED MEDIASOFT
*
*		SPEEDBALL TRAINER
*
*		VER 1.0 (2020)
*
*	MANY THANKS TO EAB ABIME FORUM,
*	ESPECIALLY TO GALAHAD/FLT FOR
*	WRITING THE MAIN CODE SNIPPET
*
*********************************************

;*****************
;*   Constants   *
;*****************

DEBUG = 1 			; 0 = enabled, otherwise disabled
DEBUG_KEYPRESS = 0		; simulate key pressed (debug mode)

SPARE_MEM = $20000

SW1_VALUE = 0
SW2_VALUE = 0
SW3_VALUE = 0
SW4_VALUE = 0

; look at http://amigadev.elowar.com/ Includes_and_Autodocs_2

OldOpenLibrary	= -408
CloseLibrary	= -414
LoadSeg			= -150

DMASET=	%1000000111000000
;	 -----a-bcdefghij

;	a: Blitter Nasty
;	b: Bitplane DMA (if this isn't set, sprites disappear!)
;	c: Copper DMA
;	d: Blitter DMA
;	e: Sprite DMA
;	f: Disk DMA
;	g-j: Audio 3-0 DMA

START:
	MOVEM.L	D0-D7/A0-A6,-(A7)	; Put registers on stack


;***********************************
;*   CLOSE ALL SYSTEM INTERRUPTS   *
;*                                 *
;*      START DEMO INTERRUPTS      *
;***********************************

	MOVE.L	$4.W,A6			; Exec pointer to A6
	LEA.L	GfxName(PC),A1		; Set library pointer
	MOVEQ	#0,D0
	JSR	OldOpenLibrary(A6)	; Open graphics.library
	MOVE.L	D0,A1			; Use Base-pointer
	MOVE.L	$26(A1),OLDCOP1		; Store copper1 start addr
	MOVE.L	$32(A1),OLDCOP2		; Store copper1 start addr
	JSR	CloseLibrary(A6)	; Close graphics library

	LEA	$DFF000,A6
	MOVE.W	$1C(A6),INTENA		; Store old INTENA
	MOVE.W	$2(A6),DMACON		; Store old DMACON
	MOVE.W	$10(A6),ADKCON		; Store old ADKCON
	
	MOVE.L  #SCREEN,D0  ; POINT TO BITPLANE
    LEA BPLPOINTERS,A1  ; 
	
	MOVE.W  D0,6(A1)    ; COPY LOW WORD OF PIC ADDRESS TO PLANE
    SWAP    D0          ; SWAP THE THE TWO WORDS
   	MOVE.W  D0,2(A1)    ; COPY THE HIGH WORD OF PIC ADDRESS TO PLANE

	IFNE DEBUG
	MOVE.W	#$7FFF,$9A(A6)		; Clear interrupt enable

	BSR.L	Wait_Vert_Blank

	MOVE.W	#$7FFF,$96(A6)		; Clear DMA channels
	MOVE.L	#COPLIST,$80(A6)	; Copper1 start address
	MOVE.W	#DMASET!$8200,$96(A6)	; DMA kontrol data
	MOVE.L	$6C.W,OldInter		; Store old inter pointer
	MOVE.L	#INTER,$6C.W		; Set interrupt pointer

	MOVE.W	#$7FFF,$9C(A6)		; Clear request
	MOVE.W	#$C020,$9A(A6)		; Interrupt enable
	ENDC

;****       Your main routine      ****

	BSR	CLEARSCREEN
	BSR	PRINTTEXT

	IFEQ	DEBUG
	BSR	ELABSWITCH
	BSR	PATCH_BEGIN
	ENDC


;**** Main Loop  Test mouse button ****
	IFNE	DEBUG
LOOP:
	BTST	#6,$BFE001		; Test left mouse button
	BNE.S	LOOP
	ENDC
;*****************************************
;*					 *
;*   RESTORE SYSTEM INTERRUPTS ECT ECT   *
;*					 *
;*****************************************

	LEA	$DFF000,A6
	IFNE DEBUG
	MOVE.W	#$7FFF,$9A(A6)		; Disable interrupts

	BSR.W	Wait_Vert_Blank

	MOVE.W	#$7FFF,$96(A6)
	MOVE.L	OldCop1(PC),$80(A6)	; Restore old copper1
	MOVE.L	OldCop2(PC),$84(A6)	; Restore old copper1
	MOVE.L	OldInter(PC),$6C.W	; Restore inter pointer
	MOVE.W	DMACON,D0		; Restore old DMACON
	OR.W	#$8000,D0
	MOVE.W	D0,$96(A6)		
	MOVE.W	ADKCON,D0		; Restore old ADKCON
	OR.W	#$8000,D0
	MOVE.W	D0,$9E(A6)
	MOVE.W	INTENA,D0		; Restore inter data
	OR.W	#$C000,D0
	MOVE.W	#$7FFF,$9C(A6)
	MOVE.W	D0,$9A(A6)
	ENDC
	MOVEM.L	(A7)+,D0-D7/A0-A6	; Get registers from stack

LOADGAME
	MOVE.L	4.W,A6			;GET EXECBASE
	LEA	DOSLIB(PC),A1		;POINTER TO 'DOS.LIBRARY'
	JSR	-$198(A6)		;OPEN DOS.LIBRARY
	TST.L	D0			;IF D0 = 0 THEN LIBRAY OPEN FAILED
	BEQ.W	PROBLEM
	MOVE.L	D0,A6			;PUT DOS.LIBRARY BASE ADDRESS IN A6
	
	LEA	FILENAME(PC),A0		;GET FILENAME PC RELATIVE
	MOVE.L	A0,D1			;MOVE FILENAME INTO D1
	JSR	LOADSEG(A6)		;CALL LOADSEG
	LSL.L	#2,D0			;MULTIPLY D0 * 4 TO GET CORRECT ADDRESS
	MOVE.L	D0,A0			;MOVE ADDRESS INTO A0


	MOVE.L	A0,A1			;COPY ADDRESS OF FILE LOADED
	LEA	PATCH_BEGIN(PC),A2		;POINTER TO PATCH CODE


	LEA	SPARE_MEM,A3		;SPARE MEMORY FOR PATCH
	MOVE.L	A3,$B2(A1)		;COPY NEW ADDRESS INTO FINAL JMP (WHICH IS LOCALTED AT INITIAL FILE ADDRESS + $B0)
	
	MOVE.W	#(PATCH_END-PATCH_BEGIN)-1,D0;SIZE OF PATCH TO COPY
COPY_PATCH:
	MOVE.B	(A2)+,(A3)+		;COPY FROM START OF PATCH ROUTINE
					;TO SPARE MEMORY
	DBRA	D0,COPY_PATCH		;SUBRACT FROM PATCH SIZE AND LOOP
					;UNTIL COPIED
	IFNE DEBUG	
	JMP	4(A0)			;EXECUTE FILE LOADED BY LOADSEG
	ENDC
	
	RTS
	
;----------------------------------------------------
; Speedball trainer code
;----------------------------------------------------
	
PATCH_BEGIN:
	LEA	BUTTONS,A0		; DO NOT USE PC RELATIVE ADDR!!!
	MOVE.B	(A0)+,D0
	TST	D0
	BEQ	CHECK_NEXT1
	MOVE.L	#$4E714E75,$30BDA	; NO SCORE P1
CHECK_NEXT1:
	MOVE.B	(A0)+,D0
	TST	D0
	BEQ	CHECK_NEXT2
	MOVE.L	#$4E714E75,$30BE0	; NO SCORE P2
CHECK_NEXT2:
	MOVE.B	(A0)+,D0
	TST	D0
	BEQ	CHECK_NEXT3
	MOVE.W  #$7424,$38F22	; UNLIMITED COINS
	MOVE.L	#$1B42041B,$38F24
CHECK_NEXT3:
	MOVE.B	(A0)+,D0
	TST	D0
	BEQ	PATCH_JMP	
	LEA	$31C57,A0				; GAME DURATION MOD
	CMP	#1,D0
	BNE	CHECKTIMEVAL2
	MOVE.B	#$3C,(A0)
	BRA.S	PATCH_JMP
CHECKTIMEVAL2:
	CMP	#2,D0
	BNE	CHECKTIMEVAL3
	MOVE.B	#$28,(A0)
	BRA.S	PATCH_JMP
CHECKTIMEVAL3:
	MOVE.B	#$14,(A0)
PATCH_JMP
	IFNE	DEBUG
	JMP	$30000
	ENDC
PATCH_END:


PROBLEM:
	MOVEQ	#0,D0
	RTS
	
NOFONT:
	RTS

KEYGET:
	MOVEQ	#0,D0
	MOVE.B	$BFED01.L,D0
	BTST	#3,D0
	BEQ.S	GENEFEIL

	MOVE.B	$BFEC01,D0
	NOT.B	D0
	LSR.W	#1,D0
	BCS	NOFONT
GENEFEIL:
	BSET	#6,$BFEE01
	MOVEQ	#127,D1
DELAY:	DBF	D1,DELAY
	BCLR	#6,$BFEE01
	CMP.B	#$50,D0
	BLT.S	NOFONT		; IF < 50 EXIT
	CMP.B	#$53,D0
	BGT.S	NOFONT		; IF > 53 EXIT
	SUB.B	#$50,D0		; IF BEETWEN 50 AND 57 SUBTRACT
ELABSWITCH:
	IFEQ DEBUG
	MOVEQ	#DEBUG_KEYPRESS,D0
	ENDC
	LEA	COORDS(PC),A0
	LEA	BUTTONS(PC),A1
	CMP.W	#3,D0
	BPL	NUMVALUE
ONOFFVALUE:
	LEA	ON(PC),A2
	LEA	OFF(PC),A3
	NOT.B	(A1,D0.W)	; CHECK 
	TST.B	(A1,D0.W)
	BNE.S	TRAINERON
TRAINEROFF:
	BSR.S	TESTPOS
	MOVE.B	(A0)+,(A3)	; STORE COORDS X ON A3
	MOVE.B	(A0)+,1(A3)	; STORE COORDS Y ON A3
	MOVE.L	A3,A0		; A0 POINT TO 0,0,' OFF'
	BSR	TEXT2
	RTS

TESTPOS:
	ADD.W	D0,D0
	LEA	(A0,D0.W),A0	; PUT COORDS OF SWITCH PRESSED ON A0
	RTS

TRAINERON:
	BSR.S	TESTPOS
	MOVE.B	(A0)+,(A2)	; STORE COORDS X ON A2
	MOVE.B	(A0)+,1(A2)	; STORE COORDS Y ON A2
	MOVE.L	A2,A0		; A0 POINT TO 0,0,' ON'
	BSR	TEXT2
	RTS
NUMVALUE:
	MOVEQ	#0,D1
	MOVE.B	(A1,D0.W),D1
	CMP.B	#3,D1
	BNE.W	NORESETVAL
	MOVEQ	#-1,D1
NORESETVAL
	ADDQ	#1,D1
	MOVE.B	D1,(A1,D0.W)		; BUTTON VALUE ON D0
	BSR.S	TESTPOS
	LEA  TIMEPERCLAB-6(PC), A2
GETLABEL
	ADD.W #6, A2
	DBRA D1, GETLABEL	
	MOVE.B	(A0)+,(A2)
	MOVE.B	(A0)+,1(A2)
	MOVE.L	A2,A0
	BSR	TEXT2	
	RTS

CLEARSCREEN:
	LEA	SCREEN,A0
	MOVE.W	#2000,D0
CLEARLOOP:
	CLR.L	(A0)+
	DBF	D0,CLEARLOOP
	RTS
PRINTTEXT:
	LEA	MENUTEXT(PC),A0
TEXT2:
	LEA	SCREEN,A1
	LEA	FONT(PC),A3
LOOPER:
	MOVEQ	#0,D0
	MOVE.L	D0,D1
	MOVE.B	(A0)+,D0
	MOVE.B	(A0)+,D1
	MULU	#[6*40],D1	; MULTIPLY COORDS Y * CHARLEN * 40 LINES
	ADD.W	D1,D0		; ADD COORDS X
	LEA	(A1,D0.W),A2	; SCREEN DEST

PRINTLOOP:
	MOVEQ	#0,D0
	MOVE.B	(A0)+,D0
	BEQ.S	LOOPER
	CMP.B	#$FF,D0
	BEQ.S	END
	BSR	SETFONT
	MOVE.B	(A4),(A2)
	MOVE.B	1(A4),40(A2)	
	MOVE.B	2(A4),80(A2)	
	MOVE.B	3(A4),120(A2)	
	MOVE.B	4(A4),160(A2)	
	ADDQ.L	#1,A2
	BRA.S	PRINTLOOP	
END:
	RTS

SETFONT:
	SUB.B	#$20,D0
	MULU	#5,D0
	LEA	(A3,D0.W),A4
	RTS

;**********************************
;*				  *
;*    INTERRUPT ROUTINE. LEVEL 3  *
;*				  *
;**********************************

INTER:
	MOVEM.L	D0-D7/A0-A6,-(A7)	; Put registers on stack
	LEA.L	$DFF000,A6
	MOVE.L	#SCREEN,$E0(A6)

;---  Place your interrupt routine here  ---

	BSR	KEYGET

	MOVE.W	#$4020,$9C(A6)		; Clear interrupt request
	MOVEM.L	(A7)+,D0-D7/A0-A6	; Get registers from stack
	RTE

;-----------------------------------------------
doslib:
	dc.b	'dos.library',0


	; place a copy of speedball executable on DH1
filename:
	dc.b	'df0:Speedball',0
	EVEN

;*** WAIT VERTICAL BLANK ***

Wait_Vert_Blank:
	BTST	#0,$5(A6)
	BEQ.S	Wait_Vert_Blank
.loop	BTST	#0,$5(A6)
	BNE.S	.loop
	RTS

;*** DATA AREA ***

GfxName		DC.B	'graphics.library',0
		even
DosBase		DC.L	0
OldInter	DC.L	0
OldCop1		DC.L	0
OldCop2		DC.L	0
INTENA		DC.W	0
DMACON		DC.W	0
ADKCON		DC.W	0

COORDS:		; switch trainer coordinate values
	dc.b	30,14
	dc.b	30,18
	dc.b	30,22
	dc.b	30,26
	
ON:
	dc.b 0,0,'ON ',$ff
OFF:
	dc.b 0,0,'OFF',$ff
TimePercLab:
	dc.b 0,0,'OFF',$ff
	dc.b 0,0,' 60',$ff
	dc.b 0,0,' 40',$ff
	dc.b 0,0,' 20',$ff

MENUTEXT:
	dc.b	0,0, '----------------------------------------',0
	dc.b	10,2,'SPEEDBALL TRAINER',0
	dc.b	0,4, '----------------------------------------',0
	dc.b	11,6,'CRACKED BY ORACLE',0
	dc.b	5,8, 'TRAINER BY FABRIZIO STELLATO',0
	dc.b	0,10,'----------------------------------------',0
	dc.b	8,14,'F1 NO SCORE P1        OFF',0
	dc.b	8,18,'F2 NO SCORE P2        OFF',0
	dc.b	8,22,'F3 UNLIMITED COINS    OFF',0
	dc.b	8,26,'F4 GAME DURATION      OFF',0
	dc.b	0,30,'----------------------------------------',$ff
	
	incdir	"dh1:own/demo/repository/trainers/"
FONT:
	incbin	"font"
BUTTONS:
	dc.b	SW1_VALUE
	dc.b	SW2_VALUE
	dc.b	SW3_VALUE
	dc.b	SW4_VALUE

	
;*****************************
;*			     *
;*      COPPER1 PROGRAM      *
;*			     *
;*****************************

	SECTION	Copper,DATA_C

COPLIST:
	DC.W	$0100,$1200	; Bit-Plane control reg.
	DC.W	$0102,$0000	; Hor-Scroll
	DC.W	$0104,$0010	; Sprite/Gfx priority
	DC.W	$0108,$0000	; Modolu (odd)
	DC.W	$010A,$0000	; Modolu (even)
	DC.W	$008E,$2C81	; Screen Size
	DC.W	$0090,$2CC1	; Screen Size
	DC.W	$0092,$0038	; H-start
	DC.W	$0094,$00D0	; H-stop
BPLPOINTERS:
	dc.w	$00e0,$0000 ; BITPLANE 0
	dc.w	$00e2,$0000 ; BITPLANE 0

	dc.w	$2707, $fffe
	dc.w	$0180, $055f
	dc.w	$2807, $fffe
	dc.w	$0180, $0004

	dc.w	$0182, $066f
	dc.w	$e607, $fffe
	dc.w	$0108, $0002
	dc.w	$00e0, $0004
	dc.w	$00e2, $1e02
	dc.w	$e007, $fffe
	dc.w	$0100, $0000
	dc.w	$eb07, $fffe
	dc.w	$0180, $055f
	dc.w	$ec07, $fffe
	dc.w	$0180, $0000

	DC.L	$FFFFFFFE

;*****************************
;*			     *
;*      SCREEN DATA AREA     *
;*			     *
;*****************************

	SECTION	Screen,BSS_C

SCREEN	DS.B	40*256
