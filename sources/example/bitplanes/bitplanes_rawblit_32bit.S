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
DMASET=	%1000001110000000
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
	MOVEQ	#4,D7
	MOVE.L	#BITPLANE,D0		; point to bitplane data
	LEA	BPLPOINTERS,A1		; point to BPL1PT register

.POINTBPL
	MOVE.W	D0,6(A1)		; BPLxPTL
	SWAP	D0
	MOVE.W	D0,2(A1)		; BPLxPTH
	SWAP	D0

	ADDI.L	#40,D0
	ADDQ.L	#8,A1
	DBRA	D7,.POINTBPL

	MOVEQ	#0,D0
	MOVE.W	D0,$88(A6)
	MOVE.W	D0,$1FC(A6)

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

	BTST.B	#5,$01F(A6)
	BEQ.B	EXIT

	NOP

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


	SECTION COPPER,DATA_C

COPPERLIST:

	DC.W	$8E,$2C81	; DiwStrt
	DC.W	$90,$2CC1	; DiwStop
	DC.W	$92,$38		; DdfStart
	DC.W	$94,$D0		; DdfStop
	DC.W	$102,0		; BplCon1
	DC.W	$104,0		; BplCon2
	DC.W	$108,40		; Bpl1Mod
	DC.W	$10A,40		; Bpl2Mod

BPLPOINTERS:
	DC.W	$E0,0,$E2,0	; BPL1PT
	DC.W	$E4,0,$E6,0	; BPL2PT
	DC.W	$E8,0,$EA,0	; BPL3PT
	DC.W	$EC,0,$EE,0	; BPL4PT
	DC.W	$F0,0,$F2,0	; BPL5PT
	
	DC.W	$100,$5200	; BPLCON0

	DC.W	$180,$000	; COLOR0
	DC.W	$182,$FFF	; COLOR1
	DC.W	$184,$00F	; COLOR2
	DC.W	$186,$0F0	; COLOR3
	DC.W	$188,$F00	; COLOR4
	DC.W	$18A,$008	; COLOR5
	DC.W	$18C,$080	; COLOR6
	DC.W	$18E,$800	; COLOR7

	DC.L	$FFFFFFFE	; stop copper instructions until next vblank
	
	SECTION	BITPLANES,BSS_C
	
BITPLANE:
	DS.B	40*256*5		; blank bitplanes
	
	END


		Low-resolution Color Selectlon

             Singe Playfield             Dual Playfields
     Normal Mode        Hold-and-modify Mode            Color Register
 (Bit-planes 5,4,3,2,1)  (Bit-planes 4,3,2,1)               Number

                                           Playfield 1
                                         Bit-planes 5,3,1

        00000                   0000                000            0 *
        00001                   0001                001            1
        00010                   0010                010            2
        00011                   0011                011            3
        00100                   0100                100            4
        00101                   0101                101            5
        00110                   0100                110            6
        00111                   0111                111            7

                                           Playfield 2
                                         Bit-planes 6,4,2

        01000                   1000                000 **         8
        01001                   1001                001            9
        01010                   1010                010           10
        01011                   1011                011           11
        01100                   1100                100           12
        01101                   1101                101           13
        01110                   1110                110           14
        01111                   1111                111           15
        10000                    |                   |            16
        10001                    |                   |            17
        10010                    |                   |            18
        10011                    |                   |            19
        10100                   NOT                 NOT           20
        10101                   USED                USED          21
        10110                    IN                  IN           22
        10111                   THIS                THIS          23
        11000                   MODE                MODE          24
        11001                    |                   |            25
        11010                    |                   |            26
        11011                    |                   |            27
        11100                    |                   |            28
        11101                    |                   |            29
        11110                    |                   |            30
        11111                    |                   |            31

* Color register 0 always defines the background color.

** Selects "transparent" mode instead of selecting color register 8.

