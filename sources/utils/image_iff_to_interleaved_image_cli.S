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

    ; --- Step 3: Process ---
    move.l  SourcePtr(pc),a0
    bsr     Module_LoadIFF      

    ; --- Step 4: Allocate Destination ---
    move.l  WorkSize,d0
    move.l  #MEMF_PUBLIC!MEMF_CLEAR,d1
    CALLEXEC AllocMem
    move.l  d0,WorkPtr
    beq     .Cleanup
	
    ; --- Step 5: Extract raw ---
    move.l  SourcePtr(pc),a0
    bsr     Extract_Raw

    ; --- Step 6: Save ---
    move.l  out_file_ptr(pc),d1
    move.l  #MODE_NEWFILE,d2
    CALLDOS Open
    move.l  d0,file_handle
    beq     .Cleanup
	
    move.l  WorkPtr(pc),DestPtr
    move.l  WorkSize(pc),DestSize

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
usage_msg:    dc.b "Usage: iff_to_interleaved <FROM> <TO>",10
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
;    INCDIR  "SOURCES:"
;    INCLUDE "utils/image_iff_to_interleaved_image_core.S"
;---------------------------------------------------------------------------
; Main Routine
; input: A0 (Source)
;---------------------------------------------------------------------------
ImgWidth:    dc.w 0
ImgHeight:   dc.w 0
ImgDepth:    dc.b 0
Compression: dc.b 0

Module_LoadIFF:
    move.l  a0,a4
    bsr     FindBmhd        ; A0 points to BMHD data (after Size)
    
    bsr     GetImageSize    ; D0 = Total Buffer Size
    move.l  d0,WorkSize
	
    rts


;---------------------------------------------------------------------------
; Extract_Raw
;
; Inputs:
;   A0 = Source Address (Compressed IFF BODY data)
;
;---------------------------------------------------------------------------
Extract_Raw:
    bsr     FindBody        ; A0 points to actual BODY data
    
    move.l  WorkSize(pc),d0 ; Restore size to D0 for decompressor 
    
    tst.b  Compression      ; compression type (0=None, 1=ByteRun1)
    beq.s   .RawCopy        ; If 0, do a simple copy
    	
    move.l  WorkPtr(pc),a1
    bsr     DecompressILBM  ; Else, decompress
    rts	
	
.RawCopy:
    lsr.l   #2,d0           ; Divide size by 4 for longword copy
    subq.l  #1,d0           ; Adjust for DBRA
.CopyLoop:
    move.l  (a0)+,(a1)+     ; Copy 4 bytes at a time
    dbra    d0,.CopyLoop    ; Loop until done
    rts
;---------------------------------------------------------------------------
; FindBody
; Ensures we skip both the TAG (4 bytes) and SIZE (4 bytes).
; Modified registers:
; a0,d0,d1,d2
;---------------------------------------------------------------------------
FindBody:
    move.l  #'BODY',d0
    bsr     FindSection
    ; A0 now points to 'BODY' tag.
    ; We must skip 'BODY' (4) + Size (4) = 8 bytes.
    addq.l  #8,a0           
    rts

;---------------------------------------------------------------------------
; FindBmhd
; Ensures we skip both the TAG (4 bytes) and SIZE (4 bytes).
; a0,d0,d1,d2
;---------------------------------------------------------------------------
FindBmhd:
    move.l  #'BMHD',d0
    bsr     FindSection
    ; A0 points to 'BMHD'.
    ; We skip 'BMHD' (4) + Size (4) = 8 bytes    
    addq.l  #8,a0           
    rts

;---------------------------------------------------------------------------
; ByteRun1 Decompressor
;
; Inputs:
;   A0 = Source Address (Compressed IFF BODY data)
;   A1 = Destination Address (Where raw bitplanes will go)
;   D0 = Size of Destination Buffer in bytes (How much to decode)
;
; Registers Modified:
;   A0, A1, D0, D1, D2
;---------------------------------------------------------------------------
DecompressILBM:
    tst.l   d0              ; Safety check
    beq.s   .Done

.Loop:
    moveq   #0,d1           ; Clear D1
    move.b  (a0)+,d1        ; Read Command Byte
    
    tst.b   d1
    bmi.s   .RunEncoded     ; If negative, it's a Run or NOP

    ; --- LITERAL RUN (0 to 127) ---
    ; Copy next N+1 bytes
    sub.l   d1,d0
    subq.l  #1,d0
.LitCopy:
    move.b  (a0)+,(a1)+
    dbra    d1,.LitCopy
    bra.s   .CheckDone

.RunEncoded:
    ; --- REPLICATE RUN (-1 to -127) ---
    ; Explicitly check for NOP (-128 / $80)
    cmp.b   #$80,d1         ; Use Hex $80 to avoid assembler sign ambiguity
    beq.s   .CheckDone      ; If NOP, just check D0 and continue

    neg.b   d1              ; Negate (-x becomes x)
    
    ; Safety catch: If neg.b failed to handle -128 (rare cpu edge case),
    ; d1 would be 128 here. We ignore it or treat as 0.
    bmi.s   .CheckDone      

    sub.l   d1,d0
    subq.l  #1,d0

    move.b  (a0)+,d2        ; Read byte to replicate
.RepCopy:
    move.b  d2,(a1)+
    dbra    d1,.RepCopy

.CheckDone:
    tst.l   d0              ; Check remaining bytes
    bgt.s   .Loop

.Done:
    rts

;---------------------------------------------------------------------------
; FindSection
; Inputs:
;   A0 = Source Address (IFF data)
; Modified registers:
;   A0,D1,D2
;---------------------------------------------------------------------------
FindSection:
    move.l  4(a0),d1        ; File Size
    add.l   a0,d1           ; End Address
    addq.l  #8,a0           ; Skip FORM+Size
    addq.l  #4,a0           ; Skip ILBM
.Loop:
    cmp.l   (a0),d0         ; Check Tag
    beq.s   .Found
    move.l  4(a0),d2        ; Size
    addq.l  #1,d2
    and.b   #$FE,d2         ; Word Align
    addq.l  #8,a0           ; Skip Tag+Size
    add.l   d2,a0           ; Skip Data
    cmp.l   d1,a0
    blt.s   .Loop
    ; If not found, A0 is garbage/EOF. You might want to handle this!
.Found:
    rts

;---------------------------------------------------------------------------
; GetImageSize
; Inputs:
;   A0 = Source Address (points to BMHD data after size)
; Output
;   D0 = Total size
;---------------------------------------------------------------------------
GetImageSize:
    move.w  (a0),d0        ; Width
    move.w  d0,ImgWidth
    move.w  2(a0),d1        ; Height
    move.w  d1,ImgHeight
    moveq   #0,d2
    move.b  8(a0),d2       ; Depth
    move.w  d2,ImgDepth
    move.b  10(a0),Compression ; Compression

    add.w   #15,d0
    lsr.w   #4,d0
    lsl.w   #1,d0           ; RowBytes (Word Aligned)

    mulu.w  d1,d0           ; PlaneSize
    mulu.w  d2,d0           ; Total Size
    rts	

;--- BSS ---
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