;---------------------------------------------------------------------------
; Example: create a MsgPort manually (Kickstart 1.2/1.3 style),
; allocate an IORequest, open audio.device, play sound
; wait for the reply via the MsgPort signal, then clean up.
;
;	Read the audio example on Amiga Rom Kernel Manual !!
;
; Notes:
;  - This example is conservative and intended for classic Amiga Exec.
;---------------------------------------------------------------------------

	INCDIR  INCLUDE:
	INCLUDE "exec/exec.i"
	INCLUDE "exec/exec_lib.i"

	INCLUDE "devices/audio.i"

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
;    CALLEXEC BeginIO
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
	MOVE.L  #ioa_SIZEOF,D0
	MOVE.L  #MEMF_PUBLIC!MEMF_CLEAR,D1
	CALLEXEC AllocMem
	TST.L   D0
	BEQ     .no_ioreq
	MOVE.L  D0,A3           ; A3 = pointer to IORequest block

;----------------------------------------------------------------------
; 5) Set up the IOAudio Request before open the device
;
; A special feature of the OpenDevice() function with the audio device
; allows you to automatically allocate channels for your program to use when
; the device is opened.  This is convenient since you must allocate one or
; more channels before you can produce sound.
;
; Set up the audio I/O block for channel allocation:                   
; ioa_Request.io_Message.mn_ReplyPort is the address of a reply port.  
; ioa_Request.io_Message.mn_Node.ln_Pri sets the precedence (priority) 
;   of our use of the audio device. Any tasks asking to use the audio  
;   device that have a higher precedence will steal the channel from us.
; ioa_Request.io_Command is the command field for I/O.                  
; ioa_Request.io_Flags is used for the I/O flags.                       
; ioa_AllocKey will be filled in by the audio device if the allocation 
;   succeeds. We must use the key it gives for all other commands sent.
; ioa_Data is a pointer to the array listing the channels we want.     
; ioa_Length tells how long our list of channels is.                   
;----------------------------------------------------------------------

	MOVE.L  A2,MN_REPLYPORT(A3)     ; io->io_Message.mn_ReplyPort = A2
	MOVE.B  #0,LN_PRI(A3)
	MOVE.W  #ADCMD_ALLOCATE,IO_COMMAND(A3)
	MOVE.B  #ADIOF_NOWAIT,IO_FLAGS(A3)	
	MOVE.W  #0,ioa_AllocKey(A3)
	MOVE.L	#Chans,ioa_Data(A3)
	MOVE.L	#4,ioa_Length(A3)		

; -----------------------------------------------------------------
; 6) Open the device (audio.device example)
;    OpenDevice(name, unit, ioRequest, flags)
; -----------------------------------------------------------------
	LEA	AudioLibName(PC),A0
	MOVEQ	#0,D0             ; unit 0
	MOVE.L	A3,A1             ; A1 = IORequest ptr
	CALLEXEC OpenDevice
	TST.L	D0
	BNE.W	.open_failed

;------------------------------------------------------------
; 7) Set up the IOAudio Request for playing the sample
;
; Set up audio I/O block to play a sample using CMD_WRITE.   
; The io_Flags are set to ADIOF_PERVOL so we can set the     
;    period (speed) and volume with the our sample;          
; ioa_Data points to the sample; ioa_Length gives the length 
; ioa_Cycles tells how many times to repeat the sample       
; If you want to play the sample at a given sampling rate,   
; set ioa_Period = clock/(given sampling rate)               
;------------------------------------------------------------	

	MOVE.W  #CMD_WRITE,IO_COMMAND(A3)
	MOVE.B  #ADIOF_PERVOL,IO_FLAGS(A3)	
	MOVE.L	#SampleData,ioa_Data(A3)
	MOVE.L  #SampleLen,ioa_Length(A3)
	MOVE.W  #424,ioa_Period(A3)
	MOVE.W  #64,ioa_Volume(A3)
	MOVE.W  #1,ioa_Cycles(A3)	
	MOVE.L  A3,A1
	BEGINIO

; -----------------------------------------------------------------
; 8) Wait for the reply using our port's signal bit
;    We form a mask with the allocated signal bit number in D7 and call Wait.
;    Then we call GetMsg to retrieve the message.
; -----------------------------------------------------------------
.wait_for_reply:

	; Build signal mask in D0: set bit number D7

	MOVEQ   #0,D0
	BSET    D7,D0           ; set bit #D7 in D0
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
; 9) Close device and cleanup (fall through to cleanup)
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
AudioLibName:
	AUDIONAME
   	EVEN

Chans: 
	DC.B 1,2,4,8	; Request channels order
			; see Allocation and Arbitration Commands
			; chapter

	SECTION	SAMPLE,DATA_C
	
	EVEN
SampleData:	
	INCDIR	RESOURCES:
	INCBIN	sounds/Alien
SampleLen   EQU *-SampleData    

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
5. Set up the IOAudio Request before open the device	
6. Open the device
	OpenDevice
7. Set up the IOAudio Request for playing the sample
	BeginIO
8. Wait for the reply using our port's signal bit
	Wait
	GetMsg
9. Close device and cleanup
	8a. Close Device
		CloseDevice
	8b. Free IORequest memory (if allocated)
		FreeMem
	8c. Free the MsgPort memory (if allocated)
		FreeMem
	8d. Free the signal bit
		FreeSignal


Command          Operation
-------          ---------
 ADCMD_ALLOCATE    Allocate one or more of the four audio channels.

 ADCMD_FINISH      Abort the current write request on one or more of the
                   channels.  Can be done immediately or at the end of the
                   current cycle.

 ADCMD_FREE        Free one or more audio channels.

 ADCMD_LOCK        Lock one or more audio channels.

 ADCMD_PERVOL      Change the period and volume for writes in progress. Can
                   be done immediately or at the end of the cycle.

 ADCMD_SETPREC     Set the allocation precedence of one or more channels.

 ADCMD_WAITCYCLE   Wait for the current write cycle to complete on a single
                   channel.  Returns at the end of the cycle or immediately
                   if no cycle is active on the channel.

 CMD_FLUSH         Purge all write cycles and waitcycles (in-progress and
                   queued) for one or more channels.

 CMD_READ          Return a pointer to the I/O block currently writing on a
                   single channel.

 CMD_RESET         Reset one or more channels their initialized state.  All
                   active and queued requests will be aborted.

 CMD_START         Resume writes to one or more channels that were stopped.

 CMD_STOP          Stop any write cycle in progress on one or more
                                   channels.

 CMD_WRITE         Start a write cycle on a single channel.



Allocation and Arbitration Commands



This command gives your program a channel to use and should be the first
command you send to the audio device.  You specify the channels you want
by setting a pointer to an array in the ioa_Data field of the IOAudio
structure.  This array uses a value of 1 to allocate channel 0, 2 for
channel 1, 4 for channel 2, and 8 for channel 3. For multiple channels,
add the values together.  For example, if you want to allocate all
channels, use a value of 15.

If you want a pair of stereo channels and you have no preference about
which of the left and right channels the system will choose for the
allocation, you can pass a pointer to an array containing 3, 5, 10, and
12. Channels 1 and 2 produce sound on the left side and channels 0 and 3
on the right side. The table below shows how this array corresponds to all
the possible combinations of a right and a left channel.

                     POSSIBLE CHANNEL COMBINATIONS
                                                           Decimal
     Channel 3    Channel 2    Channel 1    Channel 0      Value of
      (right)       (left)      (left)       (right)    Allocation Mask
     ---------    ---------    ---------    ---------   ---------------
         0            0            1            1              3
         0            1            0            1              5
         1            0            1            0              10
         1            1            0            0              12
