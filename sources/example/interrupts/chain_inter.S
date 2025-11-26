****************************************************
*						   *
* Attach a keyboard routine to existent interruput *
*						   *
****************************************************

	lea.l	jump,a1          ; move address of jump into a1
	move.l	$68,2(a1)        ; move value in address $68 (interupt 2) into memory pointed to by a1+2

	moveq	#100,d0          ; move 100 into d0

	moveq	#1,d1            ; move 1 into d1
	swap	d1               ; swap words in d1, value is now $10000 
	move.l	$4,a6            ; move value (ExecBase of exec.library) in address $4 into a6
	jsr	-198(a6)         ; Jump to subroutine AllocMem in exec.library, d0 = AllocMem(d0, d1), allocate 100 bytes with type of memory MEMF_CLEAR.

	move.l	d0,a1            ; put address of allocated memory stored in d0 into a1
	move.l	d0,d7            ; put address of allocated memory stored in d0 into d7

	lea.l	interrupt,a0     ; move address of interrupt into a0
	moveq	#24,d0           ; set d0 to 24. Use d0 as a copyloop counter

copyloop:
	move.l	(a0)+,(a1)+      ; copy value pointed to by a0 into address pointed to by a1. Increment both with 4 bytes (1 long word)
	dbra	d0,copyloop      ; if d0 > -1 goto copyloop

	move.w	#$4000,$dff09a   ; INTENA Interupt enable bits - disable all interrupts
	move.l	d7,$68           ; move value in d7 that points to our allocated memory into $68 (interupt 2)
	move.w	#$c000,$dff09a   ; INTENA Interupt enable bits - enable all interrupts

.loop
	btst	#6,$bfe001
	bne.b	.loop

	rts                      ; return from subroutine (main program)

interrupt:          		; begin interrupt handler routine
	move.l	d0,-(a7)  	; push value in d0 onto the stack
	move.b	$bfec01,d0	; read a byte from CIAA serial data register connected to keyboard into d0
	not.b	d0        	; negate a byte in d0
	ror.b	#1,d0     	; rotate right 1 bit
	
	cmp.b	#$59,d0   	; compare F10 key value with d0
	bne.s	wrongkey  	; if not F10 pressed - goto wrongkey
	
	bchg	#1,$bfe001	; Test bit and change. Bit 1 is power LED
	
wrongkey:	
	move.l	(a7)+,d0  	; pop the stack and put value into d0 - reestablish d0 to it's previous value
	
jump:	
	jmp	$0	  	; the jump was previously set to the value in address $68 (interrupt 2) so this interupt function is linked together with the previous one
