***********************************
*
*
*	TRAINER FROM BOOTBLOCK
*
*
***********************************

; attached with bblocktrd code
; note: all addresses must be relative referenced (i.e. with PC)

SECTORS=3

WriteFlag=0

	IF WriteFlag=1
	AUTO	WS\START\$73C00/$200\SECTORS\CC\
	ENDC

OldOpenLibrary	= -408
CloseLibrary 	= -414
OpenFont	=  -72
AllocRaster	= -492
FreeRaster	= -498

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

SCR_WIDTH=320+16
SCR_HEIGHT=256

SW1_MAXVALUES = 2

SW1_VALUE = 0
SW2_VALUE = 0
;SW3_VALUE = 1


FONT_HEIGHT=8
SCROLL_V_OFFSET=(40*FONT_HEIGHT*24+2)+(42*FONT_HEIGHT)
		; for the first 24 rows modulo is default
		; on 25th row, modulo is + 2


BLTWAIT	MACRO
	tst $dff002			;for compatibility
\1
	btst #6,$dff002
	bne.s \1
	ENDM

START:
	BRA.S	SHOWTRAINER
PATCH:
	MOVEM.L	D0-D7/A0-A6,-(SP)
	LEA	BUTTONS(PC),A1
UNLIMITED_BOOST:
	TST.B	(A1)+
	BEQ.B	NO_CAR_DAMAGE
	LEA	$60840,A0
	MOVE.L	#$4E714E71,(A0)+
	MOVE.W	#$4E71, (A0)
NO_CAR_DAMAGE:
	TST.B	(A1)+
	BEQ.B	LOADGAME
	LEA	$61CC2,A0
	MOVE.L	#$4E714E71,(A0)+
	MOVE.W	#$4E71,(A0)
	LEA	$61DEA,A0
	MOVE.L	#$4E714E71,(A0)+
	MOVE.W	#$4E71,(A0)
	LEA	$61F12,A0
	MOVE.L	#$4E714E71,(A0)+
	MOVE.W	#$4E71,(A0)
	MOVE.L	#$4E714E71,$63E1A
	MOVE.L	#$4E714E71,$6627A	
LOADGAME
	MOVEM.L (SP)+,D0-D7/A0-A6
	JMP	$1BA08  
BUTTONS:
	DC.B	SW1_VALUE
	DC.B	SW2_VALUE
;	DC.B	SW3_VALUE
	
	
SHOWTRAINER:
	MOVEM.L	D0-D7/A0-A6,-(SP)
	
	MOVE.L	$4.W,A6
	LEA	GFXNAME(PC),A1
	JSR	OldOpenLibrary(A6)	; load graphics library
	MOVE.L	D0,A6
	
	LEA	OldCopper(PC),A0
	MOVE.L	$26(A6),(A0)
	
;---  Get charset  ---

	LEA	TEXTATTR(PC),A0
	LEA	FONTNAME(PC),A1
	MOVE.L	A1,(A0)
	JSR	OpenFont(A6)
	MOVE.L	D0,A0
	MOVE.L	34(A0),A3		; Bit ptr
	MOVE.W	38(A0),D7		; Modulo
	
;---  Allocate Raster  ---

	MOVE.L	#SCR_WIDTH,D0		; Width
	MOVE.L	#SCR_HEIGHT,D1		; Higth
	JSR	AllocRaster(A6)		; Allocate memory for bitplane WxH
	LEA	ScreenPtr(PC),A0	
	MOVE.L	D0,(A0)			; Write btpl ptr on ScreenPtr
	
;--- Clear screen  ---

	MOVE.L	(A0),A0			; Point A0 to bitplane address
	MOVE.W	#SCR_WIDTH/8*SCR_HEIGHT/4-1,D1	; Clear 320/8 bytes wide
	MOVEQ	#0,D2			; times 260 bytes high
	
.LOOPC	
	MOVE.L	D2,(A0)+		; in longwords / 4
	DBF	D1,.LOOPC

;---  Set BPL ptrs  ---

	LEA.L	BITPLANES+2(PC),A0
	SWAP	D0		; High word of pointer
	MOVE.W	D0,(A0)		; Store high 1
	ADDQ.W	#4,A0
	SWAP	D0		; Low word of pointer
	MOVE.W	D0,(A0)		; Store low 1

	LEA	$DFF000,A6
	
	LEA	OldIntena(PC),A0
	MOVE.W	$1C(A6),(A0)		; store old INTENA (INTENAR)
	LEA	OldDma(PC),A0
	MOVE.W	$02(A6),(A0)		; store old DMACON (DMACONR)	
	LEA	OldInter(PC),A0		
	MOVE.L	$6C.W,(A0)		; store old INTER

;--- Disable Interrupt

	MOVE.W	#$7FFF,$9A(A6)		; Clear interrupt enable
	BSR.W	WAITVB			; Wait for VBLANK

;--- Disable Dma

	MOVE.W	#$7FFF,$96(A6)		; Dma disable
	
;--- Set Interrupt request ---

	LEA	INTER(PC),A0
	MOVE.L	A0,$6C.W

;--- Set Interrupt

	MOVE.W	#$7FFF,$9C(A6)		; Clear request
	MOVE.W	#INTENA,$9A(A6)		; Interrupt enable

;--- Set copperlist ---

	LEA	COPPERLIST(PC),A0	
	MOVE.L	A0,$80(A6)		; write our copperlist to COP1 loc reg
	MOVE.W	$88(A6),D0		; Launch COPJMP1

;--- Set Dma ---

	MOVE.W	#DMASET,$96(A6)		; set bits of DMACON state


;--- Main routine ---

	BSR.W	PRINTMENU

.NOLEFTTMOUSE
	BTST	#6,$BFE001
	BEQ.S	.NOLEFTTMOUSE

.LEFTTMOUSE
	BTST	#6,$BFE001
	BNE.S	.LEFTTMOUSE

;.RIGHTMOUSE
;	BTST	#10,$DFF016
;	BNE	.RIGHTMOUSE

	LEA	$DFF000,A6

	MOVE.W	#$7FFF,$9A(A6)		; disable interrupts
	
	BSR.W	WAITVB

	MOVE.W	#$7FFF,$96(A6)		; disable DMA
		
	MOVE.W	OldDma(PC),D0
	OR.W	#$8000,D0		; set bits of DMACON state
	MOVE.W	D0,$96(A6)		; restore original DMACON

	MOVE.L	OldCopper(PC),$80(A6)	; restore original COPPERLIST
	CLR.W	$88(A6)			; activate original COPPERLIST

	MOVE.L	OldInter(PC),$6C.W	; restore inter pointer

	MOVE.W	#$7FFF,$9C(A6)		; clear requests

	MOVE.W	OldIntena(PC),D0
	OR.W	#$C000,D0		; set bits of INTENA state
	MOVE.W	D0,$9A(A6)		; restore original INTENA
	
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
	CMP.B	#$51,D0
	BGT.W	NOFONT		; IF > 52 EXIT
	SUB.B	#$50,D0		; F1 = 0, F2 = 1, F3 = 2..
	
	
;	NOTE: A WELL FORMED LABEL IS COMPOSED BY:
;		X,Y,'CHR',($00|$ff)
;		B,B,BBB,B
;	FOR A TOTAL OF 6 BYTES
ELABSWITCH:
	LEA	COORDS(PC),A0
	LEA	BUTTONS(PC),A1
	
ELAB_FIXVAL:
	MOVEQ	#0,D1
	MOVE.B	(A1,D0.W),D1
	CMP.B	#SW1_MAXVALUES-1,D1
	BNE.B	NORESETVAL
	MOVEQ	#-1,D1
NORESETVAL
	ADDQ.L	#1,D1
	MOVE.B	D1,(A1,D0.W)		; STORE VALUE ON BUTTONS
	BSR.B	GETCOORD
	LEA  FIXEDVALUE-6(PC), A2
GETLABEL
	ADD.W #6, A2			; GET NEXT LABEL
	DBRA D1, GETLABEL	
	MOVE.B	(A0)+,(A2)
	MOVE.B	(A0)+,1(A2)
	MOVE.L	A2,A0
	BSR.B	WRITETEXT	
	RTS
	
; GetCoord - Get Ptr position from CoordsPtr
; CoordsPtrPos GetCoord(BtnNum, CoordsPtr)
; A0			D0      A0
GETCOORD:
	ADD.W	D0,D0
	LEA	(A0,D0.W),A0	; PUT COORDS OF SWITCH PRESSED ON A0
	RTS


PRINTMENU:				; PRINT MENU
	LEA	MENUTEXT(PC),A0 ; POINT TO MENU TEXT
; Write text - print text until char $FF
; WriteText(TextPtr,FontPtr)
;	    A0	    A3
; TextPtr - pointer to text
; FontPtr - pointer to font set
; Example of a well formed text:
;	X,Y,'text',$00 - $00 = continue printing to next text
;	X,Y,'text',$ff - $ff = end printing text
WRITETEXT:
	MOVE.L	ScreenPtr(PC),A1
LOOPER:
	MOVEQ	#0,D0		; RESET D0
	MOVEQ	#0,D1		; RESET D1
	MOVE.B	(A0)+,D0	; MOVE COORD X TO D0
	MOVE.B	(A0)+,D1	; MOVE COORD Y TO D1
	MULU	#[8*40],D1	; MULTIPLY COORD Y * CHARLEN * 40 LINES
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
	BEQ.S	ENDWT
	BSR.B	SETFONT		; GET CHAR FONT ADDRESS PTR

	MOVEQ	#8-1,D0			; copy 8 bytes
.LOOP1	
	MOVE.B	(A4),(A2)		; Copy one byte from char
	ADD.W	D7,A4			; next byte in char
	ADD.W	#40,A2			; next raster line
	DBF	D0,.LOOP1		; Loop ^	

	SUB.L	#SCR_WIDTH-16-1,A2	; POINT TO SCREEN POSITION + 1
	BRA.S	PRINTLOOP		; TURN BACK TO CHECK NEXT CHAR
ENDWT:
	RTS

; FontAddr -- get char font address pointer
; FontAddr = SetFont(fontptr,charcode)
; A4                 A3      D0

SETFONT:
	SUB.B	#$20,D0
	LEA	(A3,D0.W),A4
	RTS

PLOT:
	LEA	COUNTER(PC),A0
	SUBQ.B	#1,(A0)
	BNE.S	NOFONT
	MOVE.B	#8,(A0)
INITTEXTPTR:
	LEA	SCROLLINGTEXT(PC),A0
	LEA	TEXTPTR(PC),A1
	MOVE.W	(A1),D1
	ADD.W	D1,A0
	ADDQ	#1, D1
	MOVE.W	D1,(A1)
	
	MOVEQ	#0,D0
	MOVE.B	(A0),D0
	BNE.S	NORESET
	LEA	TEXTPTR(PC),A0
	MOVE.W	#0,(A0)
	BRA.S	INITTEXTPTR
NORESET:	
	MOVE.L	ScreenPtr(PC),A2
	ADD.L	#SCROLL_V_OFFSET+40,A2
	
STARTPLOT:
	BSR.S	SETFONT
	MOVEQ	#8-1,D0			; copy 8 bytes
.LOOP1	
	MOVE.B	(A4),(A2)		; Copy one byte from char
	ADD.W	D7,A4			; next byte in char
	ADD.W	#42,A2			; next raster line
	DBF	D0,.LOOP1		; Loop ^	
NOFONT:
	RTS

SCROLL:
	MOVE.L	ScreenPtr(PC),D0
	ADD.L	#SCROLL_V_OFFSET+(42*FONT_HEIGHT)+40,D0

	LEA	$DFF000,A6
	
	BLTWAIT BWT1

	MOVE.W	#$19F0,$40(A6)		; BLTCON0 COPY FROM A TO D ($F) 
					; 1 PIXEL SHIFT, LF = F0
	MOVE.W	#$0002,$42(A6)		; BLTCON1 USE BLITTER DESC MODE
					
	MOVE.L	#$FFFFFFFF,$44(A6)	; BLTAFWM / BLTALWM
					; BLTAFWM = $FFFF - 
					; BLTALWM = $FFFF 


	MOVE.L	D0,$50(A6)		; BLTAPTH - SOURCE
	MOVE.L	D0,$54(A6)		; BLTDPTH - DEST

	; SCROLL AN IMAGE OF THE FULL SCREEN WIDTH * FONT_HEIGHT

	MOVE.L	#$00000000,$64(A6)			; BLTAMOD + BLTDMOD 
	MOVE.W	#((FONT_HEIGHT+1)*64)+21,$58(A6)	; BLTSIZE
	
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
	
	MOVE.L	ScreenPtr(PC),A0
	
	BSR.W	KEYGET
	BSR.W	PLOT
	BSR.B	SCROLL	
		
	MOVE.W	#$4020,$9C(A6)		; Clear interrupt request
	MOVEM.L	(SP)+,D0-D7/A0-A6
	
	RTE
	
ScreenPtr:	
	DC.L	0
OldCopper:
	DC.L	0
OldIntena:
	DC.W	0
OldDma:
	DC.W	0
OldInter:
	DC.L	0
TEXTATTR:
	DC.L	0
	DC.W	8
	DC.B	0
	DC.B	0
	DC.W	8
FONTNAME:	DC.B	'topaz.font',0
GFXNAME:
	DC.B	'graphics.library',0
MENUTEXT:
	DC.B	8,2, 'STUNT CAR RACER TRAINER',0
	DC.B	10,7, 'BY FABRIZIO STELLATO',0
	DC.B	8,14,'F1 UNLIMITED BOOST    OFF',0
	DC.B	8,18,'F2 NO CAR DAMAGE      OFF'
	DC.B	$FF
SCROLLINGTEXT:
	DC.B	'*** STUNT CAR RACER (CRACKED BY QUARTEX) TRAINER '  
	DC.B	'BY FSTARRED  ',0
COORDS:		; switch trainer coordinate values
	DC.B	30,14
	DC.B	30,18
;	DC.B	30,22
FIXEDVALUE:
	DC.B 0,0,'OFF',$ff
	DC.B 0,0,' ON',$ff
COUNTER:
	DC.B	8	; TODO check len
	EVEN
TEXTPTR
	DC.W	0	; TODO check len	
COPPERLIST:
	DC.L	$01800000
	DC.L	$01820FFF
BITPLANES:
	DC.L	$00E00000	; Bitplane 1 pointer high bits
	DC.L	$00E20000	; Bitplane 1 pointer low bits
	DC.L	$00E40000	; Bitplane 2 pointer hight bits
	DC.L	$00E60000	; Bitplane 2 pointer low bits
	DC.L	$01001200	; BPLCON0 Bitplane control register
	DC.L	$01020000	; BPLCON1
	DC.L	$01040000	; BPLCON2
	DC.L	$01080000	; Bitplane modulo (odd planes)
	DC.L	$010A0000	; Bitplane modulo (even planes)
	DC.L	$008E2C78	; DIWSTRT
	DC.L	$00902CC8	; DIWSTOP
	DC.L	$00920038	; DDFSTRT
	DC.L	$009400D0	; DDFSTOP


	DC.L	$2E07FFFE
	DC.L	$01800955
	DC.L	$2F07FFFE
	DC.L	$01800400

	DC.L	$4E07FFFE
	DC.L	$01800955
	DC.L	$4F07FFFE
	DC.L	$01800500

	DC.L	$7E07FFFE
	DC.L	$01800955
	DC.L	$7F07FFFE
	DC.L	$01800600

	DC.L	$E807FFFE
	DC.L	$01800955
	DC.L	$E907FFFE
	DC.L	$01800400
	
	DC.L	$EB07FFFE
	DC.L	$01080002	; Bitplane modulo (odd planes)

	DC.L	$FFFFFFFE
END

BIN_LEN=512*SECTORS

	DS.B	BIN_LEN-(END-START)

	IF (END-START)>BIN_LEN
	FAIL
	ENDC

	PRINTT	"PROG REAL SIZE..."
	PRINTV	END-START
