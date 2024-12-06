***************************************
*
*
*	Heroes Of The Lance Trainer
*	    trainer part
*	Original IPF, Tosec 2012-04-10
*
***************************************

SECTORS=7
DEST_SECTOR=$61E00

WriteFlag

	IFD WriteFlag
	AUTO	WS\START\DEST_SECTOR/$200\SECTORS\
	ENDC

OldOpenLibrary	= -408
CloseLibrary 	= -414
OpenFont	=  -72
AllocRaster	= -492
FreeRaster	= -498

; A = AGNUS, D = DENISE, P = PAULA

;DMACON     096      W     A D P   DMA control write (clear or set)
;DMACONR    002      R     A   P   DMA control (and blitter status) read
DMASET=	%1000001111100000 ($8380)
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

SW_TYPE1_MAXVALUES = 2

SW1_VALUE = 0

FONT_HEIGHT=8
SCROLL_V_OFFSET=(42*FONT_HEIGHT*25)


BLTWAIT	MACRO
	tst $dff002			;for compatibility
\1
	btst #6,$dff002
	bne.s \1
	ENDM

START:
	BRA.B	SHOWTRAINER
PATCH:
	MOVEM.L	D0/A0,-(SP)
CRACK:
	MOVE.B	#$60,D0		; BRA
	MOVE.B	D0,$F96C
	MOVE.B	D0,$F99A
	MOVE.B	D0,$F860
	MOVE.B	D0,$F896
	
	LEA	BUTTONS(PC),A0
	MOVE.L	#$4E714E71,D0	; NOPx2
INFINITE_ENERGY:
	TST.B	(A0)+
	BEQ.B	LOAD_GAME
	MOVE.L	D0,$E706
	MOVE.L	D0,$FC6E
LOAD_GAME:
	MOVEM.L (SP)+,D0/A0
	MOVEA.L $0000C85C,A0
	RTS
BUTTONS:
	DC.B	SW1_VALUE
	EVEN
		
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

	LEA	$DFF000,A6

	MOVE.W	#$0,$108(A6)		; reset Bpl1Mod
	

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
	CMP.B	#$50,D0
	BGT.W	NOFONT		; IF > 50 EXIT
	SUB.B	#$50,D0		; F1 = 0, F2 = 1, F3 = 2..
	
	
;	NOTE: A WELL FORMED LABEL IS COMPOSED BY:
;		X,Y,'CHR',($00|$ff)
;		B,B,BBB,B
;	FOR A TOTAL OF 6 BYTES
ELABSWITCH:
	LEA	COORDS(PC),A0
	LEA	BUTTONS(PC),A1
	MOVE.W	D0,D1
ELAB_FIXVAL:
	MOVEQ	#0,D1
	MOVE.B	(A1,D0.W),D1
	LEA  	FIXEDVALUE-6(PC), A2
	CMP.B	#SW_TYPE1_MAXVALUES-1,D1
CHECK_VALUE:
	BNE.B	NORESETVAL
	MOVEQ	#-1,D1
NORESETVAL:
	ADDQ.L	#1,D1
	MOVE.B	D1,(A1,D0.W)		; STORE VALUE ON BUTTONS
	BSR.B	GETCOORD
GETLABEL:
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
	MULU	#[8*42],D1	; MULTIPLY COORD Y * CHARLEN * 42 LINES
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

	BSR.S	PLOTCHAR

	SUB.L	#SCR_WIDTH-1,A2	; POINT TO SCREEN POSITION + 1
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
	BSR.S	PLOTCHAR
NOFONT:
	RTS

PLOTCHAR:
	MOVEQ	#8-1,D0			; copy 8 bytes
.LOOP1	
	MOVE.B	(A4),(A2)		; Copy one byte from char
	ADD.W	D7,A4			; next byte in char
	ADD.W	#42,A2			; next raster line
	DBF	D0,.LOOP1		; Loop ^	
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



**************************************************************
*                                                            *
*   bar scrolling color                                      *
*                                                            *
**************************************************************

BAR_MOVE_VB_DELAY = 3

bar_move_counter:   dc.w    BAR_MOVE_VB_DELAY

move_tb_margin_bars:

    move.w  bar_move_counter, d0
    subq    #1, d0
    tst d0
    bne.s   exit_margin_bar 
    
    move    #BAR_MOVE_VB_DELAY, d0  ; reset counter
    lea TOP_MARGIN_BAR, a0
    bsr.s   rolling_color_hbar
    lea BOTTOM_MARGIN_BAR, a0
    bsr.s   rolling_color_hbar
    
exit_margin_bar:
    move.w  d0, bar_move_counter
    rts

************************************************************************
*	rolling color routine                                          *
*	<INPUT>                                                        *
*	A0 = HORIZONTAL BAR (STARTING FROM FIRST COLOR		       *
************************************************************************

rolling_color_hbar: 
    
    move.w  2+8(a0),2+0(a0) ; 07
    move.w  2+16(a0),2+8(a0)    ; 17
    move.w  2+24(a0),2+16(a0)   ; 27
    move.w  2+32(a0),2+24(a0)   ; 37
    move.w  2+40(a0),2+32(a0)   ; 47
    move.w  2+48(a0),2+40(a0)   ; 57
    move.w  2+56(a0),2+48(a0)   ; 67
    move.w  2+64(a0),2+56(a0)   ; 77
    move.w  2+72(a0),2+64(a0)   ; 87
    move.w  2+80(a0),2+72(a0)   ; 97
    move.w  2+88(a0),2+80(a0)   ; a7
    move.w  2+96(a0),2+88(a0)   ; b7
    move.w  2+104(a0),2+96(a0)  ; c7
    move.w  2+112(a0),2+104(a0) ; d7
    move.w  2+0(a0),2+112(a0)   ; e7

    rts

****************************************************************************
*                                                                          *
*   move stars routine  ripped from (RamJam course)                        *
*                                                                          *
****************************************************************************

STAR_MOVE_DELAY = 2
STAR_MOVE_PROGRESS  DC.W    0


STAR_S_COL = $0444
STAR_M_COL = $0999
STAR_F_COL = $0eee

move_stars:

    addq.b  #1,star_move_progress
    cmpi.b  #STAR_MOVE_DELAY,star_move_progress
    bne exit_move_stars 
    
    lea SPRITEPOINTERS(PC),a1   ; SPRITE pointer
    
    lea  STARFIELD_SPRITE(PC),a0
    move.l  a0,d0
    addi.w  #8*(5-1),a1         
    move.w  d0,6(a1)    
    swap    d0              
    move.w  d0,2(a1)       

    lea	    STARFIELD_SPRITE_END(PC),a1

; this routine process 3 stars each loop
; 1 - medium speed
; 2 - slow speed
; 3 - fast speed
move_loop:  

;  medium speed star - 2 pixel move

    cmpi.b  #$f0,1(a0)  ; check if star reached end screen
    bne.s   move_star_ms    ; if Z is not set move star
    move.b  #$30,1(A0)  ; if Z is set reset HSTART
move_star_ms:
    addq.b  #1,1(a0)    ; move sprite of 2 pixels
    addq.w  #8,a0       ; point to next sprite

; slow speed star - 1 pixel move

    cmpi.b  #$f0,1(a0)  ; check if star reached end screen
    bne.s   move_star_ls    ; if Z is not set move star
    move.b  #$30,1(a0)  ; if Z is set reset HSTART
move_star_ls:
    bchg    #0,3(a0)    ; check bit 0 SPR0CTL and change it
    beq.s   next_sprite ; if Z is set then go next sprite
    addq.b  #1,1(a0)    ; move slow sprite
next_sprite:
    addq.w  #8,a0       ; point to next sprite

; fast speed star - 4 pixel move

    cmpi.b  #$f0,1(a0)  ; check if star reached end screen
    bne.s   move_star_fs    ; if Z is not set move star
    move.b  #$30,1(a0)  ; if Z is set reset HSTART
move_star_fs:
    addq.b  #2,1(A0)    ; move fast sprite
    addq.w  #8,A0       ; point to next sprite

    cmp.l   a1,a0    ; check if SPRITE_END reached
    bcs.s   move_loop   ; if lower repeat loop
    clr.b   star_move_progress
exit_move_stars:
    rts         ; end routine
    
    
    


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
	BSR.W	SCROLL	
	
	BSR.W   MOVE_TB_MARGIN_BARS
	BSR.W	MOVE_STARS
		
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
	DC.B	6,1, 'HEROES OF THE LANCE TRAINER',0
	DC.B	10,7, 'BY FABRIZIO STELLATO',0
	DC.B	8,13,'F1 INFINITE ENERGY    OFF'
	DC.B	$FF
SCROLLINGTEXT:
	DC.B	'*** HEROES OF THE LANCE (ORIGINAL) TRAINER '  
	DC.B	' - TESTED ON A500 512KB/1MB '
	DC.B	' - WON''T WORK ON A1200 ',0
COORDS:		; switch trainer coordinate values
	DC.B	30,13
FIXEDVALUE:
	DC.B 0,0,'OFF',$ff
	DC.B 0,0,' ON',$ff
COUNTER:
	DC.B	8
	EVEN
TEXTPTR
	DC.W	0

; each sprite is composed by 4 words (8 bytes)
; example: $307A,$3100,$1000,$0000
; STR0POS   VSTART  $30
; STR0POS   HSTART  $7A
; SPR0CTL   VSTOP   $31
; SPR0CTL   bit 7-0 $00
;
; SPRITE DATA:
; $1000 $0000   where 1 is the pixel of the start
;
; be aware the sprite beyond $FF vertical position
; must have SPR0CTL bit 2 and 1 set ($06 or %0110) 

    
STARFIELD_SPRITE:
    
    dc.w    $54D0,$5500,$1000,$0000,$56D3,$5700,$1000,$0000
    dc.w    $58F0,$5900,$1000,$0000,$5A6A,$5B00,$1000,$0000
    dc.w    $5CA5,$5D00,$1000,$0000,$5E46,$5F00,$1000,$0000
    dc.w    $606A,$6100,$1000,$0000,$62A0,$6300,$1000,$0000
    dc.w    $64D7,$6500,$1000,$0000,$667C,$6700,$1000,$0000
    dc.w    $68C4,$6900,$1000,$0000,$6AC0,$6B00,$1000,$0000
    dc.w    $6C4A,$6D00,$1000,$0000,$6EDA,$6F00,$1000,$0000
    dc.w    $70D7,$7100,$1000,$0000,$7243,$7300,$1000,$0000
    dc.w    $74A2,$7500,$1000,$0000,$7699,$7700,$1000,$0000
    dc.w    $7872,$7900,$1000,$0000,$7A77,$7B00,$1000,$0000
    dc.w    $7CC2,$7D00,$1000,$0000,$7E56,$7F00,$1000,$0000
    dc.w    $805A,$8100,$1000,$0000,$82CC,$8300,$1000,$0000
    dc.w    $848F,$8500,$1000,$0000,$8688,$8700,$1000,$0000
    dc.w    $88B9,$8900,$1000,$0000,$8AAF,$8B00,$1000,$0000
    dc.w    $8C48,$8D00,$1000,$0000,$8E68,$8F00,$1000,$0000
    dc.w    $90DF,$9100,$1000,$0000,$924F,$9300,$1000,$0000
    dc.w    $9424,$9500,$1000,$0000,$96D7,$9700,$1000,$0000
    dc.w    $9859,$9900,$1000,$0000,$9A4F,$9B00,$1000,$0000
    dc.w    $9C4A,$9D00,$1000,$0000,$9E5C,$9F00,$1000,$0000
    dc.w    $A046,$A100,$1000,$0000,$A2A6,$A300,$1000,$0000
    dc.w    $A423,$A500,$1000,$0000,$A6FA,$A700,$1000,$0000
    dc.w    $A86C,$A900,$1000,$0000,$AA44,$AB00,$1000,$0000
    dc.w    $AC88,$AD00,$1000,$0000,$AE9A,$AF00,$1000,$0000
    dc.w    $B06C,$B100,$1000,$0000,$B2D4,$B300,$1000,$0000
    dc.w    $B42A,$B500,$1000,$0000,$B636,$B700,$1000,$0000
    dc.w    $B875,$B900,$1000,$0000,$BA89,$BB00,$1000,$0000
    dc.w    $BC45,$BD00,$1000,$0000,$BE24,$BF00,$1000,$0000
    dc.w    $C0A3,$C100,$1000,$0000,$C29D,$C300,$1000,$0000     
    dc.w    $C43F,$C500,$1000,$0000,$C634,$C700,$1000,$0000     
    dc.w    $C87C,$C900,$1000,$0000,$CA1D,$CB00,$1000,$0000     
    dc.w    $CC6B,$CD00,$1000,$0000,$CEAC,$CF00,$1000,$0000
    dc.w    $D0CF,$D100,$1000,$0000,$D2FF,$D300,$1000,$0000     
    dc.w    $D4A5,$D500,$1000,$0000,$D6D6,$D700,$1000,$0000     
    dc.w    $D8EF,$D900,$1000,$0000,$DAE1,$DB00,$1000,$0000     
    dc.w    $DCD9,$DD00,$1000,$0000,$DEA6,$DF00,$1000,$0000     
    dc.w    $E055,$E100,$1000,$0000,$E237,$E300,$1000,$0000     
    dc.w    $E47D,$E500,$1000,$0000,$E62E,$E700,$1000,$0000
    dc.w    $E8AF,$E900,$1000,$0000,$EA46,$EB00,$1000,$0000
    dc.w    $EC65,$ED00,$1000,$0000,$EE87,$EF00,$1000,$0000
    dc.w    $F0D4,$F100,$1000,$0000,$F2F5,$F300,$1000,$0000
    dc.w    $F4FA,$F500,$1000,$0000,$F62C,$F700,$1000,$0000
    dc.w    $F84D,$F900,$1000,$0000,$FAAC,$FB00,$1000,$0000
    dc.w    $FCB2,$FD00,$1000,$0000,$FE9A,$FF00,$1000,$0000
    dc.w    $009A,$0106,$1000,$0000,$02DF,$0306,$1000,$0000 ; sprite beyond vpos $FF
    dc.w    $0446,$0506,$1000,$0000,$0688,$0706,$1000,$0000

STARFIELD_SPRITE_END:
    dc.w    $0000,$0000 ; end of sprite address
	
COPPERLIST:
SPRITEPOINTERS:
	DC.W    $120,$0000,$122,$0000,$124,$0000,$126,$0000,$128,$0000  ; clear sprite pointers
	DC.W    $12a,$0000,$12c,$0000,$12e,$0000,$130,$0000,$132,$0000  ; clear sprite pointers
	DC.W    $134,$0000,$136,$0000,$138,$0000,$13a,$0000,$13c,$0000  ; clear sprite pointers
	DC.W    $13e,$0000

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

	DC.L	$01080002	; Bitplane modulo (odd planes)

	DC.W	$3407,$FFFE
	DC.W	$0182,$0DD0
	DC.W	$3507,$FFFE
	DC.W	$0182,$0CC0
	DC.W	$3607,$FFFE
	DC.W	$0182,$0BB0
	DC.W	$3707,$FFFE
	DC.W	$0182,$0AA0
	DC.W	$3807,$FFFE
	DC.W	$0182,$0BB0
	DC.W	$3907,$FFFE
	DC.W	$0182,$0CC0
	DC.W	$3a07,$FFFE
	DC.W	$0182,$0DD0
	DC.W	$3b07,$FFFE
	
	DC.W	$0182,$0FFF

	DC.W $4207,$fffe
TOP_MARGIN_BAR:
	DC.W $0180,$0032
	DC.W $4217,$fffe
	DC.W $0180,$0042
	DC.W $4227,$fffe
	DC.W $0180,$0052
	DC.W $4237,$fffe
	DC.W $0180,$0062
	DC.W $4247,$fffe
	DC.W $0180,$0082
	DC.W $4257,$fffe
	DC.W $0180,$0592
	DC.W $4267,$fffe
	DC.W $0180,$09a2
	DC.W $4277,$fffe
	DC.W $0180,$0ac2
	DC.W $4287,$fffe
	DC.W $0180,$09a2
	DC.W $4297,$fffe
	DC.W $0180,$0592
	DC.W $42a7,$fffe
	DC.W $0180,$0082
	DC.W $42b7,$fffe
	DC.W $0180,$0062
	DC.W $42c7,$fffe
	DC.W $0180,$0052
	DC.W $42d7,$fffe
	DC.W $0180,$0042
	DC.W $42e7,$fffe
	DC.W $0180,$0032
ETOP_MARGIN_BAR:
	DC.W $4307,$fffe
	DC.W $0180,$0000



TEXT_COLORS:
	DC.W $0182,$0FFF
	DC.W $0184,$0000
	DC.W $0186,$0000

;   GREEN
;   dc.w $0182,$08f6
;   dc.w $0184,$04b2
;   dc.w $0186,$0270

;   RED
;   dc.w $0182,$0f76
;   dc.w $0184,$0b32
;   dc.w $0186,$0700



	; set star color according to its speed
	; slow are dark
	; medium are mid-bright 
	; fast are bright
    
	DC.W $5407,$fffe
	DC.W $01b2,STAR_M_COL   ; medium (col17 sprite a)
	DC.W $5507,$fffe
	DC.W $01b2,STAR_S_COL   ; slow
	DC.W $5707,$fffe
	DC.W $01b2,STAR_F_COL   ; fast
	DC.W $5907,$fffe
	DC.W $01b2,STAR_M_COL   ; medium (col17 sprite a)
	DC.W $5b07,$fffe
	DC.W $01b2,STAR_S_COL   ; slow
	DC.W $5d07,$fffe
	DC.W $01b2,STAR_F_COL   ; fast
	DC.W $5f07,$fffe
	DC.W $01b2,STAR_M_COL   ; medium (col17 sprite a)
	DC.W $6107,$fffe
	DC.W $01b2,STAR_S_COL   ; slow
	DC.W $6307,$fffe
	DC.W $01b2,STAR_F_COL   ; fast
	DC.W $6507,$fffe
	DC.W $01b2,STAR_M_COL   ; medium (col17 sprite a)
	DC.W $6707,$fffe
	DC.W $01b2,STAR_S_COL   ; slow
	DC.W $6907,$fffe
	DC.W $01b2,STAR_F_COL   ; fast
	DC.W $6b07,$fffe
	DC.W $01b2,STAR_M_COL   ; medium (col17 sprite a)
	DC.W $6d07,$fffe
	DC.W $01b2,STAR_S_COL   ; slow
	DC.W $6f07,$fffe
	DC.W $01b2,STAR_F_COL   ; fast
	DC.W $7107,$fffe
	DC.W $01b2,STAR_M_COL   ; medium (col17 sprite a)
	DC.W $7307,$fffe
	DC.W $01b2,STAR_S_COL   ; slow
	DC.W $7507,$fffe
	DC.W $01b2,STAR_F_COL   ; fast
	DC.W $7707,$fffe
	DC.W $01b2,STAR_M_COL   ; medium (col17 sprite a)
	DC.W $7907,$fffe
	DC.W $01b2,STAR_S_COL   ; slow
	DC.W $7b07,$fffe
	DC.W $01b2,STAR_F_COL   ; fast
	DC.W $7d07,$fffe
	DC.W $01b2,STAR_M_COL   ; medium (col17 sprite a)
	DC.W $7f07,$fffe
	DC.W $01b2,STAR_S_COL   ; slow
	DC.W $8107,$fffe
	DC.W $01b2,STAR_F_COL   ; fast
	DC.W $8307,$fffe
	DC.W $01b2,STAR_M_COL   ; medium (col17 sprite a)
	DC.W $8507,$fffe
	DC.W $01b2,STAR_S_COL   ; slow
	DC.W $8707,$fffe
	DC.W $01b2,STAR_F_COL   ; fast
	DC.W $8907,$fffe
	DC.W $01b2,STAR_M_COL   ; medium (col17 sprite a)
	DC.W $8b07,$fffe
	DC.W $01b2,STAR_S_COL   ; slow
	DC.W $8d07,$fffe
	DC.W $01b2,STAR_F_COL   ; fast
	DC.W $8f07,$fffe
	DC.W $01b2,STAR_M_COL   ; medium (col17 sprite a)
	DC.W $9107,$fffe
	DC.W $01b2,STAR_S_COL   ; slow
	DC.W $9307,$fffe
	DC.W $01b2,STAR_F_COL   ; fast
	DC.W $9507,$fffe
	DC.W $01b2,STAR_M_COL   ; medium (col17 sprite a)
	DC.W $9707,$fffe
	DC.W $01b2,STAR_S_COL   ; slow
	DC.W $9907,$fffe
	DC.W $01b2,STAR_F_COL   ; fast
	DC.W $9b07,$fffe
	DC.W $01b2,STAR_M_COL   ; medium (col17 sprite a)
	DC.W $9d07,$fffe
	DC.W $01b2,STAR_S_COL   ; slow
	DC.W $9f07,$fffe
	DC.W $01b2,STAR_F_COL   ; fast
	DC.W $a107,$fffe
	DC.W $01b2,STAR_M_COL   ; medium (col17 sprite a)
	DC.W $a307,$fffe
	DC.W $01b2,STAR_S_COL   ; slow
	DC.W $a507,$fffe
	DC.W $01b2,STAR_F_COL   ; fast
	DC.W $a707,$fffe
	DC.W $01b2,STAR_M_COL   ; medium (col17 sprite a)
	DC.W $a907,$fffe
	DC.W $01b2,STAR_S_COL   ; slow
	DC.W $ab07,$fffe
	DC.W $01b2,STAR_F_COL   ; fast
	DC.W $ad07,$fffe
	DC.W $01b2,STAR_M_COL   ; medium (col17 sprite a)
	DC.W $af07,$fffe
	DC.W $01b2,STAR_S_COL   ; slow
	DC.W $b107,$fffe
	DC.W $01b2,STAR_F_COL   ; fast
	DC.W $b307,$fffe
	DC.W $01b2,STAR_M_COL   ; medium (col17 sprite a)
	DC.W $b507,$fffe
	DC.W $01b2,STAR_S_COL   ; slow
	DC.W $b707,$fffe
	DC.W $01b2,STAR_F_COL   ; fast
	DC.W $b907,$fffe
	DC.W $01b2,STAR_M_COL   ; medium (col17 sprite a)
	DC.W $bb07,$fffe
	DC.W $01b2,STAR_S_COL   ; slow
	DC.W $bd07,$fffe
	DC.W $01b2,STAR_F_COL   ; fast
	DC.W $bf07,$fffe
	DC.W $01b2,STAR_M_COL   ; medium (col17 sprite a)
	DC.W $c107,$fffe
	DC.W $01b2,STAR_S_COL   ; slow
	DC.W $c307,$fffe
	DC.W $01b2,STAR_F_COL   ; fast
	DC.W $c607,$fffe
	DC.W $01b2,STAR_M_COL   ; medium (col17 sprite a)
	DC.W $c807,$fffe
	DC.W $01b2,STAR_S_COL   ; slow
	DC.W $ca07,$fffe
	DC.W $01b2,STAR_F_COL   ; fast
	DC.W $cb07,$fffe
	DC.W $01b2,STAR_M_COL   ; medium (col17 sprite a)
	DC.W $cd07,$fffe
	DC.W $01b2,STAR_S_COL   ; slow
	DC.W $ab07,$fffe
	DC.W $01b2,STAR_F_COL   ; fast
	DC.W $d107,$fffe
	DC.W $01b2,STAR_M_COL   ; medium (col17 sprite a)
	DC.W $d307,$fffe
	DC.W $01b2,STAR_S_COL   ; slow
	DC.W $d507,$fffe
	DC.W $01b2,STAR_F_COL   ; fast
	DC.W $d707,$fffe
	DC.W $01b2,STAR_M_COL   ; medium (col17 sprite a)
	DC.W $d907,$fffe
	DC.W $01b2,STAR_S_COL   ; slow
	DC.W $db07,$fffe
	DC.W $01b2,STAR_F_COL   ; fast
	DC.W $dd07,$fffe
	DC.W $01b2,STAR_M_COL   ; medium (col17 sprite a)
	DC.W $df07,$fffe
	DC.W $01b2,STAR_S_COL   ; slow
	DC.W $e107,$fffe
	DC.W $01b2,STAR_F_COL   ; fast
	DC.W $e307,$fffe
	DC.W $01b2,STAR_M_COL   ; medium (col17 sprite a)
	DC.W $e507,$fffe
	DC.W $01b2,STAR_S_COL   ; slow
	DC.W $e707,$fffe
	DC.W $01b2,STAR_F_COL   ; fast
	DC.W $e907,$fffe
	DC.W $01b2,STAR_M_COL   ; medium (col17 sprite a)
	DC.W $eb07,$fffe
	DC.W $01b2,STAR_S_COL   ; slow
	DC.W $ed07,$fffe
	DC.W $01b2,STAR_F_COL   ; fast
	DC.W $ef07,$fffe
	DC.W $01b2,STAR_M_COL   ; medium (col17 sprite a)
	DC.W $f107,$fffe
	DC.W $01b2,STAR_S_COL   ; slow
	DC.W $f307,$fffe
	DC.W $01b2,STAR_F_COL   ; fast
	DC.W $f507,$fffe
	DC.W $01b2,STAR_M_COL   ; medium (col17 sprite a)
	DC.W $f707,$fffe
	DC.W $01b2,STAR_S_COL   ; slow
	DC.W $f907,$fffe
	DC.W $01b2,STAR_F_COL   ; fast
	DC.W $fb07,$fffe
	DC.W $01b2,STAR_M_COL   ; medium (col17 sprite a)
	DC.W $fd07,$fffe
	DC.W $01b2,STAR_S_COL   ; slow
	DC.W $ff07,$fffe

	DC.W $ffdf,$fffe

	DC.W $01b2,STAR_F_COL   ; fast
	DC.W $0107,$fffe
	DC.W $01b2,STAR_M_COL   ; medium (col17 sprite a)
	DC.W $0307,$fffe
	DC.W $01b2,STAR_S_COL   ; slow
	DC.W $0507,$fffe
	DC.W $01b2,STAR_F_COL   ; fast
	; end star color copper set

	DC.W $1207,$fffe
BOTTOM_MARGIN_BAR:
	DC.W $0180,$0302
	DC.W $1217,$fffe
	DC.W $0180,$0402
	DC.W $1227,$fffe
	DC.W $0180,$0502
	DC.W $1237,$fffe
	DC.W $0180,$0602
	DC.W $1247,$fffe
	DC.W $0180,$0802
	DC.W $1257,$fffe
	DC.W $0180,$0952
	DC.W $1267,$fffe
	DC.W $0180,$0a92
	DC.W $1277,$fffe
	DC.W $0180,$0ca2
	DC.W $1287,$fffe
	DC.W $0180,$0a92
	DC.W $1297,$fffe
	DC.W $0180,$0952
	DC.W $12a7,$fffe
	DC.W $0180,$0802
	DC.W $12b7,$fffe
	DC.W $0180,$0602
	DC.W $12c7,$fffe
	DC.W $0180,$0502
	DC.W $12d7,$fffe
	DC.W $0180,$0402
	DC.W $12e7,$fffe
	DC.W $0180,$0302
EBOTTOM_MARGIN_BAR:
	DC.W $1307,$fffe
	DC.W $0180,$0000
	

	DC.L	$FFFFFFFE
END

BIN_LEN=512*SECTORS
PROG_SIZE=END-START

	IF PROG_SIZE>BIN_LEN
	FAIL
	ENDC


	DS.B	BIN_LEN-PROG_SIZE	; fill remain space with $0 values


	PRINTT	"PROG REAL SIZE..."
	PRINTV	PROG_SIZE
	PRINTT	"DEST SECTOR.."
	PRINTV	DEST_SECTOR
