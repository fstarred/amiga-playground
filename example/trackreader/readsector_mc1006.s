start:
;----- Library Vector Offsets
LVOAllocSignal=-330
LVOFindTask=-294
LVOOpenDevice=-444
LVODoIO=-456
;----- Node structure offsets
LN_TYPE=8
LN_PRI=9
;----- Message type for LN_TYPE
NT_MSGPORT=4
NT_MESSAGE=$05
;----- List structure offsets
LH_HEAD=0
LH_TAIL=4
LH_TAILPRED=8
;----- MsgPort structure offsets
MP_FLAGS=14
MP_SIGBIT=15
MP_SIGTASK=16
MP_MSGLIST=20
;----- Message structure offset
MN_REPLYPORT=14
;----- IOStdRequest structure offsets
IO_COMMAND=28
IO_LENGTH=36
IO_DATA=40
IO_OFFSET=44
;----- Command type for IO_COMMAND
CMD_FLUSH=$9

BLK_RD_LEN=195	; numbers of sectors/blocks to read

;----- Begin program
	lea.l	buffer,a0  ; move buffer address into a0
	move.l	#0,d0      ; move 0 into d0 (diskStation = internal drive)
	move.l	#0,d1      ; move 0 into d1 (block = block 0)
	move.l	#BLK_RD_LEN,d2    ; move block to read lenngth into d2
	move.l	#1,d3      ; move 1 into d3 (mode = READ)

	bsr	sector
	rts                ; return from subroutine
	  
  
sector:                          ; sector(a0=buffer,d0=diskStation,d1=block,d2=length,d3=mode)
	movem.l	d0-d7/a0-a6,-(a7)        ; push register values onto the stack
	lsl.l	#8,d1                    ; convert d1=block from blocks to offset in bytes
	add.l	d1,d1                    ; convert d1=block from blocks to offset in bytes
	lsl.l	#8,d2                    ; convert d2=length from blocks to bytes
	add.l	d2,d2                    ; convert d2=length from blocks to bytes
	move.l	d1,-(a7)                 ; push d1=block onto the stack
	move.l	d2,-(a7)                 ; push d2=length onto the stack
	move.l	a0,-(a7)                 ; push a0=buffer onto the stack
	move.l	d0,-(a7)                 ; push d0=diskStation onto the stack
	move.l	$4,a6                    ; move base of exec.library into a6
	lea.l	ws_diskport,a2           ; move ws_diskport address into a2 (MsgPort)
	moveq	#-1,d0                   ; move -1 into d0 (no preference for signal number)
	jsr	LVOAllocSignal(a6)       ; call AllocSignal. d0 = AllocSignal(d0)
	moveq	#-1,d1                   ; move -1 into d1
	move.b	d0,MP_SIGBIT(a2)         ; set signal number in MsgPort
	clr.b	MP_FLAGS(a2)             ; clear flags in MsgPort
	move.b	NT_MSGPORT,LN_TYPE(a2)   ; set message type in MsgPort.Node
	move.b	#120,LN_PRI(a2)          ; set priority in MsgPort.Node
	sub.l	a1,a1                    ; set a1 to 0 (find oneself)
	jsr	LVOFindTask(a6)          ; call FindTask. d0 = FindTask(a1)
	move.l	d0,MP_SIGTASK(a2)        ; set object to be signaled in MsgPort to result of FindTask
	lea.l	MP_MSGLIST(a2),a0        ; Initialize MsgPort.List
	move.l	a0,LH_HEAD(a0)           ; Initialize MsgPort.List
	addq.l	#LH_TAIL,(a0)            ; Initialize MsgPort.List
	clr.l	LH_TAIL(a0)              ; Initialize MsgPort.List
	move.l	a0,LH_TAILPRED(a0)       ; Initialize MsgPort.List
	lea.l	ws_diskreq,a1            ; move ws_diskreq address into a1 (IOStdReq)
	move.b	#NT_MESSAGE,LN_TYPE(a1)  ; set node type in IOStdReq.Message.Node
	move.l	a2,MN_REPLYPORT(a1)      ; set reply port a2 in IOStdReq.Message
	lea.l	ws_devicename,a0         ; set a0=devName
	move.l	(a7)+,d0                 ; set d0=diskStation by popping stack
	clr.l	d1                       ; set d1=flags (0 for opening)
	jsr	LVOOpenDevice(a6)        ; call OpenDevice. (d0=returnCode) = OpenDevice(a0=devName,d0=unitNumber,a1=IORequest,d1=flags)
	move.l	(a7)+,IO_DATA(a1)        ; set data in IOStdReq.Data to buffer by popping stack
	andi.l	#3,d3                    ; convert subroutine input mode to command 
	addq.w	#1,d3                    ; convert subroutine input mode to command 
	move.w	d3,IO_COMMAND(a1)        ; set IOStdReq.Command to d3
	move.l	(a7)+,IO_LENGTH(a1)      ; set IOStdReq.Length to length by popping stack
	move.l	(a7)+,IO_OFFSET(a1)      ; set IOStdReq.Offset to block by popping stack
	jsr	LVODoIO(a6)              ; call DoIO. (d0=returnCode) = DoIO(a1=IORequest)
	move.l	d0,d7                    ; move d0=returnCode into d7
	move.l	#0,IO_LENGTH(a1)         ; set IOStdReq.Length to 0
	move.w	#CMD_FLUSH,IO_COMMAND(a1); set IOStdReq.Command to CMD_FLUSH
	jsr	LVODoIO(a6)              ; call DoIO. (d0=returnCode) = DoIO(a1)
	movem.l	(a7)+,d0-d7/a0-a6        ; pop values from the stack into the registers
	rts                              ; return from subroutine
ws_diskport:  
	blk.l	100,0  
ws_diskreq:
	blk.l	15,0
ws_devicename:
	dc.b	"trackdisk.device",0,0


buffer:
	blk.b	512*BLK_RD_LEN,0           ; allocate buffer for 512*n blocks
