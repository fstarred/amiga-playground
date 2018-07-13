;	This startup code belongs from a snippet of user borchen of EAB abime forum

; Constants

;OldOpenLibrary	= -$198		; -408
;CloseLibrary	= -$19E		; -414

MainCode:
	movem.l	d1-a6,-(sp)		; save CPU registers
	move.l	4.w,a6		; a6 = execbase

	move.l	#gfxname,a1		; a1 = gfxname
	jsr	-$198(a6)	; open gfxlibrary
	move.l	d0,a1			; a1 = gfxlibrary
	move.l	38(a1),oldcop		; save COPPER
	jsr	-$19E(a6)	; close gfxlibrary

	move.w	$dff01c,oldint		; save INTENAR
	move.w	$dff002,olddma		; save DMACONR

	move.w	#$7fff,$dff09a		; disable INTENA = turn off OS
	move.w	#$7fff,$dff09c		; disable INTREQ
	move.w	#$7fff,$dff09c		; twice -> amiga4000 hw bug!
	move.w	#$7fff,$dff096		; disable DMACON

	bsr.w	Start
	
Exit:
	move.w	#$7fff,$dff096		; clear DMACON

	move.w	olddma,d0
	or.w	#$8200,d0		; set bits of DMACON state
	move.w	d0,$dff096		; restore original DMACON

	move.l	oldcop,$dff080		; restore original copperlist
	move.w	#0,$dff088		; and activate it

	move.w	oldint,d0
	or.w	#$c000,d0		; set bits of INTENAR state
	move.w	d0,$dff09a		; restore INTENA state = turn on OS

	movem.l	(sp)+,d1-a6		; restore CPU registers
	moveq	#0,d0			; nice clean
	rts				; exit

gfxname:
	dc.b	"graphics.library",0,0
gfxbase:			; Dedicated to offset "graphics.library"
	dc.l	0	 
oldcop:				; Dedicated to system COP address
	dc.l	0
oldint:
	dc.w	0		; Dedicated to INTENA(R)
olddma:
	dc.w	0		; Dedicated to DMA
	
