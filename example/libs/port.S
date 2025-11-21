;---------------------------------------------------------------------------
; CreatePort_KS12.s
;
; A compatible implementation of creating a Message Port on Kickstart 1.2
; (and 1.3). This manually performs the work that CreatePort() does in V37+.
;---------------------------------------------------------------------------

	INCDIR	"INCLUDE:"
	INCLUDE "exec/exec.i"
	INCLUDE "exec/exec_lib.i"

;---------------------------------------------------------------------------
; Main Entry Point
;---------------------------------------------------------------------------
Start:
    ; 1. Allocate a Signal Bit
    ;    We need a signal bit for the port to notify us when a message arrives.
    ;    -1 in D0 asks for "any available bit".
    MOVEQ   #-1,D0
    CALLEXEC AllocSignal
    MOVE.B  D0,D7           ; Save signal bit in D7
    CMP.B   #-1,D7          ; Check if allocation failed
    BEQ     .no_signal

    ; 2. Allocate Memory for the MsgPort Structure
    ;    We need MEMF_PUBLIC so other tasks can see the port.
    ;    MEMF_CLEAR saves us from zeroing out fields manually.
    MOVE.L  #MP_SIZE,D0     ; Size of MsgPort structure
    MOVE.L  #MEMF_PUBLIC!MEMF_CLEAR,D1
    CALLEXEC AllocMem
    TST.L   D0
    BEQ     .no_mem
    MOVE.L  D0,A2           ; A2 now holds the pointer to our new MsgPort

    ; 3. Initialize the MsgPort
    ;    This is the part CreatePort() usually handles.

    ; A. Set up Node properties
    MOVE.B  #NT_MSGPORT,LN_TYPE(A2) ; Node Type
    MOVE.B  #0,LN_PRI(A2)           ; Priority (usually 0)
    
    ; Optional: Give the port a name if you want it to be public (FindPort)
    ; MOVE.L #MyPortName,LN_NAME(A2)

    ; B. Set up Flags and Signal info
    MOVE.B  #PA_SIGNAL,MP_FLAGS(A2) ; Flag: Signal us on arrival
    MOVE.B  D7,MP_SIGBIT(A2)        ; The signal bit we allocated earlier

    ; C. Set the SigTask (Crucial!)
    ;    We must tell the port WHICH task to signal. We need our own Task address.
    SUB.L   A1,A1           ; FindTask(0) returns this task
    CALLEXEC FindTask
    MOVE.L  D0,MP_SIGTASK(A2)

    ; D. Initialize the Message List (mp_MsgList)
    ;    The port contains a List where messages are queued. 
    ;    A List must be initialized so Head points to Tail, Tail is NULL, 
    ;    and TailPred points to Head.
    
    ;    MP_MSGLIST is the offset to the list structure within the port
    LEA     MP_MSGLIST(A2),A0       ; A0 points to the list header inside the port

    ;    Initialize LH_HEAD (points to LH_TAIL)
    LEA     LH_TAIL(A0),A1
    MOVE.L  A1,LH_HEAD(A0)

    ;    Initialize LH_TAIL (must be NULL)
    CLR.L   LH_TAIL(A0)

    ;    Initialize LH_TAILPRED (points to LH_HEAD)
    LEA     LH_HEAD(A0),A1
    MOVE.L  A1,LH_TAILPRED(A0)

    ; 4. Make the Port Known (Optional)
    ;    If you want other programs to find this port by name, call AddPort.
    ;    If this is a private port just for your ReplyMsg, you don't strictly need this.
    ;    We will skip AddPort for this simple example to avoid needing a name,
    ;    but the port is now fully functional.

    ; --- PORT IS NOW READY ---
    ; At this point, (A2) is a valid port. You can put it into 'mn_ReplyPort' 
    ; of a message and send it off.

    ; [ Your Main Loop Code Would Go Here ]
    ; Wait for the signal bit (1 << D7) to be set.

.cleanup:
    ; 5. Cleanup (Reverse the creation steps)
    
    ; Remove port (if you used AddPort, use RemPort here)
    ; For this example, we just free memory.
    
    ; Free the MsgPort Memory
    MOVE.L  A2,A1
    MOVE.L  #MP_SIZE,D0
    CALLEXEC FreeMem

.no_mem:
    ; Free the Signal Bit
    MOVE.B  D7,D0
    CALLEXEC FreeSignal

.no_signal:
    MOVEQ   #0,D0
    RTS

	END
	
1. Allocate a Signal Bit
2. Allocate Memory for the MsgPort Structure
3. Initialize the MsgPort
	a. Set up Node properties
	b. Set up Flags and Signal info
	c. Set the SigTask (Crucial!)
	d. Initialize the Message
4. * optional, skipped
5. Cleanup
