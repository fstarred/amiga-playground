*************************************************
*						*
*    Blitter copy memory area with cookie-cut	*
*            using interleaved mode		*
*						*
*************************************************

SPIN_SPEED = 5	; Higher = Slower spin. 1 = every frame.
MOVE_SPEED = 2	; Higher = Slower movement. 1 = every frame.
BALL_SIZE=128/8*128*2

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
INTENA=	%1100000000000000
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


LMCLICK		MACRO
	BTST	#6,$BFE001
	BNE.B	*-8
	BTST	#6,$BFE001
	BEQ.B	*-8
	ENDM

RMCLICK		MACRO
	BTST	#2,$DFF016
	BNE.B	*-8
	BTST	#2,$DFF016
	BEQ.B	*-8
	ENDM


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
	MOVE.W	D0,6(A1)		; BPLxPTL
	SWAP	D0
	MOVE.W	D0,2(A1)		; BPLxPTH
	SWAP	D0

	ADDI.L	#40,D0
	ADDQ.W	#8,A1
	DBRA	D7,.POINTBPL


	MOVEQ	#0,D0
	MOVE.W	D0,$88(A6)
	MOVE.W	D0,$1FC(A6)

	LEA	$DFF000,A1

	MOVEQ	#2,D7

.INIT_BG

	MOVE.L	DrawBuffer,A0
	MOVE.L	A0,A2
	ADDQ.L	#4,A2

.COPY_FROM_IMAGE

	WAITBLIT

	MOVE.W	#$09F0,$40(A1)		; BLTCON0 - USEA+USED LF=$F0 (D=A)
	CLR.W	$42(A1)			; BLTCON1
	MOVE.W	#$FFFF,$44(A1)		; BLTAFWM - full copy
	MOVE.W	#$FFFF,$46(A1)		; BLTALWM - full copy
	MOVE.L	#Brick,$50(A1)		; BLTAPT  channel A point to bitplane
	MOVE.L	A0,$54(A1)	; BLTDPT  channel D point to bitplane
	MOVE.W	#0,$64(A1)		; BLTAMOD - 0 bytes of modulo
	MOVE.W	#36+40,$66(A1)		; BLTDMOD - 40-4 bytes of modulo
	MOVE.W	#(8<<6)+2,$58(A1)	; BLTSIZE 8 height * 1 words width

.COMPLETE_HORIZONTAL_COPY

	WAITBLIT

	MOVE.L	A0,$50(A1)	; BLTAPT  channel A point to bitplane
	MOVE.L	A2,$54(A1)	; BLTDPT  channel D point to bitplane
	MOVE.W	#4+40,$64(A1)		; BLTAMOD - 40-36 bytes of modulo
	MOVE.W	#4+40,$66(A1)		; BLTDMOD - 40-36 bytes of modulo
	MOVE.W	#(8<<6)+18,$58(A1)	; BLTSIZE

.COMPLETE_VERTICAL_COPY

	ADDI.L	#(80*8-4),A2

	WAITBLIT

 	MOVE.L	A0,$50(A1)	; BLTAPT  channel A point to bitplane
	MOVE.L	A2,$54(A1)	; BLTDPT  channel D point to bitplane
	MOVE.W	#40,$64(A1)		; BLTAMOD - 0 bytes of modulo
	MOVE.W	#40,$66(A1)		; BLTDMOD - 0 bytes of modulo
	MOVE.W	#((8*31)<<6)+20,$58(A1)	; BLTSIZE 

	BSR	SWAP_BUFFER

	SUBQ.W	#1,D7
	BNE.W	.INIT_BG

	MOVE.W	#$C020,$9A(A6)		; enable interrupt

	LMCLICK

EXIT

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
	BEQ.W	EXIT_INTER

	MOVE.L	DrawBuffer,D0
	CMPI.L	#BITPLANE,D0
	BNE.B	.USE_BUFFER_2
.USE_BUFFER_1
	LEA	Context1,A5
	BRA.S	.CTX_READY
.USE_BUFFER_2
	LEA	Context2,A5
.CTX_READY
	MOVE.L	CtxObjCoord(A5),D0
	BEQ.W	.SKIP_RESTORE		; Skip if first run (addr is 0)
	MOVE.L	D0,A0			; Destination Address (Screen)
	LEA	CtxBGBuffer(A5),A2

.RESTOREBG

	WAITBLIT

	MOVE.W	#$09F0,$40(A1)		; BLTCON0 - USEA+USED LF=$F0 (D=A)
	CLR.W	$42(A1)			; BLTCON1
	MOVE.W	#$FFFF,$44(A1)		; BLTAFWM - full copy
	MOVE.W	#$FFFF,$46(A1)		; BLTALWM - full copy
	MOVE.L	A2,$50(A1)		; BLTAPT  channel A point to bitplane
	MOVE.L	A0,$54(A1)		; BLTDPT  channel D point to bitplane
	MOVE.W	#0,$64(A1)		; BLTAMOD - 0 bytes of modulo
	MOVE.W	#22,$66(A1)		; BLTDMOD - 40-18 bytes of modulo
	MOVE.W	#((128*2)<<6)+8+1,$58(A1)	; BLTSIZE

.SPIN
	SUB.B	#1,AnimCtr
	BNE.W	.CALCCOORD
	MOVE.B 	#SPIN_SPEED,AnimCtr	; reset counter

	MOVE.L	BallPtr(PC),D0		
	ADDI.L	#BALL_SIZE,D0
	CMPI.L	#BallEnd,D0
	BNE.B	.SETBALLPTR
	MOVE.L	#Ball,D0
.SETBALLPTR
	MOVE.L	D0,BallPtr
	
; TO REPLACE	
.CALCCOORD:
    SUBQ.B  #1,MoveCtr          ; Check movement timer
    BNE.S   .SKIP_TABLE_UPDATE  ; Skip update if counter > 0
    MOVE.B  #MOVE_SPEED,MoveCtr ; Reset movement timer

    LEA     COORDX,A0           ; X table address
    LEA     COORDY,A2           ; Y table address
    MOVE.W  CurCoord(PC),D0     ; Get current index
    
    ADD.W   D0,D0               ; Word offset (Index * 2)
    MOVE.W  (A0,D0.W),CoordX    ; Update X coordinate variable
    MOVE.W  (A2,D0.W),CoordY    ; Update Y coordinate variable
    
    MOVE.W  CurCoord(PC),D0     ; Increment index
    ADDQ.W  #1,D0               
    CMPI.W  #COORD_COUNT,D0     ; Check for end of table
    BNE.S   .SAVE_IDX
    MOVEQ   #0,D0               ; Reset to 0 for a seamless loop
.SAVE_IDX:
    MOVE.W  D0,CurCoord         ; Store index

.SKIP_TABLE_UPDATE:
.SKIP_RESTORE:
    MOVEQ   #0,D0
    MOVE.W  CoordX(PC),D0       ; Retrieve X for blitter
    LSR.W   #3,D0               ; Convert to byte offset
; END TO REPLACE

	MOVE.L	DrawBuffer,A0
	ADD.L	D0,A0

	MOVE.W	CoordY(PC),D0
	MULU	#80,D0			; each Y position is 80 bytes

	ADD.L	D0,A0			; add y value
	
	MOVE.L	A0,CtxObjCoord(A5)	; store obj position

	LEA	CtxBGBuffer(A5),A2

.COPY_BG_TO_BUFFER

	WAITBLIT

	MOVE.W	#$09F0,$40(A1)		; BLTCON0 - USEA+USED LF=$F0 (D=A)
	CLR.W	$42(A1)			; BLTCON1
	MOVE.W	#$FFFF,$44(A1)		; BLTAFWM - full copy
	MOVE.W	#$FFFF,$46(A1)		; BLTALWM - full copy
	MOVE.L	A0,$50(A1)		; BLTAPT  channel A point to bitplane
	MOVE.L	A2,$54(A1)		; BLTDPT  channel D point to bitplane
	MOVE.W	#22,$64(A1)		; BLTAMOD - 40-18 bytes of modulo
	MOVE.W	#0,$66(A1)		; BLTDMOD - 0 bytes of modulo
	MOVE.W	#((128*2)<<6)+8+1,$58(A1)	; BLTSIZE 

.DRAWBALL

	MOVE.W	CoordX(PC),D1		; pixel coordinate X
	ANDI.W	#$0F,D1
	SWAP	D1
	LSR.L	#4,D1			; shift 12 times trick
	
	MOVE.W	#$0FCA,D2		; MODE=ALL; LF=$CA (AB+nAC)
	OR.W	D1,D2			

	MOVE.L	CtxObjCoord(A5),A0

	WAITBLIT

	MOVE.W	D2,$40(A1)		; BLTCON0
	MOVE.W	D1,$42(A1)		; BLTCON1
	MOVE.W	#$FFFF,$44(A1)		; BLTAFWM - full copy
	MOVE.W	#$0000,$46(A1)		; BLTALWM - full copy
	MOVE.L	#BallMask,$50(A1)	; BLTAPT  channel A point to bitplane
	MOVE.L	BallPtr,  $4C(A1)	; BLTBPT  channel B point to ball
	MOVE.L	A0,$48(A1)		; BLTCPT  channel C point to background
	MOVE.L	A0,$54(A1)		; BLTDPT  channel D point to bitplane
	MOVE.W	#-2,$64(A1)		; BLTAMOD - -2 bytes of modulo
	MOVE.W	#-2,$62(A1)		; BLTBMOD - -2 bytes of modulo
	MOVE.W	#22,$60(A1)		; BLTCMOD - 40-18 bytes of modulo
	MOVE.W	#22,$66(A1)		; BLTDMOD - 40-18 bytes of modulo
	MOVE.W	#((128*2)<<6)+8+1,$58(A1)	; BLTSIZE 

	BSR	SWAP_BUFFER


EXIT_INTER
	MOVE.W	#$0020,$9C(A6)		; clear interrupt request
	MOVEM.L	(SP)+,D0-D7/A0-A6
	RTE




SWAP_BUFFER
	MOVEM.L	D0/D7/A0,-(SP)
	MOVE.L	DrawBuffer,D0
	MOVE.L	ViewBuffer,DrawBuffer
	MOVE.L	D0,ViewBuffer

	LEA	BPLPOINTERS,A0
	MOVEQ	#1,D7
.POINTBP
	MOVE.W	D0,6(A0)
	SWAP	D0
	MOVE.W	D0,2(A0)
	SWAP	D0
	ADDI.L	#40,D0
	ADDQ.W	#8,A0
	DBRA	D7,.POINTBP
	MOVEM.L	(SP)+,D0/D7/A0
	RTS


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
CoordX
	DC.W	0
CoordY
	DC.W	0
BallPtr:	
	DC.L	BallEnd-BALL_SIZE
AnimCtr:
	DC.B	SPIN_SPEED
	EVEN
	
; NEW CODE
MoveCtr:
    DC.B    1  ; The actual counter
    EVEN
CurCoord:
	DC.W	0               ; Table index
	EVEN

COORDX:
    ; Linear horizontal sweep: 0 -> 192 -> 0 (128 steps)
    ; Forward 0 to 192 (64 steps, approx 3 pixels each)
    DC.W  0,3,6,9,12,15,18,21,24,27,30,33,36,39,42,45,48,51,54,57,60,63,66,69,72,75,78,81,84,87,90,93
    DC.W  96,99,102,105,108,111,114,117,120,123,126,129,132,135,138,141,144,147,150,153,156,159,162,165,168,171,174,177,180,183,186,189
    ; Backward 192 to 3 (64 steps)
    DC.W  192,189,186,183,180,177,174,171,168,165,162,159,156,153,150,147,144,141,138,135,132,129,126,123,120,117,114,111,108,105,102,99
    DC.W  96,93,90,87,84,81,78,75,72,69,66,63,60,57,54,51,48,45,42,39,36,33,30,27,24,21,18,15,12,9,6,3
ECOORDX:

COORDY:
    ; Parabolic vertical bounce (Floor 128 <-> Peak 10)
    ; 4 mini-bounces per X-cycle to keep the movement energetic
    ; Bounce 1 (32 steps)
    DC.W  62,54,44,32,27,34,48,66,59,53,48,43,39,35,32,30,28,27,27,28,30,32,35,39,43,48,53,59,66,73,81,89,98,108,118
    ; Bounce 2 (32 steps)
    DC.W  128,118,108,98,89,81,73,66,59,53,48,43,39,35,32,30,28,27,27,28,30,32,35,39,43,48,53,59,66,73,81,89,98,108,118
    ; Bounce 3 (32 steps)
    DC.W  128,118,108,98,89,81,73,66,59,53,48,43,39,35,32,30,28,27,27,28,30,32,35,39,43,48,53,59,66,73,81,89,98,108,118
    ; Bounce 4 (29 steps to align with 128 total)
    DC.W  128,118,108,98,89,81,73,66,59,53,48,43,39,35,32,30,28,27,27,28,30,32,35,39,43,48,53,59,66
ECOORDY:

COORD_COUNT = (ECOORDX-COORDX)/2

ViewBuffer	DC.L	BITPLANE
DrawBuffer	DC.L	BITPLANE_ALT

	SECTION DATA,DATA_C

Brick:							; 32px * 8 bytes
	DC.W	%0000000000000000,%0000000000000000
	DC.W	%0111111111111110,%0000001110000000
	DC.W	%0100000000000010,%0000011011000000	
	DC.W	%0100001110000010,%0000110001100000
	DC.W	%0100011111000010,%0000110001100000
	DC.W	%0100001110000010,%0000011011000000
	DC.W	%0100000000000010,%0000001110000000
	DC.W	%0111111111111110,%0000000000000000
Ball:
	incbin	"RESOURCES:graphics/ballblit/ball001001.raw"
	incbin	"RESOURCES:graphics/ballblit/ball001002.raw"
	incbin	"RESOURCES:graphics/ballblit/ball001003.raw"
	incbin	"RESOURCES:graphics/ballblit/ball001004.raw"
	incbin	"RESOURCES:graphics/ballblit/ball001005.raw"
	incbin	"RESOURCES:graphics/ballblit/ball001006.raw"
	incbin	"RESOURCES:graphics/ballblit/ball001007.raw"
	incbin	"RESOURCES:graphics/ballblit/ball001008.raw"
	incbin	"RESOURCES:graphics/ballblit/ball001009.raw"
	incbin	"RESOURCES:graphics/ballblit/ball001010.raw"
	incbin	"RESOURCES:graphics/ballblit/ball001011.raw"
	incbin	"RESOURCES:graphics/ballblit/ball001012.raw"
	incbin	"RESOURCES:graphics/ballblit/ball001013.raw"
	incbin	"RESOURCES:graphics/ballblit/ball001014.raw"
	incbin	"RESOURCES:graphics/ballblit/ball001015.raw"
	incbin	"RESOURCES:graphics/ballblit/ball001016.raw"
BallEnd	
BallMask:
	incbin	"RESOURCES:graphics/ballblit/ballmask.raw"


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
	
	DC.W	$100,$2200	; BPLCON0

	DC.W	$0180,$000	; COLOR0	; Background (transparent)
	DC.W	$0182,$0F0	; COLOR1 	; Background (green)
	DC.W	$0184,$FFF	; COLOR2	; Ball (Color 0)
	DC.W	$0186,$F00	; COLOR3	; Ball (Color 1)

	DC.L	$FFFFFFFE	; stop copper instructions until next vblank

	SECTION	DYNAMIC, BSS_C	

	RSRESET
CtxObjCoord	RS.L	1		; store ball address position
CtxBGBuffer	RS.B	18*128*2	; store backgrund buffer
CtxSize		RS.B	0

Context1	DS.B	CtxSize		; store context parameters (frame1)
Context2	DS.B	CtxSize		; store context parameters (frame2)

BITPLANE	DS.B	40*256*2
BITPLANE_ALT	DS.B	40*256*2

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

