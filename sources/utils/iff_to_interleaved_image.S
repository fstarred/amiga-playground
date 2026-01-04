;---------------------------------------------------------------------------
; ByteRun1 Decompressor
;
; Convert a IFF compressed image into an interleaved format
;
; Inputs:
;   A0 = Source Address
;   A1 = Destination Address (Where raw bitplanes will go)
;   D0 = Size of Destination Buffer in bytes (How much to decode)
;
;---------------------------------------------------------------------------


Main:
	LEA	Source(PC),A0
	BSR	FindBody
	MOVE.L	A0,-(SP)
	Lea	Dest(PC),A1		
	LEA	Source(PC),A0
	BSR	FindBmhd
	BSR	GetImageSize
	MOVE.L	(SP)+,A0
	BSR	DecompressILBM
	RTS

		

FindBmhd
	MOVE.L	#'BMHD',D0
	BSR	FindSection
	ADDQ.L	#4,A0
	RTS
	

FindBody
	MOVE.L	#'BODY',D0
	BSR	FindSection
	ADDQ.L	#8,A0
	RTS

FindSection:
    ; A0 = Start of IFF file (The "FORM" tag)
    ; D0 = Section name (i.e. 'BMHD','BODY',etc)
    ; Returns A0 pointing to the specified section address
    move.l  4(a0),d1        ; Get total file size from IFF header
    add.l   a0,d1           ; D0 = End of file address
    addq.l  #8,a0           ; Skip "FORM" and Size
    addq.l  #4,a0           ; Skip "ILBM"

.Loop:
    cmp.l   (a0),d0   ; Is this the BODY chunk?
    beq.s   .Found
    
    ; If not BODY, skip this chunk
    move.l  4(a0),d2        ; Get chunk size
    addq.l  #1,d2           ; IFF chunks are word-aligned
    and.b   #$FE,d2         ; Force size to even
    addq.l  #8,a0           ; Skip Tag (4) and Size (4)
    add.l   d2,a0           ; Skip the chunk data
    
    cmp.l   d1,a0           ; Check if we hit end of file
    blt.s   .Loop
    rts                     ; BODY not found (handle error here)

.Found:
;    addq.l  #8,a0           ; Skip "BODY" and Chunk Size
    ; A0 now points to the first byte of compressed data
    rts


; Inputs:
;   A0 = BHMD Address
;
; Registers Modified:
;   D0,D1,D2,D3
; Output
;   D0

GetImageSize
	MOVE.W	4(A0),D0	; width in pixels
	MOVE.W	6(A0),D1	; height in pixels
	MOVEQ	#0,D2
	MOVE.B	12(A0),D2	; depth
	MOVE.W	D0,D3
	ANDI.B	#%111,D3	; check if mod 8 <> 0
	BEQ.B	CalcSize
	ADDQ.L	#1,D1
CalcSize
	LSR.W	#3,D0
	MULU.W	D1,D0 
	MULU.W	D2,D0
	RTS



; Inputs:
;   A0 = Source Address
;   A1 = Destination Address (Where raw bitplanes will go)
;   D0 = Size of Destination Buffer in bytes (How much to decode)
;
; Registers Modified:
;   A0, A1, D0, D1, D2

DecompressILBM:
    tst.l   d0              ; Safety check: Is destination size 0?
    beq.s   .Done           ; If yes, exit

.Loop:
    moveq   #0,d1           ; Clear D1 to ensure clean high-bytes for DBRA
    move.b  (a0)+,d1        ; Read the "Command Byte" (N)
    
    ; The command byte is signed. We check the sign bit.
    tst.b   d1
    bmi.s   .RunEncoded     ; If negative, it's a Repeat Run (or NOP)

    ; --- LITERAL RUN (0 <= N <= 127) ---
    ; Copy next N+1 bytes literally.
    ; DBRA loops (Count+1) times. D1 holds N, so it is already set correctly.
    
    sub.l   d1,d0           ; Update remaining output count (subtract N)
    subq.l  #1,d0           ; Subtract 1 more (total N+1)
    
.LitCopy:
    move.b  (a0)+,(a1)+     ; Copy byte Source -> Dest
    dbra    d1,.LitCopy     ; Decrement D1, loop until -1
    
    bra.s   .CheckDone      ; Check if we filled the buffer

.RunEncoded:
    ; --- REPLICATE RUN (-127 <= N <= -1) ---
    ; Repeat next byte -N+1 times.
    
    cmp.b   #-128,d1        ; Check for NOP (-128)
    beq.s   .CheckDone      ; If -128, do nothing, just check if we are done
    
    neg.b   d1              ; Negate N. (-1 becomes 1, -127 becomes 127)
    
    ; We need to repeat the byte (New D1 + 1) times.
    ; Example: Old N = -1. New D1 = 1. We want 2 copies.
    ; DBRA loops (Count + 1) times. D1 is 1. DBRA loops 2 times.
    ; D1 is perfectly set up for DBRA.

    sub.l   d1,d0           ; Update remaining output count
    subq.l  #1,d0

    move.b  (a0)+,d2        ; Read the single byte to be repeated
    
.RepCopy:
    move.b  d2,(a1)+        ; Store that byte in Dest
    dbra    d1,.RepCopy     ; Loop
    
.CheckDone:
    tst.l   d0              ; Check remaining bytes counter
    bgt.s   .Loop           ; If > 0, keep processing chunks

.Done:
    rts                     ; Return from subroutine


Source:
	incbin	image.iff
Dest:
	dcb.b	40*256*5
Dest_end
