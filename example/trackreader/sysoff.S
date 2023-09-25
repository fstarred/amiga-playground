*******************************************
*
*
*	SYSTEM OFF CALLED FROM BOOTBLOCK
*
*
*******************************************

; For writing binary, from AsmOne
; WB <file> / START / END /

WriteFlag = 1

	IF WriteFlag=1
	AUTO	WS\START\2\1\
	ENDC


DMASET=		%1000000110000000
;		 -----a-bcdefghij

;		a: Blitter Nasty
;		b: Bitplane DMA (if this isn't set sprites disapear!)
;		c: Copper DMA
;		d: Blitter DMA
;		e: Sprite DMA
;		f: Disk DMA
;	      g-j: Audio 3-0 DMA

OpenLibrary=	-408
CloseLibrary=	-414
AllocRaster=	-492
FreeRaster=	-498

SCRWIDTH =320
SCRHEIGHT=256

	SECTION	FIRST,CODE_C

START:
	RSRESET

OldCopper	RS.L	1
ScreenPtr	RS.L	1
	
	MOVEM.L	D0-D7/A0-A6,-(A7)
	LEA.L	START(PC),A4
	MOVE.L	$4.W,A6
	LEA.L	GRAPNAME(PC),A1		; Gfx Name
	MOVEQ	#0,D0
	JSR	OPENLIBRARY(A6)
	MOVE.L	D0,A6			; Gfx Base
	MOVE.L	$26(A6),OldCopper(A4)	; Get old Copper Ptr.

;---  Allocate Raster  ---

	MOVE.W	#SCRWIDTH,D0			; Width
	MOVE.W	#SCRHEIGHT,D1			; Higth
	JSR	AllocRaster(A6)
	MOVE.L	D0,ScreenPtr(A4)

;--- Clear screen  ---

	MOVE.L	D0,A0
	MOVE.W	#SCRWIDTH/8*SCRHEIGHT/4-1,D1	; Clear 320/8 bytes wide
	MOVEQ	#0,D2			; times 260 bytes high
.LOOPC	
	MOVE.L	D2,(A0)+		; in longwords / 4
	DBF	D1,.LOOPC

;---  Set BPL ptrs  ---

	LEA.L	BITPLANES+2(PC),A0
	MOVEQ	#40,D1
	ADD.L	D0,D1
	SWAP	D0		; High word of pointer
	MOVE.W	D0,(A0)		; Store high 1
	ADDQ.W	#4,A0
	SWAP	D0		; Low word of pointer
	MOVE.W	D0,(A0)		; Store low 1
;	ADDQ.W	#4,A0
;	SWAP	D1		; High word of pointer
;	MOVE.W	D1,(A0)		; Store high 2
;	ADDQ.W	#4,A0
;	SWAP	D1		; Low word of pointer
;	MOVE.W	D1,(A0)		; Store low 2

	MOVE.L	A6,-(A7)	; Store Graphics library base

;---  Set DMA registers  ---

	MOVE.L	#$DFF000,A6
	MOVE.W	$1C(A6),-(A7)		; Store old inter data
	MOVE.W	$02(A6),-(A7)		; Store old DMA data
	MOVE.L	#$7FFF7FFF,$9A(A6)	; Disable interrupts
	MOVE.W	#$7FFF,$96(A6)		; Disable all DMA's

	LEA	COPLIST(PC),A0
	MOVE.L	A0,$80(A6)		; Copper1 start adress
	MOVE.W	#DMASET!$8200,$96(A6)	; Enable DMA's
	CLR.W	$88(A6)			; Start copper1

CONTINUE
.END	
	BTST	#6,$BFE001		; Wait mouse
	BNE.S	.END			; Pressed ???

	IF WriteFlag=1
	BRA CONTINUE			; Won't exit
	ENDC

;---  The End  ---

	MOVE.L	#$7FFF7FFF,$9A(A6)	; Disable interrupts
	OR.L	#$8000C000,(A7)		; Set enable bits
	MOVE.W	(A7)+,$96(A6)		; Enable interruptr
	MOVE.W	(A7)+,$9A(A6)		; Restore old inter data
	MOVE.L	OldCopper(A4),$80(A6)	; Restore old copper ptr
	CLR.W	$88(A6)			; Start Copper

;---  DeAllocate Raster  ---

	MOVE.L	(A7)+,A6
	MOVE.L	ScreenPtr(A4),A0
	MOVE.W	#SCRWIDTH,D0			; Width
	MOVE.W	#SCRHEIGHT,D1			; Higth
	JSR	FreeRaster(A6)

	MOVE.L	A6,A1			; Close graphics library
	MOVE.L	$4.W,A6
	JSR	CLOSELIBRARY(A6)

	MOVEM.L	(A7)+,D0-D7/A0-A6
	
	RTS


GRAPNAME:	DC.B	'graphics.library',0
	EVEN	
;*****************************
;*			     *
;*      COPPER1 PROGRAM      *
;*			     *
;*****************************

COPLIST:
	DC.L	$01800000
	DC.L	$01820FFF
BITPLANES:
	DC.L	$00E00000
	DC.L	$00E20000
	DC.L	$00E40000
	DC.L	$00E60000
	DC.L	$01001200
	DC.L	$01020000
	DC.L	$01040000
	DC.L	$01080000
	DC.L	$010A0000
	DC.L	$008E2C78
	DC.L	$00902CC8
	DC.L	$00920038
	DC.L	$009400D0
;INSTRUCTIONS
	DC.L	$9601FF00
	DC.L	$01800FFF
	DC.L	$B401FF00
	DC.L	$01800000
END
