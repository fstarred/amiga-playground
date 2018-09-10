	moveq	#4, d0

	moveq	#0, d1
	moveq	#4-1,d6
loop2:
	btst	#0, d6
	bne.s	nochgoff
	neg.w	d0
nochgoff:
	moveq	#8-1,d7

loop1:
	add.w	d0, d1
	dbra	d7, loop1

	dbra	d6, loop2

	rts
