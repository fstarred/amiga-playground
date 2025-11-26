************************************************************
*
*	   STARRED MEDIASOFT
*
*	Impossible Mission II TRAINER
*	 Original  (TOSEC 2012-04-10)
*	Impossible Mission II  IPF
*		VER 1.0 (2023)
*
*
***********************************************************

;*****************
;*   Constants   *
;*****************

PROD	EQU 0			; FOR PRODUCTION
MENU	EQU 1			; SHOW TRAINER MENU ONLY
DEBUG	EQU 2			; FOR DEBUG

Mode=PROD	 		; 0=Prod,1=TrainerMenu only,2=Debug

FONT_HEIGHT = 5

SW1_VALUE = 0
SW2_VALUE = 0

; look at http://amigadev.elowar.com/ Includes_and_Autodocs_2

OldOpenLibrary	= -408
CloseLibrary	= -414
LoadSeg		= -150
UnLoadSeg	= -156

DMASET=	%1000000111000000
;	 -----a-bcdefghij

;	a: Blitter Nasty
;	b: Bitplane DMA (if this isn't set, sprites disappear!)
;	c: Copper DMA
;	d: Blitter DMA
;	e: Sprite DMA
;	f: Disk DMA
;	g-j: Audio 3-0 DMA

	INCDIR	INCLUDE:
	INCLUDE "HARDWARE/CUSTOM.I"
	
BLTWAIT	MACRO
	tst $dff002			;for compatibility
\1
	btst #6,$dff002
	bne.s \1
	ENDM

START:

	IF Mode<>DEBUG
	JSR	SHOWTRAINER
	ENDC

	IF Mode<>MENU
	BSR.W	LOADGAME
	ENDC

	RTS


SHOWTRAINER:
	MOVEM.L	D0-D7/A0-A6,-(SP)	; Put registers on stack


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
	MOVE.L	$26(A1),OldCop1		; Store copper1 start addr
	MOVE.L	$32(A1),OldCop2		; Store copper1 start addr
	JSR	CloseLibrary(A6)	; Close graphics library

	LEA	$DFF000,A6
	MOVE.W	$1C(A6),OLDINTENA		; Store old INTENA
	MOVE.W	$2(A6),OLDDMACON		; Store old DMACON
	MOVE.W	$10(A6),OLDADKCON		; Store old ADKCON
	
	MOVE.L  #SCREEN,D0  ; POINT TO BITPLANE
    	LEA BPLPOINTERS,A1  ; 
	
	MOVE.W  D0,6(A1)    ; COPY LOW WORD OF PIC ADDRESS TO PLANE
	SWAP    D0          ; SWAP THE THE TWO WORDS
   	MOVE.W  D0,2(A1)    ; COPY THE HIGH WORD OF PIC ADDRESS TO PLANE

	MOVE.W	#$7FFF,$9A(A6)		; Clear interrupt enable

	BSR.W	Wait_Vert_Blank

	MOVE.W	#$7FFF,$96(A6)		; Clear DMA channels
	MOVE.L	#COPLIST,$80(A6)	; Copper1 start address
	MOVE.W	#DMASET!$8200,$96(A6)	; DMA kontrol data
	MOVE.L	$6C.W,OldInter		; Store old inter pointer
	MOVE.L	#INTER,$6C.W		; Set interrupt pointer

	MOVE.W	#$7FFF,$9C(A6)		; Clear request
	MOVE.W	#$C020,$9A(A6)		; Interrupt enable

;****       Your main routine      ****

	BSR.W	PRINTTEXT

;**** Main Loop  Test mouse button ****
.LOOP
	BTST	#6,$BFE001		; Test left mouse button
	BNE.S	.LOOP
;*****************************************
;*					 *
;*   RESTORE SYSTEM INTERRUPTS ECT ECT   *
;*					 *
;*****************************************

	LEA	$DFF000,A6

	MOVE.W	#$7FFF,$9A(A6)		; Disable interrupts

	BSR.W	Wait_Vert_Blank

	MOVE.W	#$7FFF,$96(A6)
	MOVE.L	OldCop1(PC),$80(A6)	; Restore old copper1
	MOVE.L	OldCop2(PC),$84(A6)	; Restore old copper1
	MOVE.L	OldInter(PC),$6C.W	; Restore inter pointer
	MOVE.W	OLDDMACON,D0		; Restore old DMACON
	OR.W	#$8000,D0
	MOVE.W	D0,$96(A6)		
	MOVE.W	OLDADKCON,D0		; Restore old ADKCON
	OR.W	#$8000,D0
	MOVE.W	D0,$9E(A6)
	MOVE.W	OLDINTENA,D0		; Restore inter data
	OR.W	#$C000,D0
	MOVE.W	#$7FFF,$9C(A6)
	MOVE.W	D0,$9A(A6)

	MOVEM.L	(SP)+,D0-D7/A0-A6	; restore registers from stack

	RTS

LOADGAME:
	MOVE.L	4.W,A6			;GET EXECBASE
	LEA	DosLib(PC),A1		;POINTER TO 'DOS.LIBRARY'
	JSR	OldOpenLibrary(A6)	;OPEN DOS.LIBRARY
	TST.L	D0			;IF D0 = 0 THEN LIBRAY OPEN FAILED
	BEQ.W	PROBLEM
	MOVE.L	D0,A6			;PUT DOS.LIBRARY BASE ADDRESS IN A6
	
	LEA	Filename(PC),A0		;GET FILENAME PC RELATIVE
	MOVE.L	A0,D1			;MOVE FILENAME INTO D1
	JSR	LoadSeg(A6)		;CALL LOADSEG
	LSL.L	#2,D0			;MULTIPLY D0 * 4 TO GET CORRECT ADDRESS
	MOVE.L	D0,A0			;MOVE ADDRESS INTO A0

	JSR	PATCH_BEGIN
	
	MOVEQ	#1,D0
	MOVE.L	A0,D1

	IF Mode=PROD
	JMP	4(A0)			;EXECUTE FILE LOADED BY LOADSEG
	ELSE
	JSR	UNLOADSEG(A6)
	ENDC
	
	RTS
	
;----------------------------------------------------
; Impossible Mission II trainer code
;----------------------------------------------------
	
PATCH_BEGIN:
	MOVEM.L	D0-D7/A0-A6,-(SP)	; Put registers on stack
	
	LEA	BUTTONS(PC),A1
	MOVE.L	#$4E714E71,D1
	
	MOVE.L	A0,A2 
	ADDA.L	#$FDEC,A2	; avoid dumb ram space check 
	MOVE.L	D1,(A2)+
	MOVE.W	D1,(A2)+
	MOVE.W	#$602c,(A2)	; replace bls with bra
	
NO_TIMER_COUNTDOWN:
	TST.B	(A1)+
	BEQ.B	CHARGE_ITEMS
	MOVE.L	A0,A2
	ADDA.L	#$8244,A2		
	MOVE.L	D1,(A2)		; no timer countdown
	MOVE.L	D1,$18(A2)	; no count on player death
CHARGE_ITEMS:
	TST.B	(A1)+
	BEQ.B	PATCH_END
	MOVE.L	A0,A2
	ADDA.L	#$3030,A2
	MOVE.L	D1,(A2)		; avoid clearing items
				; at start
	ADDA.L	#$F88B,A2
	MOVEQ	#80,D2		; set all items below to 80
	MOVE.B	D2,(A2)		; electric plug
	MOVE.B	D2,$0A(A2)	; platform symbol
	MOVE.B	D2,$14(A2)	; lift platform symbol
	MOVE.B	D2,$1E(A2)	; time bomb
	MOVE.B	D2,$28(A2)	; mine
	MOVE.B	D2,$32(A2)	; light bulb
	
				; works only at first play !
	
PATCH_END:
	MOVEM.L	(SP)+,D0-D7/A0-A6	; restore registers from stack
	RTS


PROBLEM:
	MOVEQ	#0,D0
	RTS
	
KEYGET:
	MOVEQ	#0,D0
	MOVE.B	$BFED01.L,D0
	BTST	#3,D0
	BEQ.S	GENEFEIL

	MOVE.B	$BFEC01,D0
	NOT.B	D0
	LSR.W	#1,D0
	BCS.W	NOFONT
GENEFEIL:
	BSET	#6,$BFEE01
	MOVEQ	#127,D1
DELAY:	DBF	D1,DELAY
	BCLR	#6,$BFEE01
	CMP.B	#$50,D0
	BLT.W	NOFONT		; IF < 50 EXIT
	CMP.B	#$52,D0
	BGT.W	NOFONT		; IF > 51 EXIT
	SUB.B	#$50,D0		; IF BEETWEN 50 AND 51 SUBTRACT
ELABSWITCH:
	LEA	COORDS(PC),A0
	LEA	BUTTONS(PC),A1
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
	BSR.B	TEXT2
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
	BSR.B	TEXT2
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
	BSR.B	SETFONT
	MOVE.B	(A4),(A2)
	MOVE.B	1(A4),40(A2)	
	MOVE.B	2(A4),80(A2)	
	MOVE.B	3(A4),120(A2)	
	MOVE.B	4(A4),160(A2)	
	ADDQ.L	#1,A2
	BRA.S	PRINTLOOP	
END:
	RTS

PLOT:
	SUBQ.B	#1,COUNTER
	BNE.S	NOFONT
	MOVE.B	#8,COUNTER
INITTEXTPTR:
	LEA	SCROLLINGTEXT(PC),A0
	MOVE.W	TEXTPTR,D1
	ADD.W	D1,A0
	ADDQ	#1, D1
	MOVE.W	D1, TEXTPTR
	
	MOVEQ	#0,D0
	MOVE.B	(A0),D0
	BNE.S	NORESET
	MOVE.W	#0,TEXTPTR
	BRA.B		INITTEXTPTR
NORESET:	
	LEA FONT(PC), A3
	LEA	SCREEN+(40*FONT_HEIGHT*37)+40,A2	; PLOTPOSITION
	
STARTPLOT:
	BSR.B	SETFONT
	MOVE.B	(A4),(A2)
	MOVE.B	1(A4),42(A2)	
	MOVE.B	2(A4),84(A2)	
	MOVE.B	3(A4),126(A2)	
	MOVE.B	4(A4),168(A2)	
NOFONT:
	RTS

SETFONT:
	SUB.B	#$20,D0
	MULU	#FONT_HEIGHT,D0
;	MOVE.W	D0,D1	; THE 3 COMMANDS BELOW SUBSTITUTE THE MULU * 5
;	ASL	#2,D1	; ***
;	ADD.L	D1,D0	; ***
	LEA	(A3,D0.W),A4
	RTS
	
SCROLL

	MOVE.L	#SCREEN+(40*FONT_HEIGHT*37)+(42*FONT_HEIGHT)+40, D0 ; AT LINE 38 MULU=+2

	LEA	$DFF000,A5
	
	BLTWAIT BWT1

	MOVE.L	#$19F00002,bltcon0(A5)	; BLTCON0 COPY FROM A TO D ($F) 
									; 1 PIXEL SHIFT, LF = F0
									; BLTCON1 USE BLITTER DESC MODE
					
	MOVE.L	#$FFFFFFFF,bltafwm(A5)	; BLTAFWM / BLTALWM
									; BLTAFWM = $FFFF - 
									; BLTALWM = $FFFF 

	MOVE.L	D0,bltapt(A5)			; BLTAPT - SOURCE
	MOVE.L	D0,bltdpt(A5)			; BLTDPT - DEST

	; SCROLL AN IMAGE OF THE FULL SCREEN WIDTH * FONT_HEIGHT

	MOVE.L	#$00000000,bltamod(A5)	; BLTAMOD + BLTDMOD 
	MOVE.W	#((FONT_HEIGHT+1)*64)+21,bltsize(A5)	; BLTSIZE
	
	RTS
	

;**********************************
;*				  *
;*    INTERRUPT ROUTINE. LEVEL 3  *
;*				  *
;**********************************

INTER:
	MOVEM.L	D0-D7/A0-A6,-(SP)	; Put registers on stack
	LEA.L	$DFF000,A6
	MOVE.L	#SCREEN,$E0(A6)

;---  Place your interrupt routine here  ---

	BSR.W	KEYGET
	BSR.W	PLOT
	BSR.B	SCROLL

	MOVE.W	#$4020,$9C(A6)		; Clear interrupt request
	MOVEM.L	(SP)+,D0-D7/A0-A6	; Get registers from stack
	RTE

;-----------------------------------------------
DosLib:
	dc.b	'dos.library',0


Filename:
	dc.b	'df0:im2',0
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
OLDINTENA	DC.W	0
OLDDMACON	DC.W	0
OLDADKCON	DC.W	0

COORDS:		; switch trainer coordinate values
	dc.b	30,14
	dc.b	30,18
	
ON:
	dc.b 0,0,'ON ',$ff
OFF:
	dc.b 0,0,'OFF',$ff

MENUTEXT:
	dc.b	0,0, '----------------------------------------',0
	dc.b	10,2,'IMPOSSIBLE MISSION II',0
	dc.b	0,4, '----------------------------------------',0
	dc.b	6,8, 'TRAINER BY FABRIZIO STELLATO',0
	dc.b	0,10,'----------------------------------------',0
	dc.b	8,14,'F1 UNLIMITED TIME     OFF',0
	dc.b	8,18,'F2 MAXIMIZE ITEMS     OFF',0
	dc.b	0,27,'----------------------------------------',$ff
SCROLLINGTEXT:
	DC.B	'IMPOSSIBLE MISSION II TRAINER + RAM FIX'
	DC.B	' - TESTED ON A500. DOES NOT WORK ON NEWER AMIGA!'
	DC.B	' - THANKS TO EAB ABIME FORUM FOR THE SUPPORT'
	DC.B	' *** ',0
BUTTONS:
	dc.b	SW1_VALUE	
	dc.b	SW2_VALUE
	EVEN
COUNTER:
	DC.B	8
	EVEN
TEXTPTR
	DC.W	0


FONT:
	INCDIR	SOURCES:
	INCBIN	"TRAINER/FONT"

	
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
	DC.W	$0108, $0000
	dc.w	$0180, $055f
	dc.w	$2807, $fffe
	dc.w	$0180, $0004

	dc.w	$0182, $066f
	dc.w	$e107, $fffe
	dc.w	$0180, $055f
	dc.w	$e207, $fffe
	dc.w	$0180, $0000
	dc.w	$e507, $fffe
	dc.w	$0108, $0002

	DC.L	$FFFFFFFE

;*****************************
;*			     *
;*      SCREEN DATA AREA     *
;*			     *
;*****************************

	SECTION	Screen,BSS_C

SCREEN	DS.B	42*256

********

	PRINTT "Mode:"
	PRINTV Mode

