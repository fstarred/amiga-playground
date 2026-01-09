;---------------------------------------------------------------------------
; IFF Optimizer & Interleaved Saver (Modular)
; Target: Amiga 68000
;---------------------------------------------------------------------------

;--- Amiga DOS Library Offsets ---
_LVOOpen      EQU -30
_LVOClose     EQU -36
_LVORead      EQU -42
_LVOWrite     EQU -48
_LVOOutput    EQU -60
_LVOReadArgs  EQU -158
_LVOFreeArgs  EQU -164

Main:
;    lea     fakeArgs(pc),a0
;    moveq   #fakeArgsEnd,d0

    ; --- Kickstart 1.3 Argument Parsing ---
    ; On startup: A0 = ptr to argument string, D0 = length
    tst.l   d0                  ; Any arguments?
    beq     .UsageError
    
    move.l  a0,a2               ; A2 = Arg String
    move.l  d0,d2               ; D2 = Arg Length

    move.l  4.w,a6
    lea     dosname(pc),a1
    moveq   #0,d0               ; Any version
    jsr     -408(a6)            ; OldOpenLibrary
    move.l  d0,dosbase
    beq     .NoDos	

    ; 1. Find the start of the first argument (skip leading spaces)
.skip1:
    cmp.b   #' ',(a2)
    bne.s   .found1
    addq.l  #1,a2
    subq.l  #1,d2
    bne.s   .skip1
    bra     .UsageError
.found1:
    move.l  a2,in_file_ptr      ; Save pointer to "FROM" filename

    ; 2. Find the space between arguments
.find_space:
    cmp.b   #' ',(a2)+
    beq.s   .found_space
    subq.l  #1,d2
    bne.s   .find_space
    bra     .UsageError          ; Only one argument found!
.found_space:
    clr.b   -1(a2)              ; NULL terminate the first filename string

    ; 3. Skip spaces until the second argument
.skip2:
    cmp.b   #' ',(a2)
    bne.s   .found2
    addq.l  #1,a2
    subq.l  #1,d2
    bne.s   .skip2
    bra     .UsageError
.found2:
    move.l  a2,out_file_ptr     ; Save pointer to "TO" filename

    ; 4. Find end of second argument and NULL terminate
.find_end:
    cmp.b   #10,(a2)            ; Check for NewLine (LineFeed)
    beq.s   .terminate
    cmp.b   #13,(a2)            ; Check for Carriage Return
    beq.s   .terminate
    addq.l  #1,a2
    subq.l  #1,d2
    bne.s   .find_end
.terminate:
    clr.b   (a2)                ; NULL terminate the second filename

    ; --- Arguments are now in in_file_ptr and out_file_ptr ---
    
   ; --- Step 2: Load Source File ---
    move.l  dosbase(pc),a6      ; Ensure A6 is DOSBase
    move.l  in_file_ptr(pc),d1  ; <--- Use the pointer from the parser!
    move.l  #1005,d2            ; MODE_OLDFILE
    jsr     _LVOOpen(a6)
    move.l  d0,file_handle
    beq     .Close

    ; Read file into SourceBuffer
    move.l  file_handle(pc),d1
    move.l  #SourceBuffer,d2
    move.l  #150000,d3          ; Max size to read
    jsr     _LVORead(a6)
    
    move.l  file_handle(pc),d1
    jsr     _LVOClose(a6)

    ; --- Step 3: Run Your Modular Logic ---
    lea     SourceBuffer,a0     ; Point A0 to the loaded file
    lea     WorkBuffer,a1
    bsr     Module_LoadIFF      
    
    lea     SourceBuffer,a0
    lea     WorkBuffer,a1
    bsr     Module_AnalyzeColors 
    
    lea     WorkBuffer,a1
    bsr     Module_RemapPixels
    
    lea     WorkBuffer,a1   
    lea     DestBuffer,a2   
    bsr     Module_SaveInterleaved

    ; --- Step 4: Save Output File ---
    move.l  dosbase(pc),a6      ; Ensure A6 is DOSBase
    move.l  out_file_ptr(pc),d1 ; <--- Use the pointer from the parser!
    move.l  #1006,d2            ; MODE_NEWFILE
    jsr     _LVOOpen(a6)    
    move.l  d0,file_handle
    beq     .Close

    ; Calculate Save Size: (Width/8) * Height * NewDepth
    moveq   #0,d3
    move.w  ImgWidth(pc),d3
    lsr.w   #3,d3               ; Width in bytes
    move.w  ImgHeight(pc),d0
    mulu.w  d0,d3               ; Size of 1 plane
    move.w  NewDepth(pc),d0
    mulu.w  d0,d3               ; Total size for all planes

    move.l  file_handle(pc),d1
    move.l  #DestBuffer,d2
    jsr     _LVOWrite(a6)

    move.l  file_handle(pc),d1
    jsr     _LVOClose(a6)

.Close:
    move.l  dosbase(pc),a6
    move.l  arg_result(pc),d1

.ArgsError:
    move.l  4.w,a6
    move.l  dosbase(pc),a1
    jsr     -414(a6)            ; CloseLibrary

.NoDos:
    moveq   #0,d0
    rts

; --- Logic for Printing Usage ---
.UsageError:
    move.l  dosbase(pc),a6
    jsr     _LVOOutput(a6)      ; Get current CLI window handle in D0
    move.l  d0,d1               ; D1 = Output Handle
    beq.s   .NoDos              ; Safety check

    lea     usage_msg(pc),a2
    move.l  a2,d2               ; D2 = Pointer to string
    moveq   #0,d3
    move.b  (a2)+,d3            ; Read the first byte (length)
    ; Note: Alternatively, use a fixed length:
    move.l  #usage_msg_end-usage_msg,d3 
    
    jsr     _LVOWrite(a6)       ; Print it!
    bra.s   .Close              ; Exit gracefully

;===========================================================================
; MODULE 1: Load IFF -> Chunky
; Decodes bitplanes and converts immediately to 1-byte-per-pixel.
;===========================================================================
Module_LoadIFF:
    movem.l d3-d7/a2-a6,-(sp)

    ; 1. Parse Header
    lea     12(a0),a3           ; Skip FORM, Size, ILBM
    cmp.l   #'BMHD',(a3)
    bne     .Error
    
    move.w  8(a3),d1            ; Width
    move.w  10(a3),d2           ; Height
    move.b  16(a3),d3           ; Depth
    ext.w   d3
    move.b  18(a3),d4           ; Compression (0=None, 1=ByteRun1)
    
    ; Save Dims for other modules
    move.w  d1,ImgWidth
    move.w  d2,ImgHeight

    ; 2. Find BODY
    move.l  a0,a4
    bsr     Helper_FindBody     ; Returns A4 at BODY Data
    move.l  a4,a0
	
    ; 3. Decode Loop
    ; We decode one row of bitplanes, then convert to pixels line-by-line.
    move.l  a1,a6               ; A6 = Chunky Dest
    move.w  d2,d7               ; Height
    subq.w  #1,d7

    ; Calculate RowBytes (D5)
    move.l  d1,d5
    add.l   #15,d5
    lsr.l   #4,d5
    lsl.l   #1,d5               ; D5 = RowBytes

.LineLoop:
    ; Decode this line's bitplanes to Stack Buffer
;    bsr     Helper_DecodeRowToStack
    bsr     Helper_DecodeAndConvertLine
    ; (Returns Buffer at A2, Size in D0)

    dbra    d7,.LineLoop

.Error:
    movem.l (sp)+,d3-d7/a2-a6
    rts

Helper_DecodeAndConvertLine:
    movem.l d0-d7/a2-a5,-(sp)

    lea     RowTempBuffer(pc),a2 ; Static buffer for one plane row
    move.l  a6,a1               ; A6 is our current Chunky Dest (from Module_LoadIFF)

    ; --- 1. Clear the Chunky Line first ---
    move.w  ImgWidth(pc),d0
    lsr.w   #2,d0               ; Width in bytes for clearing
    subq.w  #1,d0
    move.l  a1,a3
.Clear:
    clr.l   (a3)+               ; Clear 4 pixels at a time (if width allows)
    dbra    d0,.Clear

    ; --- 2. Process each plane (Additive Merge) ---
    moveq   #0,d2               ; Current Plane Index
    move.w  d3,d7               ; Total Depth (from BMHD)
    subq.w  #1,d7

.PlaneLoop:
    move.l  d5,d0               ; RowBytes
    move.l  a2,a5               ; Dest = RowTempBuffer
    bsr     Helper_DecompressRaw ; Decompress current plane row

    ; Merge this plane (D2) into the Chunky Pixels (A1)
    move.l  a2,a3               ; Source = RowTempBuffer
    move.l  a1,a4               ; Dest = Chunky Line
    move.w  ImgWidth(pc),d4     ; Pixels to process
    
    moveq   #1,d6
    lsl.b   d2,d6               ; D6 = Bit value (1, 2, 4, 8, etc.)

.PixelLoop:
    move.b  (a3)+,d0            ; Get 8 bits from planar buffer
    moveq   #7,d1               ; Bit counter
.BitLoop:
    add.b   d0,d0               ; Shift MSB into Carry
    bcc.s   .NoBit
    or.b    d6,(a4)             ; Add bit value to chunky pixel
.NoBit:
    addq.l  #1,a4               ; Next chunky pixel
    subq.w  #1,d4
    beq.s   .NextPlane          ; Done with this line?
    dbra    d1,.BitLoop
    bra.s   .PixelLoop

.NextPlane:
    addq.w  #1,d2
    dbra    d7,.PlaneLoop

    movem.l (sp)+,d0-d7/a2-a5
    add.w   ImgWidth(pc),a6     ; Advance Chunky Pointer to next line
    rts

;===========================================================================
; MODULE 2: Analyze Colors (Merge Redundant)
; 1. Reads CMAP.
; 2. Merges duplicate RGBs.
; 3. Calculates Minimal Depth.
;===========================================================================
Module_AnalyzeColors:
    movem.l d2-d7/a2-a6,-(sp)

    ; 1. Load Palette from CMAP
    lea     SourceBuffer,a0
    move.l  a0,a4
    bsr     Helper_FindCMAP     ; A0 points to CMAP Data
    lea     Palette(pc),a2
    move.l  a4,a0
    move.w  #31,d0
.CopyPal:
    move.b  (a0)+,(a2)+         ; R
    move.b  (a0)+,(a2)+         ; G
    move.b  (a0)+,(a2)+         ; B
    dbra    d0,.CopyPal

    ; 2. Build Histogram (Usage Count)
    lea     Histogram(pc),a2
    ; Clear Hist
    moveq   #31,d0
.ClrH:
    clr.w   (a2)+
    dbra    d0,.ClrH

    lea     Histogram(pc),a2    ; ... (Clear Histogram code) ...
    move.l  a1,a0               ; Chunky Data
    moveq   #0,d0
    move.w  ImgWidth(pc),d0
    move.w  ImgHeight(pc),d1
    mulu    d1,d0               ; D0 = Total Pixels (Use .L for 32-bit result)
    
.HistLoop:
    moveq   #0,d1
    move.b  (a0)+,d1
    add.w   d1,d1               ; Word offset
    addq.w  #1,(a2,d1.w)
    subq.l  #1,d0               ; SUBQ.L handles values > 65535
    bne.s   .HistLoop           ; BNE works with the 32-bit result

    ; 3. Build Remap Table
    lea     RemapTable(pc),a3
    lea     Palette(pc),a4
    lea     Histogram(pc),a2
    
    moveq   #0,d6               ; D6 = New Index Counter (0, 1, 2...)
    moveq   #0,d0               ; D0 = Old Index (0..31)

.MapLoop:
    ; Check if color D0 is Used
    move.w  d0,d1
    add.w   d1,d1
    tst.w   (a2,d1.w)
    beq     .Unused

    ; Color D0 is USED. Check if it's a DUPLICATE of a previous mapped color.
    ; Compare RGB of D0 with RGB of (0..D0-1)
    move.w  d0,d2               ; D2 = Inner Loop (Previous colors)
    subq.w  #1,d2
    bmi.s   .Unique             ; If D0=0, it's unique

.CheckDup:
    ; Is D2 used?
    move.w  d2,d3
    add.w   d3,d3
    tst.w   (a2,d3.w)
    beq.s   .NextDup            ; If prev color unused, can't be a dup of it

    ; Compare RGB(D0) vs RGB(D2)
    ; RGBs are 3 bytes each in Palette buffer (A4)
    move.w  d0,d4
    mulu    #3,d4               ; Offset D0
    move.w  d2,d5
    mulu    #3,d5               ; Offset D2
    
    ; Compare R
    move.b  0(a4,d4.w),d7
    cmp.b   0(a4,d5.w),d7
    bne.s   .NextDup
    ; Compare G
    move.b  1(a4,d4.w),d7
    cmp.b   1(a4,d5.w),d7
    bne.s   .NextDup
    ; Compare B
    move.b  2(a4,d4.w),d7
    cmp.b   2(a4,d5.w),d7
    bne.s   .NextDup

    ; MATCH FOUND! Color D0 is a duplicate of D2.
    ; Map D0 -> RemapTable[D2]
    move.b  0(a3,d2.w),d7       ; Get target of D2
    move.b  d7,0(a3,d0.w)       ; Map D0 to same
    bra.s   .DoneCol

.NextDup:
    dbra    d2,.CheckDup

.Unique:
    ; No duplicate found. Assign new index D6.
    move.b  d6,0(a3,d0.w)
    addq.w  #1,d6               ; Use next slot
    bra.s   .DoneCol

.Unused:
    move.b  #0,0(a3,d0.w)       ; Map unused to 0

.DoneCol:
    addq.w  #1,d0
    cmp.w   #32,d0
    blt     .MapLoop

    ; 4. Calculate New Depth based on D6 (Total Unique Colors)
    moveq   #1,d0
    cmp.w   #2,d6
    ble.s   .SetD
    moveq   #2,d0
    cmp.w   #4,d6
    ble.s   .SetD
    moveq   #3,d0
    cmp.w   #8,d6
    ble.s   .SetD
    moveq   #4,d0
    cmp.w   #16,d6
    ble.s   .SetD
    moveq   #5,d0
.SetD:
    move.w  d0,NewDepth
    movem.l (sp)+,d2-d7/a2-a6
    rts

;===========================================================================
; MODULE 3: Remap Pixels
; Applies the RemapTable to the Chunky Buffer
;===========================================================================
Module_RemapPixels:
    movem.l d0-d1/a0-a3,-(sp)
    lea     RemapTable(pc),a3
    move.l  a1,a0               
    moveq   #0,d0
    move.w  ImgWidth(pc),d0
    move.w  ImgHeight(pc),d1
    mulu    d1,d0               ; D0 = Total Pixels (32-bit)
    
.ReLoop:
    moveq   #0,d1
    move.b  (a0),d1             
    move.b  0(a3,d1.w),d1       
    move.b  d1,(a0)+            
    subq.l  #1,d0               ; Use Long-word subtract
    bne.s   .ReLoop             ; Continue until D0 is 0
    movem.l (sp)+,d0-d1/a0-a3
    rts

;===========================================================================
; MODULE 4: Save as Interleaved
; Converts Chunky -> Interleaved Bitplanes (Depth D5)
;===========================================================================
;===========================================================================
; MODULE 4: Save as Interleaved
; Converts Chunky -> Interleaved Bitplanes (Depth from NewDepth)
;===========================================================================
Module_SaveInterleaved:
    movem.l d0-d7/a0-a6,-(sp)   ; Save all registers to stack 
    
    move.w  NewDepth(pc),d5     ; Total Bitplanes to create 
    move.w  ImgWidth(pc),d0     ; Screen Width (e.g., 320) 
    move.w  ImgHeight(pc),d1    ; Screen Height (e.g., 256) 
    
    ; A1 = Source (Chunky WorkBuffer)
    ; A2 = Destination (DestBuffer)

    subq.w  #1,d1               ; Adjust Height for DBRA 
.LineL:
    moveq   #0,d2               ; Current Plane Counter (0 to D5-1)
.PlaneL:
    move.l  a1,a3               ; Reset Chunky Source to Start of current line 
    
    move.w  d0,d3               ; Width in pixels
    lsr.w   #4,d3               ; Divide by 16 to get Words per line
    subq.w  #1,d3               ; Adjust for DBRA
.WordL:
    moveq   #0,d4               ; Clear Word Accumulator 
    moveq   #15,d6              ; 16 Bits per word
.BitL:
    move.b  (a3)+,d7            ; Read chunky pixel (0-31) 
    btst    d2,d7               ; Is bit 'd2' set in this pixel? 
    beq.s   .NoB
    bset    d6,d4               ; Set corresponding bit in the output word 
.NoB:
    dbra    d6,.BitL            ; Process next bit
    
    move.w  d4,(a2)+            ; Write finished word to DestBuffer 
    dbra    d3,.WordL           ; Process next word in this plane

    addq.w  #1,d2               ; Move to next Bitplane
    cmp.w   d5,d2               ; All planes done for this line?
    blt.s   .PlaneL             ; If not, restart line for next plane

    add.w   d0,a1               ; Move A1 to the start of the NEXT chunky line 
    dbra    d1,.LineL           ; Process next line of the image

    movem.l (sp)+,d0-d7/a0-a6   ; Restore all registers correctly 
    rts                         ; Return to Main

;===========================================================================
; HELPERS [FIXED]
;===========================================================================

;---------------------------------------------------------------------------
; Helper_FindBody
; Finds the BODY chunk and returns A4 pointing to its DATA.
;---------------------------------------------------------------------------
Helper_FindBody:
    move.l  #'BODY',d0      ; Set Tag
    bra.s   Helper_FindChunk

;---------------------------------------------------------------------------
; Helper_FindCMAP
; Finds the CMAP chunk and returns A4 pointing to its DATA.
;---------------------------------------------------------------------------
Helper_FindCMAP:
    move.l  #'CMAP',d0      ; Set Tag
    ; Fall through to Helper_FindChunk...

;---------------------------------------------------------------------------
; Helper_FindChunk (Generic)
; Inputs: 
;   A4 (or A0) = Start of File
;   D0 = Chunk Tag (e.g. 'CMAP')
; Returns: 
;   A4 = Points to Chunk DATA (after the Size longword)
;   D0 = 1 if Found, 0 if Not Found
;---------------------------------------------------------------------------
Helper_FindChunk:
    movem.l d1-d2/a0,-(sp)
    
    ; Set A0 to File Start. 
    ; NOTE: The caller usually puts file pointer in A4 or A0. 
    ; Let's assume A4 is the File Start based on your main code.
    move.l  a4,a0           

    ; Calculate End of File
    move.l  4(a0),d1        ; File Size (from FORM header)
    add.l   a0,d1           ; End Address
    
    ; Skip FORM Header (12 bytes: 'FORM', Size, 'ILBM')
    add.w   #12,a0          

.ScanLoop:
    cmp.l   a0,d1           ; Have we reached end of file?
    ble.s   .NotFound
    
    cmp.l   (a0),d0         ; Check Tag
    beq.s   .Found
    
    ; Skip this chunk
    move.l  4(a0),d2        ; Get Chunk Size
    addq.l  #1,d2           ; Round up...
    andi.l  #$FFFFFFFE,d2   ; ...to even byte boundary
    addq.l  #8,a0           ; Skip Tag + Size fields
    add.l   d2,a0           ; Jump to next chunk
    bra.s   .ScanLoop

.Found:
    addq.l  #8,a0           ; Skip Tag + Size to get to Data
    move.l  a0,a4           ; Return Data pointer in A4
    moveq   #1,d0           ; Success Flag
    bra.s   .Exit

.NotFound:
    moveq   #0,d0           ; Failure Flag

.Exit:
    movem.l (sp)+,d1-d2/a0
    rts

Helper_DecodeRowToStack:
    ; We no longer move SP. We use a static buffer instead.
    ; Returns A2 = Pointer to the buffer
    ; D0 = Size of the row (for your loop logic compatibility)
    
    lea     RowTempBuffer,a2    ; Point to our safe buffer
    
    ; Calculate RowBytes for the decompressor
    move.l  d5,d0               
    addq.l  #1,d0
    andi.l  #$FFFFFFFE,d0       ; D0 = Even RowBytes
    
    ; Decompress D3 (Depth) planes into the buffer
    movem.l d0/d6/a5,-(sp)      ; Save registers we are about to use
    move.w  d3,d6               ; Depth
    subq.w  #1,d6
    move.l  a2,a5               ; Temp cursor for decompressor
.PlaneD:
    move.l  d5,d0               ; RowBytes to decompress
    bsr     Helper_DecompressRaw 
    dbra    d6,.PlaneD
    movem.l (sp)+,d0/d6/a5      ; Restore registers
    
    rts                         ; This will now always work!

;---------------------------------------------------------------------------
; Helper: Helper_DecompressRaw
;
; Purpose: Decompresses a specific number of bytes (one plane row) 
;          using the ByteRun1 (RLE) algorithm.
;
; Inputs:
;   A0 = Source compressed stream (Advanced as bytes are read)
;   A5 = Destination buffer (Advanced as bytes are written)
;   D0 = Number of DECOMPRESSED bytes expected (e.g., RowBytes)
;
; Registers preserved: D1-D2
;---------------------------------------------------------------------------
Helper_DecompressRaw:
    movem.l d1-d2,-(sp)         ; Save working registers

.DecLoop:
    tst.l   d0                  ; Check if we have more bytes to fill
    ble.s   .DecDone            ; If 0 or less, we are finished

    moveq   #0,d1
    move.b  (a0)+,d1            ; Read the Opcode/Command byte
    
    ; --- Decision: Literal vs Repeat ---
    tst.b   d1
    bmi.s   .RunEncoded         ; If negative (bit 7 set), it's a Repeat run

    ; --- LITERAL RUN (0 to 127) ---
    ; Copy the next N+1 bytes directly from the source.
    ext.w   d1                  ; Ensure D1 is a clean word for DBRA
    sub.l   d1,d0               ; Update total remaining bytes count
    subq.l  #1,d0               ; (D0 = D0 - (D1 + 1))
    
.LitCopy:
    move.b  (a0)+,(a5)+         ; Copy byte from Source to Dest
    dbra    d1,.LitCopy         ; Repeat N+1 times
    bra.s   .DecLoop

.RunEncoded:
    ; --- REPLICATE RUN (-1 to -127) ---
    ; Repeat the next single byte -N+1 times.
    cmp.b   #$80,d1             ; Check for NOP (-128)
    beq.s   .DecLoop            ; If -128, ignore and get next opcode

    neg.b   d1                  ; Turn negative N into positive N (1-127)
    ext.w   d1                  ; Prepare for DBRA
    sub.l   d1,d0               ; Update total remaining bytes count
    subq.l  #1,d0               ; (D0 = D0 - (D1 + 1))
    
    move.b  (a0)+,d2            ; Read the single byte to be repeated
.RepCopy:
    move.b  d2,(a5)+            ; Write the byte to destination
    dbra    d1,.RepCopy         ; Repeat N+1 times
    bra.s   .DecLoop

.DecDone:
    movem.l (sp)+,d1-d2         ; Restore registers
    rts

; DATA
in_file_ptr:  dc.l 0
out_file_ptr: dc.l 0

dosname:      dc.b "dos.library",0
arg_template: dc.b "FROM/A,TO/A",0  ; FROM and TO are required [/A]
    even
usage_msg:    dc.b "Usage: depth_reducer FROM TO",10
usage_msg_end:
    even	
ImgWidth:   dc.w 0
ImgHeight:  dc.w 0
NewDepth:   dc.w 0
Palette:    ds.b 32*3       ; RGB Store
Histogram:  ds.w 32         ; Usage
RemapTable: ds.b 32
RowTempBuffer: ds.b 512   ; Safe buffer for one row of bitplanes (max 8 planes * 64 bytes)

dosbase:    dc.l 0	
file_handle: dc.l 0
arg_result:  dc.l 0
arg_array:   dc.l 0,0           ; Stores pointers to FROM and TO strings

fakeArgs:
;	dc.b "ball001002.iff output.raw",10,0 ; linefeed + null
	dc.b "  ",10,0
fakeArgsEnd=*-fakeArgs
	
	SECTION	DATABSS, BSS_C

SourceBuffer: ds.b 150000   ; Input data
WorkBuffer: ds.b 320*256    ; 80KB Chunky
DestBuffer: ds.b 40*256*5   ; Final Output
	END
