;---------------------------------------------------------------------------
; Interleaved to mask (IntMask) (CLI Wrapper)
; Target: Amiga 68000
;---------------------------------------------------------------------------

	incdir "INCLUDE:"
	INCLUDE "exec/exec.i"
	INCLUDE "exec/exec_lib.i"
	INCLUDE "libraries/dos.i"
	INCLUDE "libraries/dos_lib.i"

; set DEBUG to 0 before writing executable
DEBUG         EQU 1

Main:
    movem.l d1-d7/a0-a6,-(sp)
    moveq   #0,d7      
    IF DEBUG
    lea     fakeArgs(pc),a0
    moveq   #fakeArgsEnd,d0
    ENDIF
	
    move.l  a0,a2               ; Save original arg pointer
    move.l  d0,d2               ; Save original length

    lea     dosname(pc),a1
    moveq   #0,d0
    CALLEXEC OldOpenLibrary     ; OldOpenLibrary
    move.l  d0,_DOSBase         ; WRITE: Absolute
    beq     .NoDos

    move.l  a2,a0
    move.l  d2,d0
    bsr     ParseCommandLine
    bcs     .UsageError
	
    ; --- Step 1: Check if file exists ---
    move.l  in_file_ptr(pc),d1
    move.l  #ACCESS_READ,d2              ; ACCESS_READ
    CALLDOS Lock
    move.l  d0,d1               ; BPTR Lock
    beq.w   .FileNotFound       ; If lock is 0, file doesn't exist
    
    move.l  d0,-(sp)            ; Save Lock
    lea     MyFIB,a2
    move.l  a2,d2
    CALLDOS Examine
    
    move.l  (sp),d1             ; Restore Lock for UnLock later
    move.l  MyFIB+124,d0        ; fib_Size
    move.l  d0,SourceSize
    
    move.l  #MEMF_PUBLIC,d1
    CALLEXEC AllocMem
    move.l  d0,SourcePtr
    
    move.l  (sp)+,d1            ; Pop Lock from stack
    CALLDOS UnLock
    
    tst.l   SourcePtr           ; CHECK: Did AllocMem fail?
    beq.w   .NoMemError

    ; --- Step 2: Load Source File ---
    move.l  in_file_ptr(pc),d1
    move.l  #MODE_OLDFILE,d2
    CALLDOS Open
    move.l  d0,file_handle
    beq     .ReadError

    move.l  file_handle(pc),d1
    move.l  SourcePtr(pc),d2
    move.l  SourceSize(pc),d3
    CALLDOS Read
    
    move.l  file_handle(pc),d1
    CALLDOS Close

    ; --- Step 4: Allocate Destination ---
    move.l  SourceSize(pc),d0
    move.l  #MEMF_PUBLIC!MEMF_CLEAR,d1
    CALLEXEC AllocMem
    move.l  d0,WorkPtr
    beq     .NoMemError
	
    ; --- Step 5: Extract raw ---
    move.l  SourcePtr(pc),a0
    move.l  WorkPtr(pc),a1
    move.w  Width(pc),d0
    move.w  Height(pc),d1
    move.w  Depth(pc),d2
    bsr     CreateInterleavedMask

    ; --- Step 6: Save ---
    move.l  out_file_ptr(pc),d1
    move.l  #MODE_NEWFILE,d2
    CALLDOS Open
    move.l  d0,file_handle
    beq     .WriteError
	
    move.l  WorkPtr(pc),DestPtr
    move.l  SourceSize(pc),DestSize

    move.l  file_handle(pc),d1
    move.l  DestPtr(pc),d2
    move.l  DestSize(pc),d3
    CALLDOS Write

    move.l  file_handle(pc),d1
    CALLDOS Close
    bra.s   .Cleanup            ; Success! D7 is still 0.

; --- Error Handlers ---

.UsageError:
    lea     usage_msg(pc),a2
    move.l  #usage_msg_end-usage_msg,d3
    moveq   #10,d7              ; RETURN_ERROR
    bra.s   .PrintCustomError

.FileNotFound:
    lea     file_err_msg(pc),a2
    move.l  #file_err_msg_end-file_err_msg,d3
    moveq   #5,d7               ; RETURN_WARN
    bra.s   .PrintCustomError

.NoMemError:
    lea     mem_err_msg(pc),a2
    move.l  #mem_err_msg_end-mem_err_msg,d3
    moveq   #20,d7              ; RETURN_FAIL
    bra.s   .PrintCustomError

.ReadError:
.WriteError:
    lea     io_err_msg(pc),a2
    move.l  #io_err_msg_end-io_err_msg,d3
    moveq   #20,d7              ; RETURN_FAIL

.PrintCustomError:
    CALLDOS Output      ; identify program's initial output file handle        
    tst.l   d0                  
    beq.s   .Cleanup   	; check if the program was launched from console 
    move.l  d0,d1       ; set Window Handle
    move.l  a2,d2       ; point to text string
    CALLDOS Write	; write bytes of data to a file

.Cleanup:
    move.l  SourcePtr(pc),a1
    cmpa.l  #0,a1
    beq.s   .noSrc
    move.l  SourceSize(pc),d0
    CALLEXEC FreeMem
.noSrc:
    move.l  WorkPtr(pc),a1
    cmpa.l  #0,a1
    beq.s   .noDest
    move.l  DestSize(pc),d0
    CALLEXEC FreeMem
.noDest:
    move.l  _DOSBase(pc),a1
    cmpa.l  #0,a1
    beq.s   .Exit
    CALLEXEC CloseLibrary            
.Exit:
    move.l  d7,d0               ; Final Return Code into D0
    movem.l (sp)+,d1-d7/a0-a6
    rts

.NoDos:
    moveq   #20,d0              ; Can't even open DOS
    rts

; Returns: Carry Clear = Success, Carry Set = Error
ParseCommandLine:
    movem.l d0-d7/a0-a3,-(sp)
    move.l  a0,a2
    move.l  d0,d2
    moveq   #0,d3

    ; --- Arg 1: Input File ---
    bsr.s   .SkipSpaces
    tst.l   d2
    beq.s   .CheckCount
    move.l  a2,in_file_ptr
    addq.w  #1,d3
    bsr.s   .FindSpaceOrEnd
    
    ; --- Arg 2: Output File ---
    bsr.s   .SkipSpaces
    tst.l   d2
    beq.s   .CheckCount
    move.l  a2,out_file_ptr
    addq.w  #1,d3
    bsr.s   .FindSpaceOrEnd

    ; --- Arg 3: Width ---
    bsr.s   .SkipSpaces
    tst.l   d2
    beq.s   .CheckCount
    move.l  a2,a0
    bsr.s   AsciiToInt
    move.w  d1,Width
    addq.w  #1,d3
    bsr.s   .FindSpaceOrEnd

    ; --- Arg 4: Height ---
    bsr.s   .SkipSpaces
    tst.l   d2
    beq.s   .CheckCount
    move.l  a2,a0
    bsr.s   AsciiToInt
    move.w  d1,Height
    addq.w  #1,d3
    bsr.s   .FindSpaceOrEnd

    ; --- Arg 5: Depth ---
    bsr.s   .SkipSpaces
    tst.l   d2
    beq.s   .CheckCount
    move.l  a2,a0
    bsr.s   AsciiToInt
    move.w  d1,Depth
    addq.w  #1,d3

.CheckCount:
    cmp.w   #5,d3       ; Did we find exactly 5 arguments?
    beq.s   .Success
    
    ; If we fall through, it's an error
    movem.l (sp)+,d0-d7/a0-a3
    or.b    #%00000001,ccr  ; Set Carry (Fail)
    rts

.Success:
    movem.l (sp)+,d0-d7/a0-a3
    and.b   #%11111110,ccr  ; Clear Carry (Success)
    rts

; --- Subroutines for Parsing ---

.SkipSpaces:
    tst.l   d2
    beq.s   .doneSkip       ; Just return if empty, parent handles d3 count
    cmp.b   #' ',(a2)
    bne.s   .doneSkip
    addq.l  #1,a2
    subq.l  #1,d2
    bra.s   .SkipSpaces
.doneSkip:
    rts

.FindSpaceOrEnd:
    tst.l   d2
    beq.s   .doneFind
    cmp.b   #' ',(a2)
    beq.s   .foundBreak
    cmp.b   #10,(a2)
    beq.s   .foundBreak
    cmp.b   #13,(a2)
    beq.s   .foundBreak
    addq.l  #1,a2
    subq.l  #1,d2
    bra.s   .FindSpaceOrEnd
.foundBreak:
    clr.b   (a2)+       ; Null terminate
    subq.l  #1,d2
.doneFind:
    rts
	
; Input: a0 = pointer to null-terminated string
; Output: d1 = resulting integer
AsciiToInt:
    movem.l d0/d2/a0,-(sp)
    moveq   #0,d1           ; Clear result
.loop:
    moveq   #0,d0
    move.b  (a0)+,d0        ; Get character
    beq.s   .done           ; If null, we are done
    sub.b   #'0',d0         ; Convert ASCII to digit
    blt.s   .done           ; Safety check: less than '0'?
    cmp.b   #9,d0           ; Safety check: greater than '9'?
    bgt.s   .done
    
    mulu.w  #10,d1          ; Result = Result * 10
    add.l   d0,d1           ; Result = Result + Digit
    bra.s   .loop
.done:
    movem.l (sp)+,d0/d2/a0
    rts	

;--- Variables ---
in_file_ptr:  dc.l 0
out_file_ptr: dc.l 0
_DOSBase:     dc.l 0
file_handle:  dc.l 0
SourcePtr:    dc.l 0
SourceSize:   dc.l 0
WorkPtr:      dc.l 0
DestPtr:      dc.l 0
DestSize:     dc.l 0
dosname:      DOSNAME
usage_msg:    dc.b "Usage: interleaved_to_mask <FROM> <TO> <WIDTH> <HEIGHT> <DEPTH>",10
usage_msg_end:
mem_err_msg:  dc.b "Error: Out of memory.",10
mem_err_msg_end:
io_err_msg:   dc.b "Error: I/O failure.",10
io_err_msg_end:    
file_err_msg: dc.b "Error: Source file not found.",10
file_err_msg_end:
    even
Width:        dc.w 0
Height:       dc.w 0
Depth:        dc.w 0

    IF DEBUG
fakeArgs:
	dc.b "ball001002_crop.raw ball001002_mask.raw 128 128 5",10,0
fakeArgsEnd=*-fakeArgs    
    ENDIF 
	
    even

    ;--- Include Core Logic ---
    INCDIR  "SOURCES:"
    INCLUDE "utils/image_interleaved_to_mask_core.S"


    SECTION DATABSS, BSS_C
    
    even
MyFIB:         ds.b 260
    even

    END
	

struct FileInfoBlock {
	LONG fib_DiskKey;
	LONG fib_DirEntryType;
	char fib_FileName[108];
	LONG fib_Protection;
	LONG fib_EntryType;
	LONG fib_Size;
	LONG fib_NumBlocks;
	struct DateStamp fib_Date;
	char fib_Comment[80];
	UWORD fib_OwnerUID;
	UWORD fib_OwnerGID;
	char fib_Reserved[32];
};

struct DateStamp {
	LONG ds_Days;
	LONG ds_Minute;
	LONG ds_Tick;
};
	
