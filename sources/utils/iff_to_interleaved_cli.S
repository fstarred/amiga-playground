;---------------------------------------------------------------------------
; IFF Interleaved Saver (CLI Wrapper)
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

    ; --- Step 3: Process ---
    move.l  SourcePtr(pc),a0
    bsr     Module_LoadIFF      

    ; --- Step 4: Allocate Destination ---
    move.l  ImgSize(pc),d0
    move.l  #MEMF_PUBLIC!MEMF_CLEAR,d1
    CALLEXEC AllocMem
    move.l  d0,WorkPtr
    beq     .NoMemError
	
    ; --- Step 5: Extract raw ---
    move.l  SourcePtr(pc),a0
    move.l  WorkPtr(pc),a1
    bsr     Extract_Raw

    ; --- Step 6: Save ---
    move.l  out_file_ptr(pc),d1
    move.l  #MODE_NEWFILE,d2
    CALLDOS Open
    move.l  d0,file_handle
    beq     .WriteError
	
    move.l  WorkPtr(pc),DestPtr
    move.l  ImgSize(pc),DestSize

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

;--- CLI Utility ---
ParseCommandLine:
    movem.l d0-d2/a2,-(sp)
    move.l  a0,a2
    move.l  d0,d2
.skip1:
    cmp.b   #' ',(a2)
    bne.s   .found1
    addq.l  #1,a2
    subq.l  #1,d2
    bne.s   .skip1
    bra     .ParseError
.found1:
    move.l  a2,in_file_ptr
.find_space:
    cmp.b   #' ',(a2)+
    beq.s   .found_space
    subq.l  #1,d2
    bne.s   .find_space
    bra     .ParseError
.found_space:
    clr.b   -1(a2)
.skip2:
    cmp.b   #' ',(a2)
    bne.s   .found2
    addq.l  #1,a2
    subq.l  #1,d2
    bne.s   .skip2
    bra     .ParseError
.found2:
    move.l  a2,out_file_ptr
.find_end:
    cmp.b   #10,(a2)
    beq.s   .terminate
    cmp.b   #13,(a2)
    beq.s   .terminate
    addq.l  #1,a2
    subq.l  #1,d2
    bne.s   .find_end
.terminate:
    clr.b   (a2)
    movem.l (sp)+,d0-d2/a2
    and.b   #%11111110,ccr
    rts
.ParseError:
    movem.l (sp)+,d0-d2/a2
    or.b    #%00000001,ccr
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
usage_msg:    dc.b "Usage: iff_to_interleaved <FROM> <TO>",10
usage_msg_end:
mem_err_msg:  dc.b "Error: Out of memory.",10
mem_err_msg_end:
io_err_msg:   dc.b "Error: I/O failure.",10
io_err_msg_end:    
file_err_msg: dc.b "Error: Source file not found.",10
file_err_msg_end:

    IF DEBUG
fakeArgs:
	dc.b "ball001002.iff output.raw",10,0
fakeArgsEnd=*-fakeArgs    
    ENDIF
	
    even

    ;--- Include Core Logic ---
    INCDIR  "SOURCES:"
    INCLUDE "utils/iff_to_interleaved_core.S"

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
