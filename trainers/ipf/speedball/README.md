# Speedball trainer
## INFO
Format: **NDOS**
Trainer menu is written on sector 4, size 3 (max 1536 KB)

Had some difficult on searching for the right place because I was not able to write on further sectors (maybe due to disk format used?)

The _JMP DoIo_ instruction was replaced with _JSR DoIo_ in order to load game code to a specific address and modify easily. 
```
	MOVE.L	#DEPACK_ADDRESS,A3
	MOVE.L	A3,$0028(A4)			; buffer
	MOVE.W	#$0002,$001C(A4)		; command: read
	MOVE.L	#$00000400,$002C(A4)		; offset
	MOVE.L	$00000004,A6
	MOVE.L	A4,A1
	MOVE.L	A5,A0
	JSR	DoIo(A6)			; do a jsr instead of a jmp
						; because we need to modify
						; the code

```

I had to deal with STACK in order to make it jump to trainer address and then to original code

```

	LEA	DO_TRAINER(PC),A4		; replace
	MOVE.B	#$0C,$2B(A3)			; move.l a0,-(a7)
						; with a4 so 
						; patch address
						; is pushed on stack
						; and used at rts
						
	MOVE.L	A5,-(SP)			; store alloc.mem to sp

```
