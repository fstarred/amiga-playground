*************************************
*
*
*	BOOTBLOCK USING TRACKDEVICE
*
*
*************************************

; WARNING! WriteFlag=1 will write data to disk on df0:

; - In BootBlock, device commands CMD_CLEAR, TH_CHANGENUM and CDM_READ
; can be executed without error
; 
; - The boot code is invoked with the I/O request used to issue the device
; command in register A1, with the io_Offset pointing to the beginning of the
; partition (the origin of the boot blocks) and Sysbase in A6
;
; see also:
;
; http://amigadev.elowar.com/read/ADCD_2.1/Devices_Manual_guide/node007D.html

MAIN_ADDRESS = $70000

DoIo = -456

ProgSectors=2	; trainer expected size expressed in sectors

Writeflag = 1

	IF WriteFlag = 1
	AUTO	WS\BOOTBLOCK\0\ProgSectors+2\CC\
	ENDC
	
bootblock:
	dc.b	'DOS',0
	dc.l	0
	dc.l	880
	
bootEntry:

	lea	MAIN_ADDRESS,a5

	move.l	#(ProgSECTORS)*512,36(a1)	; Length
	move.l	a5,40(a1)			; ReadBuffer
	move.l	#1024,44(a1)			; Offset
	jsr	DoIo(a6)			; execute

	move.l	#0,36(a1)			; motor off
	move.w	#9,28(a1)			; command:MOTOR
	jsr	DoIo(a6)

	jmp	(a5)				; Jmp to sysoff

bootEnd:
	ds.b	1024-(bootEnd-bootBlock)	; fill remaining space 
						; of first 2 sectors with $00
mainStart:
	incdir	"dh1:/amiga-playground"
	include	"/example/bootblock/trainer/trainer.S"
mainEnd:
	ds.b	(ProgSectors*512)-(mainEnd-mainStart)	
						; fill remaining space
						; of prog sectors with $00
End

	PRINTT	"BOOTBLOCK REAL SIZE..."
	PRINTV	bootEnd
	PRINTT	"MAIN PROG REAL SIZE..."
	PRINTV	mainEnd-mainStart

