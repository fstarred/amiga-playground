# Impossible Mission II trainer
## INFO
Format: DOS

Game is not packed, so it is relatively easy to patch it; unfortunately, there is a bug when it try to do some odd RAM assertion so game won't start at all 
(a window will appear claiming for more memory). 

This bug also affects the original game when loading from a PAL system with 512KB.

The bad code looks like this:

```
b1fc 0004 6400           cmpa.l #$00046400,a0
632c                     bls.b #$2c ; if a0 is lower than $46400 then..
```

So I want to replace with:

```
4e71                     nop
4e71                     nop
4e71                     nop
602c                     bra.b #$2c ; is always true
```

The following patch satisfy the above expectation:

```
	LEA	BUTTONS(PC),A1
	MOVE.L	#$4E714E71,D1
	
	MOVE.L	A0,A2 
	ADDA.L	#$FDEC,A2	; avoid dumb ram space check 
	MOVE.L	D1,(A2)+
	MOVE.W	D1,(A2)+
	MOVE.W	#$602c,(A2)	; replace bls with bra
```
