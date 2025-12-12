*************************************************
*						*
*						*
*	Blitter copy memory area		*
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
	MOVE.L	#BITPLANE,D0		; point to bitplane data
	LEA	BPLPOINTERS,A1		; point to BPL1PT register
	MOVE.W	D0,6(A1)		; BPL1PTL
	SWAP	D0
	MOVE.W	D0,2(A1)		; BPL1PTH

	MOVEQ	#0,D0
	MOVE.W	D0,$88(A6)
	MOVE.W	D0,$1FC(A6)
MAIN
.DRAWSQUARE			;32*32
	MOVEQ	#-1,D0
	LEA	BITPLANE,A0

	MOVEQ	#8-1,D1
.LOOP
	MOVE.L	D0,(A0)
	MOVE.L	D0,40(A0)
	MOVE.L	D0,80(A0)
	MOVE.L	D0,120(A0)
	ADDI.L	#160,A0
	DBF	D1,.LOOP

.LMPRESS
	BTST	#6,$BFE001
	BNE.S	.LMPRESS
.LMRELEASE
	BTST	#6,$BFE001
	BEQ.S	.LMRELEASE


	LEA	$DFF000,A1
.WAITBLIT1.
	BTST.B	#6,$02(A1)
.WAITBLIT2:
	BTST.B	#6,$02(A1)
	BNE.B	.WAITBLIT2
COPYREGION
	MOVE.W	#$09F0,$40(A1)		; BLTCON0 - USEA+USED LF=$F0 (D=A)
	MOVE.W	#$0002,$42(A1)		; BLTCON1 - DESC
	MOVE.W	#$FFFF,$44(A1)		; BLTAFWM - full copy
	MOVE.W	#$FFFF,$46(A1)		; BLTALWM - full copy
	MOVE.L	#BITPLANE+(31*40)+2,$50(A1)	; BLTAPT  channel A 
					; in DESC mode, point to the last word
	MOVE.L	#BITPLANE+(31*40)+10,$54(A1)	; BLTDPT  channel D
					; in DESC mode, point to the last word
	MOVE.W	#36,$64(A1)		; BLTAMOD - 40-4 bytes of modulo
	MOVE.W	#36,$66(A1)		; BLTDMOD - 40-4 bytes of modulo
	MOVE.W	#(32<<6)+2,$58(A1)	; BLTSIZE 32 height * 2 words width

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
	
	DC.W	$100,$1200	; BPLCON0

	DC.W	$0180,$000	; COLOR0
	DC.W	$0182,$FFF	; COLOR1
	DC.L	$FFFFFFFE	; stop copper instructions until next vblank
	
BITPLANE:
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

