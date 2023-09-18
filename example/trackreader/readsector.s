***************************************************
*
*	example from AMIGA MACHINE LANGUAGE
*
***************************************************


* read sectors from df0 and wait for char before quit
*
* hint: run the program in debug mode and place mark before
* end of the program.
*
* Press any key to continue until the end


;***** Track disk-Basic function  10/86 S.D. *****

;               ILABEL ASSEMPRO:includes/Amiga.l   :AssemPro only

openlib      =-408
closelib     =-414
execbase    = 4                    ;defined in INIT_AMIGA

        * calls to amiga dos:

open         =-30
close        =-36
opendevice   =-444
closedev     =-450
sendIo       =-462
read         =-42
write        =-48
waitforchar  =-204

; 1005	Open existing file read/write positioned at beginning of file.
; 1006	Open freshly created file (delete old file) read/write, exclusive lock.
; 1004	Open old file w/shared lock, creates file if doesn't exist.
mode_old     = 1005
block_len    = 2
block_offset = 0

;No    Name          Function
;-----------------------------------------------------------------
;2     READ          Read one or more sectors
;3     WRITE         Write sectors
;4     UPDATE        Update the track buffer
;5     CLEAR         Erase track buffer
;9     MOTOR         Turn motor on/off
;10    SEEK          Search for a track
;11    FORMAT        Format tracks
;12    REMOVE        Initialize routine that is called when you
;					remove the disk
;13    CHANGENUM     Find out number of disk changes
;14    CHANGESTATE   Test if disk is in drive
;15    PROTSTATUS    Test if disk is write protected


;              INIT_AMIGA                   ;AssemPro only

run:
	bsr     init
	bra     test		;system test

init:					;system initialization and open 
	move.l  execbase,a6		;pointer to exec-library
	lea     dosname,a1
	moveq   #0,d0
	jsr     openlib(a6)		;open dos-library
	move.l  d0,dosbase
	beq     error

	lea     diskio,a1
	move.l  #diskrep,14(a1)
	moveq   #0,d0
	moveq   #0,d1
	lea     trddevice,a0
	jsr     opendevice(a6)		;open trackdisk.device
	tst.l   d0
	bne     error

bp:
	lea     consolname(pc),a1	;console-definition
	move.l  #mode_old,d0
	bsr     openfile		;console open
	beq     error
	move.l  d0,conhandle

	rts

test:
	bsr     accdisk

	bsr     getchr			;wait for character
	bra     qu

error:
	move.l  #-1,d7			;flag

qu:
	move.l  execbase,a6
	lea     diskio,a1
	move    #9,28(a1)		;command:MOTOR (0=off,1=on)
	move.l  #0,36(a1)		;motor off
	jsr     sendio(a6)

	move.l  conhandle,d1		;window close
	move.l  dosbase,a6
	jsr     close(a6)

	move.l  dosbase,a1		;dos.lib close
	move.l  execbase,a6
	jsr     closelib(a6)

	lea     diskio,a1
	move.l  32(a1),d7
	jsr     closedev(a6)

	rts

;               EXIT_AMIGA                   ;AssemPro only

openfile:				;open file
	move.l  a1,d1			;pointer to the I/O-definition text
							
	move.l  d0,d2
	move.l  dosbase,a6
	jsr     open(a6)
	tst.l   d0
	rts

scankey:				;test for key
	move.l  conhandle,d1                      
	move.l  #500,d2			;wait value
	move.l  dosbase,a6
	jsr     waitforchar(a6)
	tst.l   d0
	rts

getchr:					;get one character from keyboard
	move.l  #1,d3			;1 character
	move.l  conhandle,d1
	lea     inbuff,a1		;buffer-address
	move.l  a1,d2
	move.l  dosbase,a6
	jsr     read(a6)
	clr.l   d0
	move.b  inbuff,d0
	rts

accdisk:
	lea     diskio,a1
	move    #2,28(a1)			;command:READ                 
	move.l  #diskbuff,40(a1)		;buffer
	move.l  #block_len*512,36(a1)		;length: n sectors
	move.l  #block_offset*512,44(a1)	;offset: n sectors
	move.l  execbase,a6
	jsr     sendio(a6)
	rts

dosname:       dc.b 'dos.library',0,0
	even
dosbase:       dc.l 0
consolname:    dc.b 'RAW:0/100/640/100/** Test-Window S.D.V0.1',0
trddevice:     dc.b 'trackdisk.device',0
	even
conhandle:     dc.l 0
inbuff:        ds.b 8                                             
diskio:        ds.l 20
diskrep:       ds.l 8                                           
diskbuff:      ds.b 512*block_len

end
