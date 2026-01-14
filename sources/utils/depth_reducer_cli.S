;---------------------------------------------------------------------------
; IFF Optimizer & Interleaved Saver (CLI Wrapper)
; Target: Amiga 68000
;---------------------------------------------------------------------------

	incdir "INCLUDE:"
	INCLUDE "exec/exec.i"
	INCLUDE "exec/exec_lib.i"
	INCLUDE "libraries/dos.i"
	INCLUDE "libraries/dos_lib.i"

;--- Amiga Library Offsets ---

DEBUG         EQU 1

Main:
    IF DEBUG
    lea     fakeArgs(pc),a0
    moveq   #fakeArgsEnd,d0
    ENDIF
	
    move.l  a0,a2               ; Save original arg pointer
    move.l  d0,d2               ; Save original length

    lea     dosname(pc),a1
    moveq   #0,d0
    CALLEXEC OldOpenLibrary                    ; OldOpenLibrary
    move.l  d0,_DOSBase                        ; WRITE: Absolute
    beq     .NoDos

    move.l  a2,a0
    move.l  d2,d0
    bsr     ParseCommandLine
    bcs     .UsageError
	
    ; --- Step 1: Check if file exists ---
    move.l  in_file_ptr(pc),d1
    move.l  #-2,d2              ; ACCESS_READ
    CALLDOS Lock
    move.l  d0,d1               ; BPTR Lock
    beq.w   .FileNotFound       ; If lock is 0, file doesn't exist
    
    move.l  d0,d1               ; BPTR Lock
    move.l  d1,-(sp)
    lea     MyFIB,a2
    move.l  a2,d2
    CALLDOS Examine
    
    move.l  (sp)+,d1
    move.l  d1,-(sp)
    
    move.l  MyFIB+124,d0        ; fib_Size
    move.l  d0,SourceSize
    
    move.l  #MEMF_PUBLIC,d1
    CALLEXEC AllocMem
    move.l  d0,SourcePtr
    
    move.l  (sp)+,d1
    CALLDOS UnLock
    
    move.l  SourcePtr(pc),a0
    cmpa.l  #0,a0
    beq     .Cleanup

    ; --- Step 2: Load Source File ---
    move.l  in_file_ptr(pc),d1
    move.l  #MODE_OLDFILE,d2
    CALLDOS Open
    move.l  d0,file_handle
    beq     .Cleanup

    move.l  file_handle(pc),d1
    move.l  SourcePtr(pc),d2
    move.l  SourceSize(pc),d3
    CALLDOS Read
    
    move.l  file_handle(pc),d1
    CALLDOS Close

    ; --- Step 3: Peek Dimensions & Allocate WorkBuffer ---
    move.l  SourcePtr(pc),a0
    lea     12(a0),a3
    move.w  8(a3),d1
    move.w  10(a3),d2
    move.w  d1,ImgWidth
    move.w  d2,ImgHeight
    
    mulu.w  d1,d2               ; Chunky size
    move.l  d2,WorkSize
    
    move.l  d2,d0
    move.l  #MEMF_PUBLIC!MEMF_CLEAR,d1
    CALLEXEC AllocMem
    move.l  d0,WorkPtr
    beq     .Cleanup

    ; --- Step 4: Process ---
    move.l  SourcePtr(pc),a0
    move.l  WorkPtr(pc),a1
    bsr     Module_LoadIFF      
    
    move.l  SourcePtr(pc),a0
    move.l  WorkPtr(pc),a1
    bsr     Module_AnalyzeColors 

    ; --- Step 5: Allocate Destination ---
    moveq   #0,d3
    move.w  ImgWidth(pc),d3
    lsr.w   #3,d3
    move.w  ImgHeight(pc),d0
    mulu.w  d0,d3
    move.w  NewDepth(pc),d0
    mulu.w  d0,d3
    move.l  d3,DestSize

    move.l  d3,d0
    move.l  #MEMF_PUBLIC!MEMF_CLEAR,d1
    CALLEXEC AllocMem
    move.l  d0,DestPtr
    beq     .Cleanup

    move.l  WorkPtr(pc),a1
    bsr     Module_RemapPixels
    
    move.l  WorkPtr(pc),a1
    move.l  DestPtr(pc),a2
    bsr     Module_SaveInterleaved

    ; --- Step 6: Save ---
    move.l  out_file_ptr(pc),d1
    move.l  #MODE_NEWFILE,d2
    CALLDOS Open
    move.l  d0,file_handle
    beq     .Cleanup

    move.l  file_handle(pc),d1
    move.l  DestPtr(pc),d2
    move.l  DestSize(pc),d3
    CALLDOS Write

    move.l  file_handle(pc),d1
    CALLDOS Close

.Cleanup:
    move.l  SourcePtr(pc),a1
    cmpa.l  #0,a1
    beq.s   .noSrc
    move.l  SourceSize(pc),d0
    CALLEXEC FreeMem
.noSrc:
    move.l  WorkPtr(pc),a1
    cmpa.l  #0,a1
    beq.s   .noWork
    move.l  WorkSize(pc),d0
    CALLEXEC FreeMem
.noWork:
    move.l  DestPtr(pc),a1
    cmpa.l  #0,a1
    beq.s   .noDest
    move.l  DestSize(pc),d0
    CALLEXEC FreeMem
.noDest:
    move.l  _DOSBase(pc),a1
    cmpa.l  #0,a1
    beq.s   .NoDos
    CALLEXEC CloseLibrary            ; CloseLibrary
.NoDos:
    rts
	
.FileNotFound:
    lea     file_err_msg(pc),a2
    move.l  #file_err_msg_end-file_err_msg,d3
    bra.s   .PrintCustomError

.UsageError:
    lea     usage_msg(pc),a2
    move.l  #usage_msg_end-usage_msg,d3

.PrintCustomError:
    CALLDOS Output              ; Get handle in D0
    tst.l   d0                  ; Is there a valid CLI window?
    beq.w   .Cleanup            ; If 0, we can't print, just exit
    
    move.l  d0,d1               ; D1 = Output Handle
    move.l  a2,d2               ; D2 = Buffer
    ; D3 already contains length
    CALLDOS Write
    bra.w   .Cleanup

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
WorkSize:     dc.l 0
DestPtr:      dc.l 0
DestSize:     dc.l 0
dosname:      DOSNAME
usage_msg:    dc.b "Usage: depth_reducer FROM TO",10
usage_msg_end:
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
    INCLUDE "utils/depth_reducer_core.S"

;--- BSS ---
    SECTION DATABSS, BSS_C
    
	even
MyFIB:         ds.b 260
    even
    END
