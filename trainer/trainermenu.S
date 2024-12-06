*****************************************
*					*
*	   STARRED MEDIASOFT		*
*					*
*	TRAINER MENU TEMPLATE		*
*	Trainer menu template		*
*					*
*	     VER 1.0 (2023)		*
*					*
*					*
*****************************************

;*****************
;*   Constants   *
;*****************

	INCDIR	"DH1:/AMIGA-PLAYGROUND"

SW1_MAXVALUES = 2
SW2_MAXVALUES = 12
SW3_MAXVALUES = 10

SW1_VALUE = 0
SW2_VALUE = 0
SW3_VALUE = SW3_MAXVALUES

OldOpenLibrary	= -408
CloseLibrary	= -414

FONT_HEIGHT=5

SCROLL_V_OFFSET=(42*FONT_HEIGHT*37)


; A = AGNUS, D = DENISE, P = PAULA

;DMACON     096      W     A D P   DMA control write (clear or set)
;DMACONR    002      R     A   P   DMA control (and blitter status) read
DMASET=	%1000001111000000 ($83C0)
;	 fedcba9876543210

;	f: Set/Clear control bit
;	e: Blitter busy status bit (read only)
;	d: Blotter logic zero status bit (read only)
;	c: X
;	b: X
;	a: Blitter DMA priority (blitter nasty)
;	9: Enable all DMA below
;	8: Bitplane DMA enable
;	7: Copper DMA enable
;	6: Blitter DMA enable
;	5: Sprite DMA enable
;	4: Disk DMA enable
;	3: Audio channel 3 DMA enable
;	2: Audio channel 2 DMA enable
;	1: Audio channel 1 DMA enable
;	0: Audio channel 0 DMA enable

;INTENA     09A      W       P    Interrupt enable bits (clear or set bits)
;INTENAR    01C      R       P    Interrupt enable bits (read)
INTENA=	%1100000000100000 ($C020)
;	 fedcba9876543210

;	f: Set/Clear control bit 
;	e: Master interrupt
;	d: External interrupt
;	c: Disk sync register ( DSKSYNC ) matches disk data
;	b: Serial port receive buffer full
;	a: Audio channel 3 block finished
;	9: Audio channel 2 block finished
;	8: Audio channel 1 block finished
;	7: Audio channel 0 block finished
;	6: Blitter finished
;	5: Start of vertical blank
;	4: Copper
;	3: I/O ports and timers
;	2: Reserved for software -initalited interrupt
;	1: Disk block finished
;	0: Serial port transmit buffere empty
	
BLTWAIT	MACRO
	tst $dff002			;for compatibility
\1
	btst #6,$dff002
	bne.s \1
	ENDM

START:
;--- Store Old Register Settings ---

	MOVEM.L	D0-D7/A0-A6,-(SP)

	MOVE.L	$4.W,A6
	LEA	GFXNAME(PC),A1
	JSR	OldOpenLibrary(A6)	; load graphics library
	MOVE.L	D0,A1
	MOVE.L	38(A1),OldCopper	; store old copper 1
	JSR	CloseLibrary(A6)	; close graphics library

	LEA	$DFF000,A6
	MOVE.W	$1C(A6),OldIntena	; store old INTENA (INTENAR)
	MOVE.W	$02(A6),OldDma		; store old DMACON (DMACONR)	

;--- Disable Intena/Intreq/Dmacon ---

	MOVE.L	#$7FFF7FFF,$9A(A6)	; disable INTENA/INTREQ
	MOVE.W	#$7FFF, $96(A6)		; disable DMACON

;--- Set Bpl pointers	---

	MOVE.L  #SCREEN,D0  		; POINT TO BITPLANE
	LEA BPLPOINTERS,A1  	 
	
	MOVE.W  D0,6(A1)    		; COPY LOW WORD OF PIC ADDRESS TO PLANE
	SWAP    D0          		; SWAP THE THE TWO WORDS
   	MOVE.W  D0,2(A1)    		; COPY THE HIGH WORD OF PIC ADDRESS TO PLANE


;--- Set Register Settings ---

	BSR	WAITVB			; Wait for VBLANK

	MOVE.W	#DMASET,$96(A6)		; set bits of DMACON state
	MOVE.L	#COPLIST,$80(A6)	; set custom COPPERLIST
	MOVEQ	#0,D0
	MOVE.W	D0,$88(A6)		; activate COPLIST
	MOVE.W	D0,$1FC(A6)		; FMODE - BPL32

;--- Program Interrupt ---

	MOVE.L	$6C.W,OldInter		; store old INTER PTR

	MOVE.L	#INTER,$6C.W		: set interrupt pointer
	MOVE.W	#INTENA,$9A(A6)		; set bit of INTENA

;****       Your main routine      ****

	BSR.W	CLEARSCREEN
	BSR.W	PRINTMENU


;**** Main Loop  Test mouse button ****
LOOP:
	BTST	#6,$BFE001		; Test left mouse button
	BNE.S	LOOP
	
;*****************************************
;*					 *
;*   RESTORE SYSTEM INTERRUPTS ECT ECT   *
;*					 *
;*****************************************

	LEA	$DFF000,A6

	MOVE.W	#$7FFF,$9A(A6)		; disable interrupts	

	BSR.W	WAITVB

;--- Restore old DmaCon ---

	MOVE.W	#$7FFF,$96(A6)		; disable DMA

	MOVE.W	OldDma(PC),D0
	OR.W	#$8000,D0		; set bits of DMACON state
	MOVE.W	D0,$96(A6)		; restore original DMACON

;--- Restore old Copper ---

	MOVE.L	OldCopper,$80(A6)	; restore original COPPERLIST
	MOVE.W	D0,$88(A6)		; activate original COPPERLIST

;--- Restore old Intreq ---

	MOVE.L	OldInter(PC),$6C.W	; restore inter pointer

	MOVE.W	#$7FFF,$9C(A6)		; clear requests

;--- Restore old Intena ---

	MOVE.W	OldIntena(PC),D0
	OR.W	#$C000,D0		; set bits of INTENA state
	MOVE.W	D0,$9A(A6)		; restore original INTENA
	
;--- Restore Old Register Settings ---
	
	MOVEM.L (SP)+,D0-D7/A0-A6

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
	BGT.W	NOFONT		; IF > 52 EXIT
	SUB.B	#$50,D0		; F1 = 0, F2 = 1, F3 = 2..
	
	
;	NOTE: A WELL FORMED LABEL IS COMPOSED BY:
;		X,Y,'CHR',($00|$ff)
;		B,B,BBB,B
;	FOR A TOTAL OF 6 BYTES
ELABSWITCH:
	LEA	COORDS(PC),A0
	LEA	BUTTONS(PC),A1
	MOVE.W	D0,D1
	BEQ.B	ELAB_FIXVAL
	SUBQ	#1,D1
	BEQ.B	ELAB_NUMVAL
	SUBQ	#1,D1
	BEQ.B	ELAB_MIXVAL
	
ELAB_FIXVAL:
	MOVEQ	#0,D1
	MOVE.B	(A1,D0.W),D1
	CMP.B	#SW1_MAXVALUES-1,D1
	BNE.B	NORESETVAL
	MOVEQ	#-1,D1
NORESETVAL
	ADDQ.L	#1,D1
	MOVE.B	D1,(A1,D0.W)		; STORE VALUE ON BUTTONS
	BSR.W	GETCOORD
	LEA  FIXEDVALUE-6(PC), A2
GETLABEL
	ADD.W #6, A2			; GET NEXT LABEL
	DBRA D1, GETLABEL	
	MOVE.B	(A0)+,(A2)
	MOVE.B	(A0)+,1(A2)
	MOVE.L	A2,A0
	BSR.W	WRITETEXT	
	RTS
	
ELAB_NUMVAL:
	MOVEQ	#0,D1
	MOVE.B	(A1,D0.W),D1		; BUTTON VALUE ON A1 
	CMP.B	#SW2_MAXVALUES,D1	; D1 = SWITCH VALUE
	BNE.B	NORESETNUMVAL
	MOVEQ	#-1, D1
NORESETNUMVAL
	ADDQ.L	#1, D1
	MOVE.B	D1,(A1,D0.W)		; BUTTON VALUE ON D0
	BSR.S	GETCOORD
PRINTNUM:
	LEA NUMVALUE(PC),A2
	MOVE.B	(A0)+,(A2)
	MOVE.B	(A0)+,1(A2)
	MOVE.L	D1,D2
	BSR.B 	NUMTOHEX
	MOVE.L	A2,A0
	BSR.B	WRITETEXT
	RTS
	
ELAB_MIXVAL:
	MOVEQ	#0,D1
	MOVE.B	(A1,D0.W),D1	; BUTTON VALUE ON A1 
	BNE.B	NORESETMIXVAL
	MOVEQ	#SW3_MAXVALUES+1, D1
NORESETMIXVAL
	SUBQ.L	#1, D1
	MOVE.B	D1,(A1,D0.W)	; BUTTON VALUE ON D0
	BSR.S	GETCOORD
	CMP	#SW3_MAXVALUES, D1
	BNE.B 	NOTMAX
	LEA	MIXEDVALUE(PC),A2
	MOVE.B	(A0)+,(A2)
	MOVE.B	(A0)+,1(A2)
	MOVE.L	A2,A0
	BSR.B	WRITETEXT	
	RTS
NOTMAX:
	CMP	#0, D1
	BNE.B 	NOTMIN
	LEA 	MIXEDVALUE+6(PC),A2
	MOVE.B	(A0)+,(A2)
	MOVE.B	(A0)+,1(A2)
	MOVE.L	A2,A0
	BSR.B	WRITETEXT	
	RTS
NOTMIN:
	BRA.B PRINTNUM
	
	
; GETCOORD - Get Ptr position from CoordsPtr
; CoordsPtrPos GETCOORD(BtnNum, CoordsPtr)
; A0                  D0      A0
GETCOORD:
	ADD.W	D0,D0
	LEA	(A0,D0.W),A0	; PUT COORDS OF SWITCH PRESSED ON A0
	RTS

NUMTOHEX:
;	DIVU	#100, D2
;	ADD.B	#'0', D2
;	MOVE.B	D2, 2(A2)
;	CLR.W	D2
;	SWAP	D2

	MOVE.B	#' ', 2(A2)

	DIVU	#10, D2
	ADD.B	#'0', D2
	MOVE.B	D2, 3(A2)
	SWAP	D2
	ADD.B	#'0', D2
	MOVE.B	D2, 4(A2)
	RTS



CLEARSCREEN:
	LEA	SCREEN,A0
	MOVE.W	#2000,D0
CLEARLOOP:
	CLR.L	(A0)+
	DBF	D0,CLEARLOOP
	RTS


PRINTMENU:				; PRINT MENU
	LEA	MENUTEXT(PC),A0 ; POINT TO MENU TEXT
; Write text - print text until char $FF
; WriteText(TextPtr)
;			A0
; TextPtr - pointer to text
; Example of a well formed text:
;	X,Y,'text',$00 - $00 = continue printing to next text
;	X,Y,'text',$ff - $ff = end printing text
WRITETEXT:
	LEA	SCREEN,A1		; SCREEN ON A1
	LEA	FONT(PC),A3		; FONT ON A3
LOOPER:
	MOVEQ	#0,D0		; RESET D0
	MOVEQ	#0,D1		; RESET D1
	MOVE.B	(A0)+,D0	; MOVE COORD X TO D0
	MOVE.B	(A0)+,D1	; MOVE COORD Y TO D1
	MULU	#[6*42],D1	; MULTIPLY COORD Y * CHARLEN * 42 LINES
				; IN ORDER TO POINT ON SCREEN AT Y COORD
	ADD.W	D1,D0		; ADD COORD Y TO X IN ORDER TO GET
				; POINT ON SCREEN
	LEA	(A1,D0.W),A2	; SCREEN XY DESTINATION TO A2
PRINTLOOP:
	MOVEQ	#0,D0		; RESET D0
	MOVE.B	(A0)+,D0	; POINT TO NEXT CHAR
	BEQ.S	LOOPER		; IF CHAR==0 TURN BACK AND CALCULATE
				; NEXT CHAR POSITION 
	CMP.B	#$FF,D0		; IF CHAR==$FF EXIT
	BEQ.S	END
	BSR.B	SETFONT		; GET CHAR FONT ADDRESS PTR
	MOVE.B	(A4),(A2)	; WRITE CHAR(A4) TO SCREEN(A2)
	MOVE.B	1(A4),42(A2)	
	MOVE.B	2(A4),84(A2)	
	MOVE.B	3(A4),126(A2)	
	MOVE.B	4(A4),168(A2)	
	ADDQ.L	#1,A2		; POINT TO SCREEN POSITION + 1
	BRA.S	PRINTLOOP	; TURN BACK TO CHECK NEXT CHAR
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
	BRA.B	INITTEXTPTR
NORESET:	
	LEA FONT(PC), A3
	LEA	SCREEN+SCROLL_V_OFFSET+40,A2	; PLOTPOSITION
	
STARTPLOT:
	BSR.B	SETFONT
	MOVE.B	(A4),(A2)
	MOVE.B	1(A4),42(A2)	
	MOVE.B	2(A4),84(A2)	
	MOVE.B	3(A4),126(A2)	
	MOVE.B	4(A4),168(A2)	
NOFONT:
	RTS

; FontAddr -- get char font address pointer
; FontAddr = SetFont(fontptr,charcode)
; A4                 A3      D0

SETFONT:
	SUB.B	#$20,D0
	MULU	#5,D0 ; THE 3 COMMANDS BELOW SUBSTITUTE THE MULU * 5
;	MOVE.W	D0,D1	; ***
;	ASL	#2,D1	; ***
;	ADD.L	D1,D0	; ***
	LEA	(A3,D0.W),A4
	RTS
	
SCROLL:

	MOVE.L	#SCREEN+SCROLL_V_OFFSET+(42*FONT_HEIGHT)+40, D0
	
	BLTWAIT BWT1

	MOVE.W	#$19F0,$40(A6)		; BLTCON0 COPY FROM A TO D ($F) 
					; 1 PIXEL SHIFT, LF = F0
	MOVE.W	#$0002,$42(A6)		; BLTCON1 USE BLITTER DESC MODE
					
	MOVE.L	#$FFFFFFFF,$44(A6)	; BLTAFWM / BLTALWM
					; BLTAFWM = $FFFF - 
					; BLTALWM = $FFFF 


	MOVE.L	D0,$50(A6)		; BLTAPT - SOURCE
	MOVE.L	D0,$54(A6)		; BLTDPT - DEST

	; SCROLL AN IMAGE OF THE FULL SCREEN WIDTH * FONT_HEIGHT

	MOVE.L	#$00000000,$64(A6)	; BLTAMOD + BLTDMOD 
	MOVE.W	#(6*64)+21,$58(A6)	; BLTSIZE
	
	RTS
	

WAITVB:
	TST.B	$DFF005
	BEQ.B	WAITVB
.LOOP
	TST.B	$DFF005
	BNE.S	.LOOP
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

	BSR.W	KEYGET
	BSR.W	PLOT
	BSR.B	SCROLL

	MOVE.W	#$4020,$9C(A6)		; Clear interrupt request
	MOVEM.L	(A7)+,D0-D7/A0-A6	; Get registers from stack
	RTE

;-----------------------------------------------


;*** DATA AREA ***

GfxName		DC.B	'graphics.library',0
	EVEN	
OldCopper:
	DC.L	0
OldIntena:
	DC.W	0
OldDma:
	DC.W	0
OldInter:
	DC.L	0

COORDS:		; switch trainer coordinate values
	DC.B	30,14
	DC.B	30,18
	DC.B	30,22

FIXEDVALUE:
	DC.B 0,0,'OFF',$ff
	DC.B 0,0,' ON',$ff
NUMVALUE:
	DC.B 0,0,'  0',$ff
MIXEDVALUE:
	DC.B 0,0,'MAX',$ff
	DC.B 0,0,'MIN',$ff
	
	
MENUTEXT:
	DC.B	10,2,'TRAINER MENU TEMPLATE',0
	DC.B	8,6, 'MENU BY FABRIZIO STELLATO',0
	DC.B	8,14,'F1 FIXED VALUES       OFF',0
	DC.B	8,18,'F2 NUMBER VALUES       00',0
	DC.B	8,22,'F3 MIXED VALUES       MAX'
	DC.B	$FF

	EVEN

SCROLLINGTEXT:
	DC.B	'TRAINER MENU BY FABRIZIO STELLATO   '
	DC.B	'           ',0
	
BUTTONS:
	DC.B	SW1_VALUE
	DC.B	SW2_VALUE
	DC.B	SW3_VALUE
COUNTER:
	DC.B	8
TEXTPTR
	DC.W	0


FONT:
	INCBIN	"/TRAINERS/FONT"
	
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
	DC.W	$0108,$0002	; Modolu (odd)
	DC.W	$010A,$0000	; Modolu (even)
	DC.W	$008E,$2C81	; Screen Size
	DC.W	$0090,$2CC1	; Screen Size
	DC.W	$0092,$0038	; H-start
	DC.W	$0094,$00D0	; H-stop
BPLPOINTERS:
	DC.W	$00e0,$0000 ; BITPLANE 0
	DC.W	$00e2,$0000 ; BITPLANE 0

	DC.W	$2707, $fffe
	DC.W	$0180, $055f
	DC.W	$2807, $fffe
	DC.W	$0180, $0004

	DC.W	$0182, $066f
	DC.W	$e107, $fffe
	DC.W	$0180, $055f
	DC.W	$e207, $fffe
	DC.W	$0180, $0000
	DC.W	$e507, $fffe

	DC.L	$FFFFFFFE

;*****************************
;*			     *
;*      SCREEN DATA AREA     *
;*			     *
;*****************************

	SECTION	Screen,BSS_C

SCREEN	DS.B	42*256

