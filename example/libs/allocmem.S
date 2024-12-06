*********************************
*				*
*	AllocMem example	*
*				*
*********************************

; http://amigadev.elowar.com/read/ADCD_2.1/Includes_and_Autodocs_2._guide/node0332.html
; http://amigadev.elowar.com/read/ADCD_2.1/Includes_and_Autodocs_3._guide/node062D.html

MEMF_ANY      =$00000000
MEMF_PUBLIC   =$00000001
MEMF_CHIP     =$00000002
MEMF_FAST     =$00000004
MEMF_LOCAL    =$00000008
MEMF_24BITDMA =$00000010 ; Pre-V36 systems may not have this memor
MEMF_CLEAR    =$00010000

AllocMem = -198		; -$00C6
FreeMem  = -210		; -$00D2

BYTESIZE=$2000

.ALLOCMEM	
	MOVE.L	#(MEMF_CHIP+MEMF_CLEAR),D1
	MOVE.L	#BYTESIZE,D0
	MOVE.L	$4.W,A6
	JSR	AllocMem(A6)
	TST.W	D0
	BEQ	ERROR

.FREEMEM
	MOVE.L	D0,A1
	MOVE.L	#BYTESIZE,D0
	JSR	FreeMem(A6)
	
	RTS

ERROR
	RTS
	
