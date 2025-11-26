*************************************************
*						*
*						*
*	System OFF with VBLANK Interrupt	*
*						*
*						*
*************************************************

; If you want to debug with Assembler (i.e. ASM-One),
; comment the following lines:
;
; MOVE.L #$7FFF7FFF,$9A(A6)	; disable INTENA/INTREQ ; at least disable
;				INTREQ
; MOVE.W #$7FFF, $96(A6)	; disable DMACON
; MOVE.L #COPPERLIST, $80(A6)	; this trigger our custom copperlist
;
; MOVE.L #INTER,$6C.W		: set interrupt pointer
; MOVE.W #INTENA,$9A(A6)	; set bit of INTENA



OldOpenLibrary = -408
CloseLibrary = -414

; A = AGNUS, D = DENISE, P = PAULA

;DMACON     096      W     A D P   DMA control write (clear or set)
;DMACONR    002      R     A   P   DMA control (and blitter status) read
DMASET=	%1000001110100000
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
INTENA=	%1100000000100000
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


BALL_VPOS=$2C
BALL_HPOS=$80
BALL_HEIGHT=32
BALL_FRAMEWIDTH=16
BALL_FRAME_SIZE=$88

SPIN_FRAME_COUNT=8
SPIN_FRAME_RATE=4

MOVE_SPEED_RATE=4

	SECTION	PROGRAMCODE,CODE

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


;--- Set Register Settings ---

	BSR	WAITVB			; Wait for VBLANK

	MOVE.W	#DMASET,$96(A6)		; set bits of DMACON state
	MOVE.L	#COPPERLIST, $80(A6)	; set custom COPPERLIST

;--- Program Interrupt ---

	MOVE.L	$6C.W,OldInter		; store old INTER PTR

	MOVE.L	#INTER,$6C.W		; set interrupt pointer
	MOVE.W	#INTENA,$9A(A6)		; set bit of INTENA

	MOVEQ	#0,D0
	MOVE.W	D0,$88(A6)
	MOVE.W	D0,$1FC(A6)		; forces ECS compatibility
	
INIT
	MOVE.L	#BITPLANE,D0		; point to bitplane data
	LEA	BPLPOINTERS,A1		; point to BPL1PT register
	MOVE.W	D0,6(A1)		; BPL1PTL
	SWAP	D0
	MOVE.W	D0,2(A1)		; BPL1PTH

LEFTMOUSE
	BTST	#6,$BFE001
	BNE.S	LEFTMOUSE

**** EXIT - RESTORE OLD REG SETTINGS ****

	LEA	$DFF000,A6

	MOVE.W	#$7FFF,$9A(A6)		; disable interrupts	

	BSR.S	WAITVB

	MOVE.W	#$7FFF,$96(A6)		; disable DMA
	
	MOVE.W	OldDma(PC),D0
	OR.W	#$8000,D0		; set bits of DMACON state
	MOVE.W	D0,$96(A6)		; restore original DMACON

	MOVE.L	OldCopper,$80(A6)	; restore original COPPERLIST
	MOVE.W	D0,$88(A6)		; activate original COPPERLIST

	MOVE.L	OldInter(PC),$6C.W	; restore inter pointer

	MOVE.W	#$7FFF,$9C(A6)		; clear requests

	MOVE.W	OldIntena(PC),D0
	OR.W	#$C000,D0		; set bits of INTENA state
	MOVE.W	D0,$9A(A6)		; restore original INTENA
	
	MOVEM.L (SP)+,D0-D7/A0-A6

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

	BTST.B	#5,$01F(A6)		; check INTREQR
	BEQ.W	EXIT	

	SUB.B	#1,MoveSpeedCounter
	BNE.W	CHECKSPIN
	MOVE.B	#MOVE_SPEED_RATE,MoveSpeedCounter

LSPRITE	
	LEA	SPRITEPOINTERS,A1
	MOVE.L	CurrentSpinFrameOffset(PC),D0
	MOVE.W	D0,6(A1)
	SWAP	D0
	MOVE.W	D0,2(A1)
	SWAP	D0	

LMOVE
	MOVE.L	D0,A2
	MOVE.B	#BALL_VPOS,(A2)
	MOVE.B	#(BALL_VPOS+BALL_HEIGHT),2(A2)
	CLR.B	3(A2)

.MOVEX
	MOVEQ	#0,D1
	LEA	CurrCoordX(PC),A3
	MOVE.B	(A3),D1
	CMPI.B	#COORDX_COUNT-2,D1
	BNE.B	.NEXT_COORDX
	MOVEQ	#-2,D1
.NEXT_COORDX
	ADDQ.W	#2,D1
	MOVE.B	D1,(A3)
	LEA	COORDX,A3
	MOVE.W	(A3,D1.W),D1

	LSR	#1,D1
	BCS.B	.SETLBX
	BCLR.B	#0,3(A2)
	BRA.B	.SETPOSX
.SETLBX
	BSET.B	#0,3(A2)	
.SETPOSX
	MOVE.B	D1,1(A2)	
.EMOVEX

RSPRITE
	ADDQ.L	#8,A1
	ADD.L	#BALL_FRAME_SIZE,D0
	MOVE.W	D0,6(A1)
	SWAP	D0
	MOVE.W	D0,2(A1)
	SWAP	D0

RMOVE
	MOVE.L	D0,A2
	MOVE.B	#BALL_VPOS,(A2)
	MOVE.B	-BALL_FRAME_SIZE+1(A2),D1
	ADDQ.B	#BALL_FRAMEWIDTH/2,D1
	MOVE.B	D1,1(A2)
	MOVE.B	#BALL_VPOS+BALL_HEIGHT,2(A2)
	MOVE.B	-BALL_FRAME_SIZE+3(A2),3(A2)

CHECKSPIN
	SUB.B	#1,CurrentSpinFrameRate
	BNE.W	EXIT

	MOVE.B	#SPIN_FRAME_RATE, CurrentSpinFrameRate	
CHECKFRAME
	SUB.B	#1,SpinFrameCounter
	BNE.B	.NEXTFRAME
	MOVE.B	#SPIN_FRAME_COUNT, SpinFrameCounter
	MOVE.L	#FRAME1,CurrentSpinFrameOffset
	BRA.B	EXIT
.NEXTFRAME	
	ADD.L	#BALL_FRAME_SIZE*2,CurrentSpinFrameOffset
EXIT
	MOVE.W	#$0020,$9C(A6)		; clear interrupt request
	MOVEM.L	(SP)+,D0-D7/A0-A6
	RTE
	

GFXNAME:
	DC.B	'graphics.library',0
	EVEN
OldCopper:
	DC.L	0
OldIntena:
	DC.W	0
OldDma:
	DC.W	0
OldInter:
	DC.L	0

CurrentSpinFrameRate
	DC.B	1
SpinFrameCounter
	DC.B	SPIN_FRAME_COUNT
CurrentSpinFrameOffset
	DC.L	FRAME1

CurrCoordX
	DC.B	COORDX_COUNT-2
MoveSpeedCounter
	DC.B	MOVE_SPEED_RATE

COORDX:
	DC.W	$80,$81,$82,$83,$84,$85,$86,$85,$84,$83,$82,$81
ECOORDX

COORDX_COUNT=ECOORDX-COORDX
	
	SECTION COPPER,DATA_C

COPPERLIST:

	DC.W	$8E,$2C81	; DiwStrt
	DC.W	$90,$2CC1	; DiwStop
	DC.W	$92,$38		; DdfStart
	DC.W	$94,$D0		; DdfStop
	DC.W	$102,0		; BplCon1
	DC.W	$104,0		; BplCon2
	DC.W	$108,0		; Bpl1Mod
	DC.W	$10A,0		; Bpl2Mod

SPRITEPOINTERS:
	DC.W    $120,0,$122,0,$124,0,$126,0 ; SPR0/1PT
	DC.W	$128,0,$12A,0,$12C,0,$12E,0 ; SPR2/3PT
	DC.W	$130,0,$132,0,$134,0,$136,0 ; SPR4/5PT
	DC.W	$138,0,$13A,0,$13C,0,$13E,0 ; SPR6/7PT

BPLPOINTERS:
	DC.W	$E0,0,$E2,0	; BPL1PT
	
	DC.W	$100,$1200	; BPLCON0

	DC.W	$0180,$000	; COLOR0
	DC.W	$0182,$FFF	; COLOR1


	DC.W	$01A0,$0000
	DC.W	$01A2,$0E00
	DC.W	$01A4,$0FFF
	DC.W	$01A6,$0FFF

	DC.L	$FFFFFFFE	; stop copper instructions until next vblank

	incdir	"RESOURCES:graphics/ball/"

FRAME1:
	include "ball001a.S"
	include "ball001b.S"
FRAME2:
	include "ball002a.S"
	include "ball002b.S"	
FRAME3:
	include "ball003a.S"
	include "ball003b.S"
FRAME4:
	include "ball004a.S"
	include "ball004b.S"	
FRAME5:
	include "ball005a.S"
	include "ball005b.S"
FRAME6:
	include "ball006a.S"
	include "ball006b.S"	
FRAME7:
	include "ball007a.S"
	include "ball007b.S"
FRAME8:
	include "ball008a.S"
	include "ball008b.S"	

	SECTION	BITPLANES,DATA_C
	
BITPLANE:
	DCB.B	40*256		; blank bitplane
	
END

*                           Agnus/
*                   Read/   Denise/
* Register Address  Write   Paula         Function
* -------- -------  -----   -------       --------
* SPRxCTL    142      W     A D( E ) Sprite x vert stop position and
*                                        control data
* SPRxPOS    140      W      A D     Sprite x vert-horiz start position data
* 
*                  These two registers work together as position, size and
*                  feature sprite-control registers.  They are usually loaded
*                  by the sprite DMA channel during horizontal blank;
*                  however, they may be loaded by either processor at any
*                  time.  SPRxPOS register:
* 
*                  BIT#   SYM      FUNCTION
*                  ----   ----     -----------------------------
*                  15-08  SV7-SV0  Start vertical value. High bit(SV8) is
*                                  in SPRxCTL register below.
*                  07-00  SH8-SH1  Start horizontal value. Low bit(SH0) is
*                                  in SPRxCTL register below.
* 
*                  SPRxCTL register (writing this address disables sprite
*                                    horizontal comparator circuit):
* 
*                  BIT#    SYM       FUNCTION
*                  ----    --------  -----------------------------
*                  15-08   EV7-EV0   End (stop) vertical value low 8 bits
*                  07      ATT       Sprite attach control bit (odd sprites)
*                  06-04    X        Not used
*                  02      SV8       Start vertical value high bit
*                  01      EV8       End (stop) vertical value high bit
*                  00      SH0       Start horizontal value low bit
