;---------------------------------------------------------------------------
; Example: create a MsgPort manually (Kickstart 1.2/1.3 style),
; allocate an IORequest, open timer.device, issue a TR_ADDREQUEST,
; wait for the reply via the MsgPort signal, then clean up.
;
; Notes:
;  - This example is conservative and intended for classic Amiga Exec.
;---------------------------------------------------------------------------

	INCDIR  "INCLUDE:"
	INCLUDE "exec/exec.i"
	INCLUDE "exec/exec_lib.i"

	INCLUDE "devices/timer.i"

; --------------------------------------------------------------------------
; External (Exec) calls - CALLEXEC macro used in original file
; --------------------------------------------------------------------------
; We assume your assembler has CALLEXEC defined to call Exec functions.
; If not, you can replace CALLEXEC X with jsr -X where appropriate, or
; with the actual calling convention your toolchain expects.
;
; Examples (left commented since original file already relied on CALLEXEC):
;    CALLEXEC AllocSignal
;    CALLEXEC AllocMem
;    CALLEXEC FreeSignal
;    CALLEXEC FreeMem
;    CALLEXEC FindTask
;    CALLEXEC OpenDevice
;    CALLEXEC SendIO
;    CALLEXEC Wait
;    CALLEXEC GetMsg
;    CALLEXEC CloseDevice
; --------------------------------------------------------------------------



START:
;-----------------------------------------------------------
; 1) Allocate a Signal Bit
;    -1 asks for "any available bit"
;-----------------------------------------------------------
	MOVEQ   #-1,D0
	CALLEXEC AllocSignal
	MOVE.B  D0,D7           ; SAVE SIGNAL BIT NUMBER IN D7
	CMP.B   #-1,D7
	BEQ     .no_signal

;-----------------------------------------------------------
; 2) Allocate memory for the MsgPort structure
;    Use MEMF_PUBLIC so the port is visible to other tasks (optional).
;    MEMF_CLEAR zeros the memory.
;-----------------------------------------------------------
	MOVE.L  #MP_SIZE,D0
	MOVE.L  #MEMF_PUBLIC!MEMF_CLEAR,D1
	CALLEXEC AllocMem
	TST.L   D0
	BEQ     .no_mem
	MOVE.L  D0,A2           ; A2 = POINTER TO MSGPORT

;-----------------------------------------------------------
; 3) Initialize the MsgPort fields (Node, flags, sigbit, SigTask,
;    list initialization). This mimics CreatePort() behavior.
;-----------------------------------------------------------

	; Node type
	MOVE.B  #NT_MSGPORT,LN_TYPE(A2)
	MOVE.B  #0,LN_PRI(A2)

	; Flags: signal on arrival
	MOVE.B  #PA_SIGNAL,MP_FLAGS(A2)
	MOVE.B  D7,MP_SIGBIT(A2)

	; SigTask: our own task (FindTask(0) returns current task)
	SUB.L   A1,A1           ; clear A1 for FindTask(0)
	CALLEXEC FindTask
	MOVE.L  D0,MP_SIGTASK(A2)

	; Initialize the mp_MsgList (List) inside the port
	LEA     MP_MSGLIST(A2),A0
	; LH_HEAD -> points to LH_TAIL
	LEA     LH_TAIL(A0),A1
	MOVE.L  A1,LH_HEAD(A0)
	; LH_TAIL -> NULL
	CLR.L   LH_TAIL(A0)
	; LH_TAILPRED -> points to LH_HEAD
	LEA     LH_HEAD(A0),A1
	MOVE.L  A1,LH_TAILPRED(A0)

	; Port is now ready. A2 == MsgPort, D7 == signal bit number.
; -----------------------------------------------------------------
; 4) Allocate an IORequest (conservative static allocation via AllocMem)
;    NOTE: IO request structure sizes vary. 
; -----------------------------------------------------------------
	MOVE.L  #IOSTD_SIZE,D0
	MOVE.L  #MEMF_PUBLIC!MEMF_CLEAR,D1
	CALLEXEC AllocMem
	TST.L   D0
	BEQ     .no_ioreq
	MOVE.L  D0,A3           ; A3 = pointer to IORequest block

; Set the Message.reply port inside the IORequest so device replies
; return to our manually created port.
; MN_REPLYPORT(offset) is defined in exec/exec.i and assumes a Message
; starts at the beginning of the IORequest (which it does for IOStdReq).

	MOVE.L  A2,MN_REPLYPORT(A3)     ; io->io_Message.mn_ReplyPort = A2

; -----------------------------------------------------------------
; 5) Open the device (timer.device example)
;    OpenDevice(name, unit, ioRequest, flags)
; -----------------------------------------------------------------
	LEA	TimerLibName(pc),A0
	MOVEQ	#0,D0             ; unit 0 (timer has only one unit)
	MOVE.L	A3,A1             ; A1 = IORequest ptr
	CALLEXEC OpenDevice
	TST.L	D0
	BNE.W	.open_failed

; -----------------------------------------------------------------
; 6) Issue asynchronous request: TR_ADDREQUEST (add a delay)
;    We put 1_000_000 microseconds (1 second) in io_Length and send.
; -----------------------------------------------------------------
	MOVE.W  #TR_ADDREQUEST,IO_COMMAND(A3)
	MOVE.L  #1000000,IO_LENGTH(A3)   ; 1s in microseconds
	MOVE.L  A3,A1
	CALLEXEC SendIO

; -----------------------------------------------------------------
; 7) Wait for the reply using our port's signal bit
;    We form a mask with the allocated signal bit number in D7 and call Wait.
;    Then we call GetMsg to retrieve the message.
; -----------------------------------------------------------------
.wait_for_reply:

	; Build signal mask in D0: set bit number D7

	MOVEQ   #0,D0
	BSET    D7,D0           ; set bit #D7 in D0
	MOVE.L  D0,D1
	; D0 contains mask (some CALLEXEC Wait wrappers expect D0)

	CALLEXEC Wait

	; Try to fetch a message from our port

	MOVE.L  A2,A0
	CALLEXEC GetMsg
	TST.L   D0

	; no message yet (shouldn't normally happen after Wait)
	BEQ     .wait_for_reply 

    ; D0 now holds pointer to the Message (which is our IORequest pointer)
    ; So we can check IO error/status fields in the IORequest (A3)
    ; io_Error is typically at IO_ERROR(A3) macro

	TST.B   IO_ERROR(A3)
	BEQ     .io_ok

    ; There was an error: place error code in D0 and continue to cleanup
	MOVE.L  D1,D0
	BRA     .cleanup

.io_ok:
    ; Successful completion.
    ; You can examine IO_ACTUAL / IO_LENGTH / other fields as needed here.
    ; Example: read returned value (if the request type provides one)
    ; move.l IO_ACTUAL(A3),D0    ; if applicable

    ; (Do more work here if you wish)

; -----------------------------------------------------------------
; 8) Close device and cleanup (fall through to cleanup)
; -----------------------------------------------------------------
	MOVE.L  A3,A1
	CALLEXEC CloseDevice

.cleanup:
	; Free IORequest memory (if allocated)
	CMPA.L  #0,A3
	BEQ     .skip_free_ioreq
	MOVE.L  A3,A1
	MOVE.L  #IOSTD_SIZE,D0
	CALLEXEC FreeMem

.skip_free_ioreq:
	; Free the MsgPort memory (if allocated)
	CMPA.L  #0,A2
	BEQ     .skip_free_port
	MOVE.L  A2,A1
	MOVE.L  #MP_SIZE,D0
	CALLEXEC FreeMem

.skip_free_port:
	; Free the signal bit
	MOVE.B  D7,D0
	CALLEXEC FreeSignal

.exit_gracefully:
	MOVEQ #0,D0
	RTS

.no_ioreq:
	MOVEQ #-3,D0
	RTS

.open_failed:
	MOVEQ #-4,D0
	RTS

.no_mem:
	MOVEQ #-2,D0
	RTS

.no_signal:
	MOVEQ #-1,D0
	RTS

; -------------------------------------------------------------------------
; data
; -------------------------------------------------------------------------

	DC.B	0
TimerLibName:
	TIMERNAME
	
	END

The following is the expected flow:

1. Allocate a Signal Bit
	AllocSignal
2. Allocate memory for the MsgPort structure	
	AllocMem
3. Initialize the MsgPort fields
	FindTask
4. Allocate an IORequest
	AllocMem
5. Open the device
	OpenDevice
6. Issue asynchronous request
	SendIO
7. Wait for the reply using our port's signal bit
	Wait
	GetMsg
8. Close device and cleanup
	8a. Close Device
		CloseDevice
	8b. Free IORequest memory (if allocated)
		FreeMem
	8c. Free the MsgPort memory (if allocated)
		FreeMem
	8d. Free the signal bit
		FreeSignal
