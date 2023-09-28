*************************************
*
*
*	BOOTBLOCK USING TRACKDEVICE
*
*
*************************************

; before running with WriteFlag=1,
; ensure to prepare binary of sysoff.s
; (check instructions on sysoff source

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

Writeflag = 1

	IF WriteFlag = 1
	AUTO	WS\BOOTBLOCK\0\3\CC\
	ENDC
	
bootblock:
	dc.b	'DOS',0
	dc.l	0
	dc.l	880
	
bootEntry:

	lea	MAIN_ADDRESS,a5

	move.l	#(end-mainStart),36(a1)		; Length (512)
	move.l	a5,40(a1)			; ReadBuffer
	move.l	#mainStart-bootblock,44(a1)	; Offset (1024)
	jsr	DoIo(a6)			; execute

	move.l	#0,36(a1)			; motor off
	move.w	#9,28(a1)			; command:MOTOR
	jsr	DoIo(a6)

	jmp	(a5)				; Jmp to sysoff

bootEnd:
	ds.b	(1024-(bootEnd-bootblock))	; fill remaining space 
						; of the 2 sectors with $00
mainStart:
	incbin	"dh1:/sysoff"
mainEnd:
	ds.b	512-(mainEnd-mainStart)		; fill remaining space with $0.
						; Depending og the bin size,
						; you must use multiple of 512
						; (i.e. if bin size = 1120,
						; use 1536)
End:
