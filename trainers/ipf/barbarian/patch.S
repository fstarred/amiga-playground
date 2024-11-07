*************************************************
*						*
*	      STARRED MEDIASOFT			*
*						*
*	      Barbarian TRAINER			*
*		VER 1.1 (2024)			*
*	 Original  (TOSEC 2012-04-10)		*
*		Barbarian  IPF			*
*						*
*						*	
*************************************************


	INCDIR	"DH1:/AMIGA-PLAYGROUND"



PROD	EQU 0			; FOR PRODUCTION
MENU	EQU 1			; SHOW TRAINER MENU ONLY
DEBUG	EQU 2			; FOR DEBUG

Mode=0	 		; 0=Prod,1=TrainerMenu only,2=Debug

SW1_MAXVALUE = 12
SW2_MAXVALUES = 2

SW1_VALUE = SW1_MAXVALUE
SW2_VALUE = 0

SW1_MINVALUE = 1

OldOpenLibrary	= -408
CloseLibrary	= -414
LoadSeg		= -150
UnLoadSeg	= -156
AllocMem	= -198

FONT_HEIGHT=5

SCROLL_V_OFFSET=(42*FONT_HEIGHT*37)

; A = AGNUS, D = DENISE, P = PAULA

;DMACON     096      W     A D P   DMA control write (clear or set)
;DMACONR    002      R     A   P   DMA control (and blitter status) read
DMASET=	%1000001111000000 ($8380)
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

	SECTION	MAIN,CODE_P

START:

	IF MODE<>DEBUG
	JSR	SHOWTRAINER
	ENDC

	IF MODE<>MENU
	BSR.W	LOADGAME
	ENDC
	
	RTS

; PLAYERS INIT ENERGY ORIGINAL CODE

; 700c                     moveq #$0c,d0
; 206c 29f0                movea.l (a4,$29f0),a0
; 2140 0024                move.l d0,(a0,$0024)
; 206c 29f4                movea.l (a4,$29f4),a0
; 2140 0024                move.l d0,(a0,$0024)
; 4e5d                     unlk.l a5

; SCENARIO INIT ORIGINAL CODE

; 7000                     moveq #$00,d0
; 2940 28b0                move.l d0,(a4,$28b0)
; 2940 0184                move.l d0,(a4,$0184)
; 396c 0900 2962           move.w (a4,$0900),(a4,$2962)
; 396c 0902 2964           move.w (a4,$0902),(a4,$2964)
; 2940 2a80                move.l d0,(a4,$2a80)
; 2940 2a92                move.l d0,(a4,$2a92)
; 6028                     bra.b #$28

PATCH_BEGIN:
	MOVE.L	(SP),STACK_ADDR_BACK		; store jsr address
	MOVEM.L	D0-D1/A2-A3,-(SP)

	MOVE.B	BUTTONS(PC),P1_ENERGY+1
	MOVE.B	BUTTONS+1(PC),P2_ENERGY+1

	LEA	FIXED_PATCH(PC),A2
	MOVE.L	A1,A3
	ADD.L	#$9C48,A3
	MOVEQ	#(END_FIXED_PATCH-FIXED_PATCH)-1,D0
.COPY_FIXED_PATCH
	MOVE.B	(A2)+,(A3)+
	DBF	D0,.COPY_FIXED_PATCH

	MOVE.L	#$4E714E71,D1

	MOVE.W	BUTTONS(PC),D0	
	CMP.W	#$0C0C,D0
	BEQ.W	.SCENARIO_TRAINER	

; == ENERGY TRAINER ==

	MOVE.L	A1,A3
	ADD.L	#$4D8C,A3
	MOVE.L	#$61004EC8,(A3)+		; BSR +$4EC8
	MOVE.L	#$700C600A,(A3)+		; MOVEQ #$0C,D0
						; BRA +$0A
	MOVE.L	D1,(A3)+			; NOP x4
	MOVE.W	D1,(A3)				; NOP
		
.SCENARIO_TRAINER:
	MOVE.B	BUTTONS+2(PC),D0
	BEQ	.LOAD_GAME

	MOVE.L	A1,A3
	ADD.L	#$69EE,A3
	MOVE.W	#$7000,(A3)+			; MOVEQ #0,D0
	MOVE.L	#$61003256,(A3)+		; BSR +$3256
	MOVE.L	D1,(A3)				; NOP x2

; -- HACK F7/F8 KEYS --

	MOVE.W	#$32EA,$6982(A1)		; BRA +$32EA
	MOVE.W	#$32E6,$6986(A1)		; BRA +$32E6

.LOAD_GAME:
   	MOVE.L	STACK_ADDR_BACK(PC),A2
	MOVE.W	#$4E75,(A2)+			; restore original opcodes
	MOVE.L	#$2E7A0BE6,(A2)			; restore original opcodes	
.EXIT_PATCH
	MOVEM.L (SP)+,D0-D1/A2-A3
	MOVE.L	STACK_ADDR_BACK(PC),(SP)	; back to original address
	
	RTS
STACK_ADDR_BACK:
	DC.L	0
BUTTONS:
	DC.B	SW1_VALUE
	DC.B	SW1_VALUE
	DC.B	SW2_VALUE
	EVEN
FIXED_PATCH:
; == SCENARIO INIT ==
	MOVE.L	SCENARIO_VALUE(PC),$28B0(A4)
	MOVE.L	ENEMY_VALUE(PC),$184(A4)
	RTS
; == ENERGY INIT ==
P1_ENERGY:
	MOVEQ	#$0C,D0
	MOVEA.L	$29F0(A4),A0
	MOVE.L	D0,$24(A0)
P2_ENERGY:
	MOVEQ	#$0C,D0
	MOVEA.L	$29F4(A4),A0
	MOVE.L	D0,$24(A0)
	RTS
; == SPECIAL KEYS ==
	MOVEM.L	D0/D1/A0,-(SP)
	SUB.W	#$56,D0
	ASL.W	#2,D0
	LEA.L	SCENARIO_VALUE(PC),A0
	MOVE.L	0(A0,D0.W),D1
	CMP.L	#7,D0
	BNE.W	.ADD_1
	SUBQ.W	#8,D1
.ADD_1
	ADDQ.W	#1,D1
	MOVE.L	D1,0(A0,D0.W)
	MOVEM.L	(SP)+,D0/D1/A0
	DC.L	$6000CD4C		; BRA +$CD4C
SCENARIO_VALUE:
	DC.L	0
ENEMY_VALUE:
	DC.L	0
END_FIXED_PATCH	

SHOWTRAINER:
;	--- Start ---

	MOVEM.L	D0-D7/A0-A6,-(SP)

	MOVE.L	$4.W,A6
	LEA	GFXLIBNAME(PC),A1
	JSR	OldOpenLibrary(A6)	; load graphics library
	MOVE.L	D0,A1
	MOVE.L	38(A1),OldCopper	; store old copper 1
	JSR	CloseLibrary(A6)	; close graphics library

;--- Store Old Register Settings ---

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

	BSR.W	WAITVB			; Wait for VBLANK

	MOVE.W	#DMASET,$96(A6)		; set bits of DMACON state
	MOVE.L	#COPLIST, $80(A6)	; set custom COPPERLIST

;--- Program Interrupt ---

	MOVE.L	$6C.W,OldInter		; store old INTER PTR

	MOVE.L	#INTER,$6C.W		: set interrupt pointer
	MOVE.W	#INTENA,$9A(A6)		; set bit of INTENA
	
;--- Main routine ---

	BSR.W	CLEARSCREEN
	BSR.W	PRINTMENU

LEFTMOUSE
	BTST	#6,$BFE001
	BNE.S	LEFTMOUSE

;--- Exit ---

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
	CLR.W	$88(A6)			; activate original COPPERLIST

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
	CMP.B 	#2,D0
	BCS	ELAB_PHEALTH

ELAB_FIXVAL:
	MOVEQ	#0,D1
	MOVE.B	(A1,D0.W),D1
	CMP.B	#SW2_MAXVALUES-1,D1
	BNE.B	NORESETVAL
	MOVEQ	#-1,D1
NORESETVAL
	ADDQ.L	#1,D1
	MOVE.B	D1,(A1,D0.W)		; STORE VALUE ON BUTTONS
	BSR.W	GETCOORD
	LEA 	SWITCHVALUE-6(PC), A2
.GETLABEL
	ADD.W 	#6,A2			; GET NEXT LABEL
	DBF 	D1, .GETLABEL	
	MOVE.B	(A0)+,(A2)
	MOVE.B	(A0)+,1(A2)
	MOVE.L	A2,A0
	BSR.W	WRITETEXT	
	RTS
	
ELAB_PHEALTH:
	MOVEQ	#0,D1
	MOVE.B	(A1,D0.W),D1	; BUTTON VALUE ON A1 
	CMP	#SW1_MINVALUE,D1
	BNE.B	NORESETHEALTHVAL
	MOVEQ	#SW1_MAXVALUE+1, D1
NORESETHEALTHVAL
	SUBQ.L	#1, D1
	MOVE.B	D1,(A1,D0.W)	; BUTTON VALUE ON D0
	BSR.S	GETCOORD
	CMP	#SW1_MAXVALUE, D1
	BNE.B 	PRINTNUM
	LEA	DEFVALUE(PC),A2
	MOVE.B	(A0)+,(A2)
	MOVE.B	(A0)+,1(A2)
	MOVE.L	A2,A0
	BSR.B	WRITETEXT	
	RTS
PRINTNUM:
	LEA NUMVALUE(PC),A2
	MOVE.B	(A0)+,(A2)
	MOVE.B	(A0)+,1(A2)
	MOVE.L	D1,D2
	BSR.B 	NUMTOHEX
	MOVE.L	A2,A0
	BSR.B	WRITETEXT
	RTS
	
	
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
	MULU	#FONT_HEIGHT,D0 ; THE 3 COMMANDS BELOW SUBSTITUTE THE MULU * 5
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

INTER:
	MOVEM.L	D0-D7/A0-A6,-(SP)
	LEA	$DFF000,A6	

;--- VBLANK Inter routine ---

	BSR.W	KEYGET
	BSR.W	PLOT
	BSR.B	SCROLL


	MOVE.W	#$4020,$9C(A6)		; clear interrupt request
	MOVEM.L	(SP)+,D0-D7/A0-A6
	RTE

LOADGAME:
	MOVE.L	$4.W,A6			;get execbase
	LEA	DOSLIB(PC),A1		;pointer to 'dos.library'
	JSR	OldOpenLibrary(A6)	;open dos.library
	TST.L	D0			;if d0 = 0 then libray open failed
	BEQ.W	PROBLEM

	MOVE.L	D0,DosLibPtr		;store dos library to var
	MOVE.L	D0,A6			;put dos.library base address in a6
	
	LEA	FILENAME(PC),A0		;get filename pc relative
	MOVE.L	A0,D1			;move filename into d1
	JSR	LoadSeg(A6)		;call loadseg
	TST.L	D0
	BEQ.W	PROBLEM

	IF	MODE=DEBUG

	MOVE.L	D0,-(SP)		;Store segment list pointer

	ENDC
	
	LSL.L	#2,D0			;multiply d0 * 4 to get correct address
	MOVE.L	D0,A0			;move address into a0

	MOVE.L	D0,A3
	
;	ID
;	BEG>	A0+$04
;	END>	A0+$46

LB_22E8	
;	MOVEM.L	D0-A6,-(SP)
	
	MOVE.L	A0,A2
	ADDA.L	#4,A0
	
	MOVE.L	#$00000200,D2
	MOVE.L	#$00000D58,D3
	MOVE.L	A0,A1
	ADDA.L	#$40,A1
	CLR.L	D0
LB_2302	
	CLR.L	D1
	MOVE.W	$00(A0,D0.W),D5
LB_2308	
	EOR.W	D5,$00(A1,D1.W)
	MOVE.W	$00(A1,D1.W),D5
	ADDQ.L	#2,D1
	CMP.W	D3,D1
	BNE.B	LB_2308
LB_2318	
	ADDQ.L	#2,D0
	CMP.W	#$0040,D0
	BEQ.B	LB_2318
	CMP.W	D2,D0
	BNE.B	LB_2302
LB_2328		
;---	Custom part	---

	ADD.L	#$FA,A3			; will jump to patch here
	MOVE.W	#$4EB9,(A3)+		; hack rts
	MOVE.L	#PATCH_BEGIN,(A3)	; jsr to patch

	ADD.L	#$4F8,A3		; hack read
	MOVE.W	#$4EB9,(A3)+		; jsr to hack_read
	MOVE.L	#HACK_READ,(A3)
	
	IF Mode=PROD

	MOVEM.L	D0-D7/A0-A6,-(SP)
	
	JMP	$44(A2)

	ENDC
	
	IF MODE=DEBUG
	
	MOVE.L	(SP)+,D1
	JSR	UnloadSeg(A6)
	BRA.B	CLOSELIB
	
	ENDC
	
PROBLEM:
	MOVEQ	#0,D0
	RTS
	
	IF MODE=DEBUG

CLOSELIB:
	MOVE.L	DosLibPtr,A1
	MOVE.L	4.W,A6			;get execbase
	JSR	CloseLibrary(A6)
	RTS

	ENDC

; mock read
; original opcodes:
; 1218                     move.b (a0)+,d1
; e149                     lsl.w #$08,d1
; b342                     eor.w d1,d2
HACK_READ:
	MOVEM.L	D3-D5/A1,-(SP)
	MOVE.L	16(SP),D3				; get jsr address
	SUBQ.L	#6,D3					; fix it
	MOVE.L	A0,D4					; computed address in d4
	
	CMP.L	D3,D4
	BCS.B	.INIT_HACKRTS
	
.INIT_HACKREAD
	LEA	OR_OPCODES_P1(PC),A1

.INIT
	MOVEQ	#(END_OR_OPCODES_P1-OR_OPCODES_P1)-1,D5	; both same size
.CHECK_ADDR:
	CMP.L	D3,D4
	BEQ.B	.ADDR_FOUND
	ADDQ.L	#1,D3
	ADDQ.L	#1,A1
	DBF	D5,.CHECK_ADDR
.ADDR_NOT_FOUND:
	MOVE.B	(A0)+,D1
	BRA.B	.DO_LSL_EOR
.ADDR_FOUND:
	MOVE.B	(A1),D1
	ADDQ.L	#1,A0
.DO_LSL_EOR:
	LSL.W	#$08,D1
	EOR.W	D1,D2
	MOVEM.L	(SP)+,D3-D5/A1
	RTS

.INIT_HACKRTS
	LEA	OR_OPCODES_P2(PC),A1
	SUB.L	#$4FA,D3
	BRA.B	.INIT

OR_OPCODES_P1:
	DC.W	$1218		; move.b (a0)+,d1
	DC.W	$E149		; lsl.w #$08,d1
	DC.W	$B342		; eor.w d1,d2
END_OR_OPCODES_P1

OR_OPCODES_P2:
	DC.W	$4E75		; rts
	DC.L	$2E7A0BE6	; movea.l (pc,$0be6),a7
END_OR_OPCODES_P2

JMP_OLD_INTER:
	JMP	$0
HACK_ADDRESS:
	DC.L	0
END_INTERKBD

;*** DATA AREA ***

filename:
	dc.b	'df0:main',0
doslib:
	dc.b	'dos.library',0
GfxLibName:
	DC.B	'graphics.library',0
DosLibPtr	
	DC.L	0
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

NUMVALUE:
	DC.B 0,0,'  0',$ff
DEFVALUE:
	DC.B 0,0,'DEF',$ff
SWITCHVALUE:
	DC.B 0,0,'OFF',$ff
	DC.B 0,0,' ON',$ff

	
	
MENUTEXT:
	DC.B	11,2,'BARBARIAN (PALACE)',0
	DC.B	6,6, 'TRAINER BY FABRIZIO STELLATO',0
	DC.B	8,14,'F1 P1 HEALTH          DEF',0
	DC.B	8,18,'F2 P2 HEALTH          DEF',0
	DC.B	8,22,'F3 MAGIC KEYS (F7/F8) OFF'
	DC.B	$FF

	EVEN

SCROLLINGTEXT:
	DC.B	'BARBARIAN (PALACE) TRAINER+ BY FABRIZIO STELLATO   '
	DC.B	' - TESTED ON A500. DOES NOT WORK ON NEWER AMIGA!'
	DC.B	'           ',0	
COUNTER:
	DC.B	8
	EVEN
TEXTPTR
	DC.W	0

FONT:
	INCBIN	"/TRAINERS/FONT"

	
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

	SECTION	Screen,BSS_C

SCREEN	DS.B	42*256
