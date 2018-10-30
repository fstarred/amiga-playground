
	SECTION Code,CODE

*****************************************************************************
	incdir	"dh1:own/demo/repository/startup/borchen/"
	include	"startup.s"
	incdir	"dh1:own/demo/repository/shared/"	
	include "hardware/custom.i"
	incdir  "dh1:own/demo/repository/replay/"
	include	"PT3.0b_replay_cia.s"
*****************************************************************************



DMASET  = %1000001111000000
;     	  %-----axbcdefghij
;   a: Blitter Nasty
;   x: Enable DMA
;   b: Bitplane DMA (if this isn't set, sprites disappear!)
;   c: Copper DMA
;   d: Blitter DMA
;   e: Sprite DMA
;   f: Disk DMA
;   g-j: Audio 3-0 DMA

INTENASET=     %1010000000000000
;              -FEDCBA9876543210

;   F   SET/CLR 0=clear, 1=set bits that are set to 1 below
;   E   INTEN   Enable interrupts below (master toggle)
;   D   EXTER   Level 6 External interrupt
;   C   DSKSYN  Level 5 Disk Sync value found
;   B   RBF Level 5 Receive Buffer Full (serial port)
;   A   AUD3    Level 4 Audio Interrupt channel 3
;   9   AUD2    Level 4 Audio Interrupt channel 2
;   8   AUD1    Level 4 Audio Interrupt channel 1
;   7   AUD0    Level 4 Audio Interrupt channel 0
;   6   BLIT    Level 3 Blitter Interrupt
;   5   VERTB   Level 3 Vertical Blank Interrupt
;   4   COPER   Level 3 Copper Interrupt
;   3   PORTS   Level 2 CIA Interrupt (I/O ports and timers)
;   2   SOFT    Level 1 Software Interrupt
;   1   DSKBLK  Level 1 Disk Block Finished Interuppt
;   0   TBE Level 1 Transmit Buffer Empty Interrupt (serial port)


w	=320
h	=256
bplsize	=w*h/8
ScrBpl	=w/8

bpls = 1

;wbl = $2c 	;(for copper monitor only)
wbl = 303
	
	
WAITVB MACRO
   	move.l  $dff004,d0      ; wait
 	and.l   #$0001ff00,d0       ; for
   	cmp.l   #wbl<<8,d0      ; rasterline 303
	bne.s   \1
	ENDM

WAITVB2 MACRO
	move.l  $dff004,d0      ; wait
 	and.l   #$0001ff00,d0   ; for
	cmp.l   #wbl<<8,d0      ; rasterline 303
	beq.s   \1
	ENDM

BLTWAIT	MACRO
	tst $dff002			;for compatibility
\1
	btst #6,$dff002
	bne.s \1
	ENDM

LMOUSE	MACRO
	btst	#6,$bfe001	; check L MOUSE btn
	bne.s	\1
	ENDM

RMOUSE	MACRO
\1
	btst	#2,$dff016	; check L MOUSE btn
	beq.s	\1
	ENDM



	
START:

	move.l  #SCREEN,d0  ; point to bitplane
    	lea BPLPOINTERS,a1  ; 
   	MOVEQ   #bpls-1,d1  ; 2 BITPLANE
POINTBP:
    	move.w  d0,6(a1)    ; copy low word of pic address to plane
    	swap    d0          ; swap the the two words
   	move.w  d0,2(a1)    ; copy the high word of pic address to plane
    	swap    d0          ; swap the the two words

	add.l   #ScrBpl*h,d0      ; BITPLANE point to next byte line data
                        ; instead of the standard raw
                        ; where bitplane is immediately
                        ; after the previous bitplane
                        ; standard raw (40*256)
                        ; blitter raw (40)
			; notice the +2 bytes where to place char data
			
	addq.w  #8,a1   ; the next bpl starts one row
                	; after the previous one	
	dbra    d1,POINTBP
    
	move.w  #DMASET,$dff096     ; enable necessary bits in DMACON
	move.w  #INTENASET,$dff09a     ; INTENA
    
	move.l  #COPPERLIST,$dff080 ; COP1LCH set custom copperlist
   	move.w  #0,$dff088      ; COPJMP1 activate copperlist
	
	bsr.w   pt_init
	
	lea	$dff000,a5

	bsr.s	init_bar
	
Main:
	WAITVB	Main
;	***** COPPER MONITOR
;	move.w  #$F00, $dff180
	
	bsr.w   pt_play
	bsr.w	start_equalizer
	
;  	**** COPPER MONITOR
;	move.w  #0, $dff180
	

Wait	WAITVB2	Wait
	
	RMOUSE WaitRM
	
	LMOUSE	Main
	
	BSR pt_end

	rts
	
BAR_HEIGHT = 64
DECREASE_SPEED = 1
H_DESC_OFFSET = 20
V_OFFSET = 80*ScrBpl

SCREEN_OFFSET =V_OFFSET+(BAR_HEIGHT*ScrBpl)+H_DESC_OFFSET

init_bar:

	lea	SCREEN+SCREEN_OFFSET, a0

	BLTWAIT	bltw1
		
	move.w	#$ffff,BLTAFWM(a5)		; BLTAFWM 
	move.w	#$ffff,BLTALWM(a5)		; BLTALWM 
	move.w	#$09f0,BLTCON0(a5)		; BLTCON0 ; A-D
	move.w	#$0002,BLTCON1(a5)		; BLTCON1 ; DESC
	move.w	#0,BLTAMOD(a5)		; BLTAMOD 
	move.w	#40-(4*2),BLTDMOD(a5)	; BLTDMOD 
	move.l	#BAR+14,BLTAPT(a5)	; BLTAPT  ; point to BAR source
	move.l	a0,BLTDPT(a5)		; BLTDPT  ; point to SCREEN destination
	move.w	#64*2+4,BLTSIZE(a5)	; BLTSIZE: rectangle size
		
	rts
	
start_equalizer:
	
	moveq	#4-1, d7	; init loop	
	moveq	#0, d2		; channel_address index (0-3)
	moveq	#0, d3		; reset channel volume

	lea	chan_level(PC), a1		
check_channel_level:	
	lea	channel_address(PC), a0	
	move.l	(a0,d2.w), a0	; channel temp address to a0
	move.l	(a0), d0	; channel temp touch to d0
	move.b	19(a0), d3	; channel temp value to d3
		
	move.w	(a1), d1        ; channel level value to d1
	
	tst.w	d0		; test if mt_channel is touched
	beq.s	no_sound	
	move.w	d3, d1		; update channel level value
	;move.w	#BAR_HEIGHT-DECREASE_SPEED, d1
no_sound:	
	tst.w	d1		; test channel level
	beq.s	min_value	; no channel level subtract
	subq.w	#DECREASE_SPEED, d1		; subtract channel level
	move.w	d1, (a1)	; write new value to channel level

min_value:	
	addq	#4, d2	; add to incremental pointer
	addq	#2, a1	; point to next	chan_level
	
	dbra	d7, check_channel_level
	
	moveq	#4-1, d7	; init loop

	
clear_equalizer:

	lea	SCREEN+SCREEN_OFFSET-(ScrBpl*1), a0

	BLTWAIT	bltw2
		
	move.w	#$ffff,BLTAFWM(a5)		; BLTAFWM 
	move.w	#$ffff,BLTALWM(a5)		; BLTALWM 
	move.w	#$0100,BLTCON0(a5)		; BLTCON0 ; A-D
	move.w	#$0002,BLTCON1(a5)		; BLTCON1 ; DESC
	move.w	#0,BLTAMOD(a5)		; BLTAMOD 
	move.w	#40-(4*2),BLTDMOD(a5)	; BLTDMOD 
	move.l	#0,BLTAPT(a5)	; BLTAPT  ; point to BAR source
	move.l	a0,BLTDPT(a5)		; BLTDPT  ; point to SCREEN destination
	move.w	#BAR_HEIGHT*64+4,BLTSIZE(a5)	; BLTSIZE: rectangle size	
	
	lea	chan_level, a0	
	lea	SCREEN+SCREEN_OFFSET-6, a1
	
draw_equalizer:
	
	move.w	(a0)+,d0

	addi.w	#DECREASE_SPEED, d0	; won't blit 0 lines
	
	lsl.w	#6,d0
	addq	#1,d0	

	move.l	a1, a2
	subi.l	#ScrBpl*2, a2
	
	BLTWAIT	bltw3
		
	move.w	#$ffff,BLTAFWM(a5)	; BLTAFWM 
	move.w	#$ffff,BLTALWM(a5)	; BLTALWM 
	move.w	#$09f0,BLTCON0(a5)	; BLTCON0 ; D
	move.w	#$0002,BLTCON1(a5)	; BLTCON1
	move.w	#40-2,BLTAMOD(a5)	; BLTAMOD 
	move.w	#40-2,BLTDMOD(a5)	; BLTDMOD 
	move.l	a1,BLTAPT(a5)	; BLTAPT  ; point to picture source
	move.l	a2,BLTDPT(a5)	; BLTDPT  ; point to SCREEN destination
	move.w	d0,BLTSIZE(a5)	; BLTSIZE: rectangle size
	
	addq	#2,a1
	
	dbra	d7, draw_equalizer
	
	rts

chan_level:	dc.w	0,0,0,0

channel_address:
	dc.l	pt_audchan1temp
	dc.l	pt_audchan2temp
	dc.l	pt_audchan3temp
	dc.l	pt_audchan4temp
		
	
;*****************************************************************************

	SECTION	GRAPHIC,DATA_C

COPPERLIST:
	dc.w	$8E,$2c81	; DiwStrt
	dc.w	$90,$2cc1	; DiwStop
	dc.w	$92,$38		; DdfStart
	dc.w	$94,$d0		; DdfStop
	dc.w	$102,0		; BplCon1
	dc.w	$104,0		; BplCon2
	dc.w	$108,0		; Bpl1Mod
	dc.w	$10a,0		; Bpl2Mod

	dc.w	$100,$1200	; bplcon0 - 1 SCREEN lowres

BPLPOINTERS:
	dc.w $e0,$0000,$e2,$0000	;first SCREEN

	dc.w	$0180,	$000	; color0
	dc.w	$0182,	$eee	; color1
	
	dc.w	$FFFF,	$FFFE	; End of copperlist

*****************************************************************************

	SECTION	Data,DATA_C

BAR:	
	dc.w	%0000000000000000, %0000000000000000, %0000000000000000, %0000000000000000
	dc.w	%1010101000000000, %1010101000000000, %1010101000000000, %1010101000000000

	SECTION Music,DATA_C

PT_DATA:
	incdir  "dh1:own/demo/repository/resources/mod/"
	incbin  "mod.broken"

	
*****************************************************************************

	SECTION	Screen,BSS_C	

SCREEN:
	ds.b	ScrBpl*h	; SCREEN azzerato lowres

	end

; +--------------------------+---------------------------+
; | AREA MODE ("normal")     | LINE MODE (line draw)     |
; +------+---------+---------+------+---------+----------+
; | BIT# | BLTCON0 | BLTCON1 | BIT# | BLTCON0 | BLTCON1  |
; +------+---------+---------+------+---------+----------+
; | 15   | ASH3    | BSH3    | 15   | ASH3    | BSH3     |
; | 14   | ASH2    | BSH2    | 14   | ASH2    | BSH2     |
; | 13   | ASH1    | BSH1    | 13   | ASH1    | BSH1     |
; | 12   | ASA0    | BSH0    | 12   | ASH0    | BSH0     |
; | 11   | USEA    | 0       | 11   | 1       | 0        |
; | 10   | USEB    | 0       | 10   | 0       | 0        |
; | 09   | USEC    | 0       | 09   | 1       | 0        |
; | 08   | USED    | 0       | 08   | 1       | 0        |
; | 07   | LF7(ABC)| DOFF    | 07   | LF7(ABC)| DPFF     |
; | 06   | LF6(ABc)| 0       | 06   | LF6(ABc)| SIGN     |
; | 05   | LF5(AbC)| 0       | 05   | LF5(AbC)| OVF      |
; | 04   | LF4(Abc)| EFE     | 04   | LF4(Abc)| SUD      |
; | 03   | LF3(aBC)| IFE     | 03   | LF3(aBC)| SUL      |
; | 02   | LF2(aBc)| FCI     | 02   | LF2(aBc)| AUL      |
; | 01   | LF1(abC)| DESC    | 01   | LF1(abC)| SING     |
; | 00   | LF0(abc)| LINE(=0)| 00   | LF0(abc)| LINE(=1) |
; +------+---------+---------+------+---------+----------+
