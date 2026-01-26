*************************************************
*						*
*						*
*	Blitter copy memory area		*
*						*
*						*
*************************************************


OldOpenLibrary = -408
CloseLibrary = -414

; A = AGNUS, D = DENISE, P = PAULA

;DMACON     096      W     A D P   DMA control write (clear or set)
;DMACONR    002      R     A   P   DMA control (and blitter status) read
DMASET=	%1000001111000000
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


WAITBLIT	MACRO
	BTST.B	#6,$02(A1)
	BTST.B	#6,$02(A1)
	BNE.B	*-6
	ENDM


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
	
INIT

	MOVE.L	#BITPLANE,D0
	LEA	BPLPOINTERS,A1		; point to BPL1PT register
	MOVEQ	#1,D7
.POINTBPL	
	MOVE.W	D0,6(A1)		; BPL1PTL
	SWAP	D0
	MOVE.W	D0,2(A1)		; BPL1PTH
	SWAP	D0

	ADDI.L	#40*256,D0
	ADDQ.W	#8,A1
	DBRA	D7,.POINTBPL


	MOVEQ	#0,D0
	MOVE.W	D0,$88(A6)
	MOVE.W	D0,$1FC(A6)

	LEA	$DFF000,A1

	WAITBLIT

.COPY_FROM_IMAGE
	MOVE.W	#$09F0,$40(A1)		; BLTCON0 - USEA+USED LF=$F0 (D=A)
	CLR.W	$42(A1)			; BLTCON1
	MOVE.W	#$FFFF,$44(A1)		; BLTAFWM - full copy
	MOVE.W	#$FFFF,$46(A1)		; BLTALWM - full copy
	MOVE.L	#Brick,$50(A1)		; BLTAPT  channel A point to bitplane
	MOVE.L	#BITPLANE,$54(A1)	; BLTDPT  channel D point to bitplane
	MOVE.W	#0,$64(A1)		; BLTAMOD - 0 bytes of modulo
	MOVE.W	#38,$66(A1)		; BLTDMOD - 40-2 bytes of modulo
	MOVE.W	#(8<<6)+1,$58(A1)	; BLTSIZE 8 height * 1 words width

	WAITBLIT

.COPY_HORIZONTALLY
	MOVE.L	#BITPLANE,$50(A1)	; BLTAPT  channel A point to bitplane
	MOVE.L	#BITPLANE+2,$54(A1)	; BLTDPT  channel D point to bitplane
	MOVE.W	#40-2,$64(A1)		; BLTAMOD - 40-2 bytes of modulo
	MOVE.W	#40-2,$66(A1)		; BLTDMOD - 40-2 bytes of modulo
	MOVE.W	#(8<<6)+1,$58(A1)	; BLTSIZE 

	WAITBLIT

.COMPLETE_HORIZONTAL_COPY
	MOVE.L	#BITPLANE,$50(A1)	; BLTAPT  channel A point to bitplane
	MOVE.L	#BITPLANE+4,$54(A1)	; BLTDPT  channel D point to bitplane
	MOVE.W	#4,$64(A1)		; BLTAMOD - 40-36 bytes of modulo
	MOVE.W	#4,$66(A1)		; BLTDMOD - 40-36 bytes of modulo
	MOVE.W	#(8<<6)+18,$58(A1)	; BLTSIZE

	WAITBLIT

.COMPLETE_VERTICAL_COPY
	MOVE.L	#BITPLANE,$50(A1)	; BLTAPT  channel A point to bitplane
	MOVE.L	#BITPLANE+(40*8),$54(A1); BLTDPT  channel D point to bitplane
	MOVE.W	#0,$64(A1)		; BLTAMOD - 0 bytes of modulo
	MOVE.W	#0,$66(A1)		; BLTDMOD - 0 bytes of modulo
	MOVE.W	#((8*31)<<6)+20,$58(A1)	; BLTSIZE 

	WAITBLIT

DRAWBALL
	MOVE.W	#$09F0,$40(A1)		; BLTCON0 - USEA+USED LF=$F0 (D=A)
	CLR.W	$42(A1)			; BLTCON1
	MOVE.W	#$FFFF,$44(A1)		; BLTAFWM - full copy
	MOVE.W	#$FFFF,$46(A1)		; BLTALWM - full copy
	MOVE.L	#Ball,$50(A1)		; BLTAPT  channel A point to bitplane
	MOVE.L	#BITPLANE,$54(A1)	; BLTDPT  channel D point to bitplane
	MOVE.W	#0,$64(A1)		; BLTAMOD - 0 bytes of modulo
	MOVE.W	#24,$66(A1)		; BLTDMOD - 40-2 bytes of modulo
	MOVE.W	#(128<<6)+8,$58(A1)	; BLTSIZE 

	WAITBLIT

	MOVE.L	#Ball+2048,$50(A1)		; BLTAPT  channel A point to bitplane
	MOVE.L	#BITPLANE2,$54(A1)	; BLTDPT  channel D point to bitplane
	MOVE.W	#(128<<6)+8,$58(A1)	; BLTSIZE 


EXIT

.LMPRESS
	BTST	#6,$BFE001
	BNE.S	.LMPRESS

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
	LEA	$DFF000,A1

	BTST.B	#5,$01F(A6)
	BEQ.B	.EXIT			

	NOP

.EXIT
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

	SECTION DATA,DATA_C

Brick:
	DC.W	%0000000000000000
	DC.W	%0111111111111110
	DC.W	%0100000000000010
	DC.W	%0100001110000010
	DC.W	%0100011111000010
	DC.W	%0100001110000010
	DC.W	%0100000000000010
	DC.W	%0111111111111110

Ball:
	incbin	"RESOURCES:graphics/ballblit/ball001001plan.raw"
BallMask:
	incbin	"RESOURCES:graphics/ballblit/ballmask_plan.raw"


COPPERLIST:

	DC.W	$8E,$2C81	; DiwStrt
	DC.W	$90,$2CC1	; DiwStop
	DC.W	$92,$38		; DdfStart
	DC.W	$94,$D0		; DdfStop
	DC.W	$102,0		; BplCon1
	DC.W	$104,0		; BplCon2
	DC.W	$108,0		; Bpl1Mod
	DC.W	$10A,0		; Bpl2Mod

BPLPOINTERS:
	DC.W	$E0,0,$E2,0	; BPL1PT
	DC.W	$E4,0,$E6,0	; BPL2PT
	
	DC.W	$100,$2200	; BPLCON0

	DC.W	$0180,$000	; COLOR0
	DC.W	$0182,$0F0	; COLOR1
	DC.W	$0184,$FFF	; COLOR2
	DC.W	$0186,$F00	; COLOR3

	DC.L	$FFFFFFFE	; stop copper instructions until next vblank

	SECTION SCREEN, BSS_C
	
BITPLANE:
	DS.B	40*256		; blank bitplane
BITPLANE2:
	DS.B	40*256		; blank bitplane
	
	END





	
       Truth table

A B C D BLTCONO position
0 0 0 ?        0
0 0 1 ?        1
0 1 0 ?        2
0 1 1 ?        3
1 0 0 ?        4
1 0 1 ?        5
1 1 0 ?        6
1 1 1 ?        7

			Table of Common Minterm Values


	  Selected      BLTCON0            Selected      BLTCON0 
	  Equation      LF Code            Equation      LF Code
	  --------      -------            --------      -------
	  D = A           $F0              D =  AB         $C0
	      _                                  _
	  D = A           $0F              D =  AB         $30
	  					_
	  D = B           $CC              D =  AB         $0C
	      _                                 __
	  D = B           $33              D =  AB         $03

	  D = C           $AA              D =  BC         $88
	      _                                  _
	  D = C           $55              D =  BC         $44
	  					_
	  D = AC          $A0              D =  BC         $22
	       _                                __
	  D = AC          $50              D =  AC         $11
	      _                                     _
	  D = AC          $0A              D =  A + B      $F3
	      _                                 _   _
	  D = AC          $05              D =  A + B      $3F
				         	    _
	  D = A + B       $FC              D =  A + C      $F5
	      _                                 _   _
	  D = A + B       $CF              D =  A + C      $5F
						    _
	  D = A + C       $FA              D =  B + C      $DD
	      _                                 _   _
	  D = A + C       $AF              D =  B + C      $77
						     _
	  D = B + C       $EE              D =  AB + AC    $CA
	      _
	  D = B + C       $BB	
	  
	  

                          Agnus/
                  Read/   Denise/
Register Address  Write   Paula         Function
-------- -------  -----   -------       --------
BLTCON0    040      W       A      Blitter control register 0
BLTCON1    042      W      A( E )  Blitter control register 1

 These two control registers are used together to
 control blitter operations.  There are two basic
 modes, area and line, which are selected by bit
 0 of BLTCON1, as shown below.

		AREA MODE ("normal")
	 -------------------------
	 BIT# BLTCON0     BLTCON1
	 ---- -------     -------
	 15   ASH3        BSH3
	 14   ASH2        BSH2
	 13   ASH1        BSH1
	 12   ASA0        BSH0
	 11   USEA         X
	 10   USEB         X
	 09   USEC         X
	 08   USED         X
	 07   LF7          DOFF
	 06   LF6          X
	 05   LF5          X
	 04   LF4         EFE
	 03   LF3         IFE
	 02   LF2         FCI
	 01   LF1         DESC
	 00   LF0         LINE(=0)

	 ASH3-0  Shift value of A source
	 BSH3-0  Shift value of B source
	 USEA    Mode control bit to use source A
	 USEB    Mode control bit to use source B
	 USEC    Mode control bit to use source C
	 USED    Mode control bit to use destination D
	 LF7-0   Logic function minterm select lines
	 EFE     Exclusive fill enable
	 IFE     Inclusive fill enable
	 FCI     Fill carry input
	 DESC    Descending (decreasing address) control bit
	 LINE    Line mode control bit (set to 0)	

