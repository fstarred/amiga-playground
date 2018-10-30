
	SECTION	Code,CODE	; This command will run the below code
				; on FAST RAM (if enough) or CHIP RAM

DMASET	= %1000001010000000
;	  %-----axbcdefghij
;	a: Blitter Nasty
;	x: Enable DMA
;	b: Bitplane DMA (if this isn't set, sprites disappear!)
;	c: Copper DMA
;	d: Blitter DMA
;	e: Sprite DMA
;	f: Disk DMA
;	g-j: Audio 3-0 DMA

INTENA=	    %1010000000000000
;           -FEDCBA9876543210

;	F	SET/CLR	0=clear, 1=set bits that are set to 1 below
;	E	INTEN	Enable interrupts below (master toggle)
;	D	EXTER	Level 6 External interrupt
;	C	DSKSYN	Level 5 Disk Sync value found
;	B	RBF	Level 5 Receive Buffer Full (serial port)
;	A	AUD3	Level 4 Audio Interrupt channel 3
;	9	AUD2	Level 4 Audio Interrupt channel 2
;	8	AUD1	Level 4 Audio Interrupt channel 1
;	7	AUD0	Level 4 Audio Interrupt channel 0
;	6	BLIT	Level 3 Blitter Interrupt
;	5	VERTB	Level 3 Vertical Blank Interrupt
;	4	COPER	Level 3 Copper Interrupt
;	3	PORTS	Level 2 CIA Interrupt (I/O ports and timers)
;	2	SOFT	Level 1 Software Interrupt
;	1	DSKBLK	Level 1 Disk Block Finished Interuppt
;	0	TBE	Level 1 Transmit Buffer Empty Interrupt (serial port)


;;    ---  screen buffer dimensions  ---

w	=320
h	=256

bpls = 1
wbl = 303


P61mode	=1	;Try other modes ONLY IF there are no Fxx commands >= 20.
		;(f.ex., P61.new_ditty only works with P61mode=1)


;;    ---  options common to all P61modes  ---

usecode	=-1	;CHANGE! to the USE hexcode from P61con for a big 
		;CPU-time gain! (See module usecodes at end of source)
		;Multiple songs, single playroutine? Just "OR" the 
		;usecodes together!

		;...STOP! Have you changed it yet!? ;)
		;You will LOSE RASTERTIME AND FEATURES if you don't.

P61pl=usecode&$400000

split4	=0	;Great time gain, but INCOMPATIBLE with F03, F02, and F01
		;speeds in the song! That's the ONLY reason it's default 0.
		;So ==> PLEASE try split4=1 in ANY mode!
		;Overrides splitchans to decrunch 1 chan/frame.
		;See ;@@ note for P61_SetPosition.


splitchans=1	;#channels to be split off to be decrunched at "playtime frame"
		;0=use normal "decrunch all channels in the same frame"
		;Experiment to find minimum rastertime, but it should be 1 or 2
		;for 3-4 channels songs and 0 or 1 with less channels.

visuctrs=1	;enables visualizers in this example: P61_visuctr0..3.w 
		;containing #frames (#lev6ints if cia=1) elapsed since last
		;instrument triggered. (0=triggered this frame.)
		;Easy alternative to E8x or 1Fx sync commands.

asmonereport	=0	;ONLY for printing a settings report on assembly. Use
			;if you get problems (only works in AsmOne/AsmPro, tho)

p61system=0	;1=system-friendly. Use for DOS/Workbench programs.

p61exec	=0	;0 if execbase is destroyed, such as in a trackmo.

p61fade	=0	;enable channel volume fading from your demo

channels=4	;<4 for game sound effects in the higher channels. Incompatible
		; with splitchans/split4.

playflag=0	;1=enable music on/off capability (at run-time). .If 0, you can
		;still do this by just, you know, not calling P61_Music...
		;It's a convenience function to "pause" music in CIA mode.

p61bigjtab=0	;1 to waste 480b and save max 56 cycles on 68000.

opt020	=0	;1=enable optimizations for 020+. Please be 68000 compatible!
		;splitchans will already give MUCH bigger gains, and you can
		;try the MAXOPTI mode.

p61jump	=0	;0 to leave out P61_SetPosition (size gain)
		;1 if you need to force-start at a given position fex in a game

C	=0	;If you happen to have some $dffxxx value in a6, you can 
		;change this to $xxx to not have to load it before P61_Music.

clraudxdat=0	;enable smoother start of quiet sounds. probably not needed.

optjmp	=1	;0=safety check for jump beyond end of song. Clear it if you 
		;play unknown P61 songs with erroneous Bxx/Dxx commands in them

oscillo	=0	;1 to get a sample window (ptr, size) to read and display for 
		;oscilloscope type effects (beta, noshorts=1, pad instruments)
		;IMPORTANT: see ;@@ note about chipmem dc.w buffer.

quietstart=0	;attempt to avoid the very first click in some modules
		;IMPORTANT: see ;@@ note about chipmem dc.w buffer.

use1Fx=0	;Optional extra effect-sync trigger (*). If your module is free
		;from E commands, and you add E8x to sync stuff, this will 
		;change the usecode to include a whole code block for all E 
		;commands. You can avoid this by only using 1Fx. (You can 
		;also use this as an extra sync command if E8x is not enough, 
		;of course.)

;(*) Slideup values>116 causes bugs in Protracker, and E8 causes extra-code 
;for all E-commands, so I used this. It's only faster if your song contains 0
;E-commands, so it's only useful to a few, I guess. Bit of cyclemania. :)

;Just like E8x, you will get the trigger after the P61_Music call, 1 frame 
;BEFORE it's heard. This is good, because it allows double-buffered graphics 
;or effects running at < 50 fps to show the trigger synced properly.



;;    ---  CIA mode options (default) ---

	ifeq P61mode-1

p61cia	=1	;call P61_Music on the CIA interrupt instead of every frame.

lev6	=1	;1=keep the timer B int at least for setting DMA.
		;0="FBI mode" - ie. "Free the B-timer Interrupt".

		;0 requires noshorts=1, p61system=0, and that YOU make sure DMA
		;is set at 11 scanlines (700 usecs) after P61_Music is called.
		;AsmOne will warn you if requirements are wrong.

		;DMA bits will be poked in the address you pass in A4 to 
		;P61_init. (Update P61_DMApokeAddr during playing if necessary,
		;for example if switching Coppers.)

		;P61_Init will still save old timer B settings, and initialize
		;it. P61_End will still restore timer B settings from P61_Init.
		;So don't count on it 'across calls' to these routines.
		;Using it after P61_Init and before P61_End is fine.

noshorts=0	;1 saves ~1 scanline, requires Lev6=0. Use if no instrument is
		;shorter than ~300 bytes (or extend them to > 300 bytes).
		;It does this by setting repeatpos/length the next frame 
		;instead of after a few scanlines,so incompatible with MAXOPTI

dupedec	=0	;0=save 500 bytes and lose 26 cycles - I don't blame you. :)
		;1=splitchans or split4 must be on.

suppF01	=1	;0 is incompatible with CIA mode. It moves ~100 cycles of
		;next-pattern code to the less busy 2nd frame of a notestep.
		;If you really need it, you have to experiment as the support 
		;is quite complex. Basically set it to 1 and try the various 
		;P61modes, if none work, change some settings.

	endc

;;    ---  VBLANK mode options ---

	ifeq P61mode-2

p61cia	=0
lev6	=1	;still set sound DMA with a simple interrupt.
noshorts=0	;try 1 (and pad short instruments if nec) for 1 scanline gain
dupedec	=0
suppF01	=P61pl	;if 1, split4=1 may cause sound errors. but try it anyway. :)
	
	endc

;;    ---  COPPER mode options ---

	ifeq P61mode-3

p61cia	=0
lev6	=0	;don't set sound DMA with an interrupt.
		;(use the copper to set sound DMA 11 scanlines after P61_Music)
noshorts=1	;You must pad instruments < 300 bytes for this mode to work.
dupedec	=0
suppF01	=P61pl	;if 1, split4=1 may cause sound errors. but try it anyway. :)

	endc

;;    ---  MAXOPTI mode options ---

	ifeq P61mode-4

p61cia	=0
lev6	=0
noshorts=1	;You must pad instruments < 300 bytes for this mode to work.
dupedec	=1
suppF01	=P61pl	;if 1, split4=1 may cause sound errors. but try it anyway. :)

	endc
	
;*****************************************************************************
	incdir	"dh1:own/demo/repository/startup/borchen/"
	include	"startup.s"	; 
	incdir  "dh1:own/demo/repository/replay/"
	include	"P6112-Play.i"
	
	
;*****************************************************************************

WAITVB MACRO
   	move.l  $dff004,d0      ; wait
 	and.l   #$0001ff00,d0   ; for
   	cmp.l   #wbl<<8,d0      ; rasterline 303
	bne.s   \1
	ENDM

WAITVB2 MACRO
	move.l  $dff004,d0      ; wait
 	and.l   #$0001ff00,d0   ; for
	cmp.l   #wbl<<8,d0      ; rasterline 303
	beq.s   \1
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
	
Start:	

	move.w	#DMASET,$dff096		; enable necessary bits in DMACON
	move.w  #INTENA,$dff09a		; INTENA
	
	move.l	#COPPERLIST,$dff080	; COP1LCH set custom copperlist
	move.w	#0,$dff088		; COPJMP1 activate copperlist

;;    ---  Call P61_Init  ---
	movem.l d0-a6,-(sp)

	lea M_DATA,a0
	sub.l a1,a1
	sub.l a2,a2
	moveq #0,d0
	jsr P61_Init

	movem.l (sp)+,d0-a6
	
Main:
	WAITVB	Main
	
Wait	WAITVB2	Wait
	
	RMOUSE WaitRM
	
	LMOUSE	Main

	movem.l d0-a6,-(sp)
	jsr P61_End
	movem.l (sp)+,d0-a6
	
	rts
	
;*****************************************************************************

	SECTION	Copper,DATA_C

COPPERLIST:
SPRITEPOINTERS:
	dc.w	$120,$0000,$122,$0000,$124,$0000,$126,$0000,$128,$0000	; clear sprite pointers
	dc.w	$12a,$0000,$12c,$0000,$12e,$0000,$130,$0000,$132,$0000  ; clear sprite pointers
	dc.w	$134,$0000,$136,$0000,$138,$0000,$13a,$0000,$13c,$0000  ; clear sprite pointers
	dc.w	$13e,$0000

	dc.w	$8E,$2c81	; DiwStrt
	dc.w	$90,$2cc1	; DiwStop
	dc.w	$92,$38		; DdfStart
	dc.w	$94,$d0		; DdfStop
	dc.w	$102,0		; BplCon1
	dc.w	$104,0		; BplCon2
	dc.w	$108,0		; Bpl1Mod
	dc.w	$10a,0		; Bpl2Mod

	dc.w	$100,bpls*$1000+$200	; bplcon0 - bitplane lowres

BPLPOINTERS:
	dc.w 	$e0,$0000,$e2,$0000	; bitplane 1
	
	dc.w 	$0180, $0000		
	
	dc.w	$FFFF, $FFFE	; End of copperlist

	
*****************************************************************************

	SECTION	Data,DATA_C

M_DATA:
	incdir  "dh1:own/demo/repository/resources/mod/"
	incbin	"p61.venezia"

	
*****************************************************************************

	SECTION	Screen,BSS_C	

SCREEN:
	ds.b	40*256*bpls	; 

	end
