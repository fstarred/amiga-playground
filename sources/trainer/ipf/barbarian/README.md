# Barbarian (Palace) trainer
## INFO
Format: DOS

This game has a protection (Rob Northen?) in which the code is loaded using a key generated from the code itself, therefore normally it is not possible to 
patch the code without making the game crash during loading.

First step was to reproduce the initial part in order to generate the code to modify

```
LB_22E8	
;	MOVEM.L	D0-A6,-(SP)
	
	MOVE.L	A0,A2
	ADDA.L	#4,A0
	
	MOVE.L	#$00000200,D2
	MOVE.L	#$00000D58,D3
	MOVE.L	A0,A1
	ADDA.L	#$40,A1
	CLR.L	D0
LB_2302	
	CLR.L	D1
	MOVE.W	$00(A0,D0.W),D5
LB_2308	
	EOR.W	D5,$00(A1,D1.W)
	MOVE.W	$00(A1,D1.W),D5
	ADDQ.L	#2,D1
	CMP.W	D3,D1
	BNE.B	LB_2308
LB_2318	
	ADDQ.L	#2,D0
	CMP.W	#$0040,D0
	BEQ.B	LB_2318
	CMP.W	D2,D0
	BNE.B	LB_2302
LB_2328		
```

Second step was to mock the part where the code is read and the key is generated, in order to allow patching the code.

Therefore the instruction

```
move.b (a0)+,d1
```

become

```
jsr <address_to_mocked_read>
```

the HACK_READ instruction basically do the same of the original instruction but for the patched address, where it is forced to read to 
a prebuilt table of opcodes

```
OR_OPCODES_P1:
	DC.W	$1218		; move.b (a0)+,d1
	DC.W	$E149		; lsl.w #$08,d1
	DC.W	$B342		; eor.w d1,d2
END_OR_OPCODES_P1

OR_OPCODES_P2:
	DC.W	$4E75		; rts
	DC.L	$2E7A0BE6	; movea.l (pc,$0be6),a7
END_OR_OPCODES_P2
```
