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


SPRITE_VPOS=$2C
SPRITE_HPOS=$40
SPRITE_FRAME_OFFSET=$80

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

	MOVE.L	#SPR0,D0
	LEA	SPRITEPOINTERS,A1
	MOVE.W	D0,6(A1)
	SWAP	D0
	MOVE.W	D0,2(A1)
	SWAP	D0

	ADD.L	#SPRITE_FRAME_OFFSET+4,D0
	ADDQ.L	#8,A1
	MOVE.W	D0,6(A1)
	SWAP	D0
	MOVE.W	D0,2(A1)

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
	CLR.W	$88(A6)			; activate original COPPERLIST

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

	MOVE.W	#$4020,$9C(A6)		; clear interrupt request
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

	dc.l $01A20FFF
	dc.l $01A40F00,$01A60F0F
	


	DC.L	$FFFFFFFE	; stop copper instructions until next vblank

SPR0
VSTART
	DC.B	SPRITE_VPOS
HSTART
	DC.B	SPRITE_HPOS
VSTOP	
	DC.B	SPRITE_VPOS+$20
SPRCTL
	DC.B	$00

	dc.w $0000,$0000
	dc.w $0000,$0000
	dc.w $0007,$0018
	dc.w $000F,$0071
	dc.w $00EE,$0111
	dc.w $01C3,$023C
	dc.w $03C3,$047C
	dc.w $0707,$08F8
	dc.w $0887,$0778
	dc.w $11F3,$0E0C
	dc.w $11F8,$0E0F
	dc.w $23F0,$1C1F
	dc.w $03F0,$3C1F
	dc.w $1DE0,$221F
	dc.w $1C20,$23FF
	dc.w $1C3C,$27C3
	dc.w $1C3F,$27C0
	dc.w $183F,$27C0
	dc.w $243F,$1FC1
	dc.w $267F,$1981
	dc.w $279E,$1861
	dc.w $07C2,$187F
	dc.w $1783,$187C
	dc.w $0FC3,$007C
	dc.w $04C3,$0B7C
	dc.w $0467,$0398
	dc.w $0279,$0186
	dc.w $0038,$01C7
	dc.w $0058,$0027
	dc.w $000E,$0011
	dc.w $0000,$0000
	dc.w $0000,$0000
	

SPR1
VSTART1
	DC.B	SPRITE_VPOS
HSTART1
	DC.B	SPRITE_HPOS+8
VSTOP1
	DC.B	SPRITE_VPOS+$20
SPRCTL1
	DC.B	$00	

	dc.w $0000,$0000
	dc.w $0000,$0000
	dc.w $7000,$8800
	dc.w $1A00,$E400
	dc.w $1E00,$E380
	dc.w $9E40,$6180
	dc.w $E620,$19C0
	dc.w $E120,$3ED0
	dc.w $E1F0,$3E00
	dc.w $C1E8,$3E18
	dc.w $41E0,$FE18
	dc.w $79E4,$8618
	dc.w $7E64,$8198
	dc.w $7E04,$83F8
	dc.w $FC18,$03E4
	dc.w $FE1C,$03E4
	dc.w $3C1C,$C3E4
	dc.w $843C,$FFC4
	dc.w $07B8,$F844
	dc.w $07C0,$F83C
	dc.w $07C4,$F838
	dc.w $0FC8,$F070
	dc.w $CF88,$3070
	dc.w $E190,$1EE0
	dc.w $F0E0,$1F10
	dc.w $E1C0,$1E20
	dc.w $C380,$3C40
	dc.w $7700,$8880
	dc.w $7800,$8E00
	dc.w $E000,$1800
	dc.w $0000,$0000
	dc.w $0000,$0000

		
	SECTION	BITPLANES,BSS_C
	
BITPLANE:
	DS.B	40*256		; blank bitplane
	
END

