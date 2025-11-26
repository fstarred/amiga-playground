# Demo 3

![screenshot](https://github.com/fstarred/amiga_playground/blob/master/docs/demo_3.png?raw=true) 

## Premise

Most of the code present on this repository is inspired from [RamJam italian course][1]

## HIRES and LORES

One great feature of the Amiga is the ability of display both LORES and HIRES at the same time, as well as diffent screen modes (+ o - bitplanes).

This is how we setup the screen:


```
;;    ---  SCREEN_H setup  ---

w_H	=640+320
h_H 	=48
ScrHBpl	=w_H/8	

bpls_H = 4

;;    ---  SCREEN_L setup  ---

w_L	=320
h_L	=256-h_H
ScrLBpl	=w_L/8	

bpls_L = 1

```



## Chessboard

The *draw_chessboard* receives 2 long word input as the square pattern to draw.

First off, pattern data (32x8px) is written to the upper screen (HIRES).

```
draw_cb_loop:
	
	move.l	d0, (a0)
	move.l	d0, ScrHBpl(a0)
	move.l	d0, ScrHBpl*2(a0)
	move.l	d0, ScrHBpl*3(a0)
	move.l	d0, ScrHBpl*4(a0)
	move.l	d0, ScrHBpl*5(a0)
	move.l	d0, ScrHBpl*6(a0)
	move.l	d0, ScrHBpl*7(a0)
	
draw_cb_loop_alt:
	
	move.l	d1, ScrHBpl*8(a0)
	move.l	d1, ScrHBpl*9(a0)
	move.l	d1, ScrHBpl*10(a0)
	move.l	d1, ScrHBpl*11(a0)
	move.l	d1, ScrHBpl*12(a0)
	move.l	d1, ScrHBpl*13(a0)
	move.l	d1, ScrHBpl*14(a0)
	move.l	d1, ScrHBpl*15(a0)
```

Then we do 2 blit: One will fill repeating the pattern data vertically, and one horizontally.

```
	BLTWAIT BWT9
	
	move.l	#$09f00000,BLTCON0(a5)	; BLTCON0: A-D
	move.l	#$ffffffff,BLTAFWM(a5)	; BLTAFWM + BLTALWM 

	move.l	a0, BLTAPT(a5)	; BLTAPT
	addi.l	#ScrHBpl*SQUARE_HEIGHT*2, a0
	move.l	a0, BLTDPT(a5) 	; BLTDPT
	move.l	#$00740074, BLTAMOD(a5) ; BLTAMOD
	move.w	#((h_H-(SQUARE_HEIGHT*2))*64)+2, BLTSIZE(a5) ; BLTSIZE	
	
	lea	SCREEN_H+(ScrHBpl*h_H*3), a0	; move to bitplane 3	
	
	BLTWAIT BWT10

	move.l	a0, BLTAPT(a5)	; BLTAPT	
	addq.l	#4, a0
	move.l	a0, BLTDPT(a5) 	; BLTDPT
	move.w	#$0004, BLTAMOD(a5) ; BLTDMOD
	move.w	#$0004, BLTDMOD(a5) ; BLTDMOD
	
	move.w	#(h_H*64)+(ScrHBpl/2-2), BLTSIZE(a5) ; BLTSIZE		
	
	rts
```

## Chessboard animation

When the ball reaches the *x* position, it activate the chessboard "open courtaine" animation.

Basically, there is a flag that indicates the action to do (close/open). According to the action, the routine will call the animation routine or - if action is completed - do nothing.

```
animate_chessboard:
	move.b	chessboard_counter(pc), d1
	tst.b	chessboard_action
	bne.s	prepare_chessboard_open_action
prepare_chessboard_close_action:
	tst.b	d1
	beq.s	no_chessboard_animation	; check if chessboard is already closed
	subq	#1, d1
	bra.s	prepare_draw_chessboard
prepare_chessboard_open_action:	
	btst	#3, d1
	bne.s	no_chessboard_animation	; check if chessboard is already open
	addq	#1, d1
prepare_draw_chessboard:
	move.b	d1, chessboard_counter	; update chessboard counter
	
	move.b	#$FF, d0
	lsr.b	d1, d0
	
	move.l	#$FF00FF00, d1		; start composing square patterns
	add.b	d0, d1
	swap	d1
	add.b	d0, d1
	move.l	d1, d0
	lsl.l	#8, d0
	move.b	#$FF, d0
	
	exg	d0, d1
	
	bra.s	draw_chessboard
	
no_chessboard_animation:
	rts
```

Notice the above routine prepare the input D0 and D1 before calling *draw_chessboard* routine.


## Scroll header screen

The scroll screen effect can be achieved by adding / subtracting a value within $11 and $77 on the *BPLCON1* register.
For *LORES* mode, BPLCON1 value can be:

$XX where X is a value between 1 and 15 (pixels). The two X set the value respectively for even and odd bitplanes.
For *HIRES* mode, each value fetch 2 pixels instead of 1, so max value is $77 indeed.

```
scroll_left:
	cmpi.b	#$77,OWNBPLCON1	; check right edge scroll reached
	beq.s	set_bpl_left	; if Z is clear go bplcon1_add

	add.b	#$11,OWNBPLCON1	; scroll 2px forward (hires)
	rts
```


To avoid scrolling issues, the BITPLANE pointer must point 2 bytes before bitplane

```
START:
    	move.l  #SCREEN_H-2,d0  ; point to bitplane
    	lea BPLPOINTERS_H,a1  ; 
   	moveq   #bpls_H-1,d1  ; 2 BITPLANE
POINTBP_H:
    	move.w  d0,6(a1)    ; copy low word of pic address to plane
    	swap    d0          ; swap the the two words
   	move.w  d0,2(a1)    ; copy the high word of pic address to plane
    	swap    d0          ; swap the the two words

	add.l   #ScrHBpl*h_H,d0      
			
	addq.w  #8,a1
                	
	dbra    d1,POINTBP_H
```

The value of *BPLxMOD* must change to fit the DdfStart value

```
	dc.w	$108,40-4	; Bpl1Mod
	dc.w	$10a,40-4	; Bpl2Mod
```
	

## Copper bars

The copper bars routines are ripped from RamJam course.
The effect is accompished in 3 steps:

1. init_copper_bars
2. clear_copper_area
3. rolling_copper_bars

The *init_copper_bars* should be called before *Main* routine; it dinamically generate a piece of copperlist with *MOVE* and *WAIT* instructions like:

```
dc.w $6001, $FFFE
dc.w $0180, $0000

dc.w $7001, $FFFE
dc.w $0180, $0000

[...]
```

The *clear_copper_area* routine set all the COLOR00 registers of the *BARCOPPER* label to 0 (background color).

The *rolling_copper_bars* write the proper color on the eight bars and move them following precalc *POSLIST* tab label


## Sprite animation and move

This works exactly as Demo 1; as a plus we make the ball rolling faster as it approaches the text.

```
ANIMATION_SLOW = 4
ANIMATION_FAST = 2

animation_frame_delay:	dc.w	ANIMATION_SLOW
```

## Interactive camel scrolling text

The effect is achieved with 6 steps:

1. Print next char on a memory buffer of (40+font width bytes) * (font height pixels)
2. Scroll text area of the memory buffer using SHIFT BLIT on DESC mode (see Demo 2)
3. Copy text buffer to SCREEN
4. Calculate all the involved points needed to create the camel effect
5. Clear dirty area
6. Create the camel effect

The camel effect takes inspiration from the well-know sinus scroll, where each slice of text (usually 1,2 or 4 pixel) is drawn at different height from each other; 
Every piece of text is BLITTED with BLTCON0/1 = 0bfa0000 and A,C,D channels enabled, in order to do an A or C COPY where A = TEXT SLICE and C = SCREEN

The low edge of the text is reached on the ball sprite Y+HEIGHT position.

## Double buffering

Camel scrolling text can heavily stress the CPU; to make sure the raster beam will draw all of the displayed frame before it reaches the VBLANK, double buffering tecnique may be useful.

With DB, all the draw operations are done on a "draw screen", while the other is displayed. 
Once VBLANK occurs, the draw screen is displayed whereas the other one will take its place.

The screens are so swapped:


```

swap_buffer:
	move.l	draw_buffer(pc), d0		
	move.l	view_buffer(pc), draw_buffer	
	move.l	d0, view_buffer			
				
	lea	BPLPOINTERS_L, a1	
	moveq	#bpls_L-1, d1	
POINTBP:
	move.w	d0,6(a1)
	swap	d0
	move.w	d0,2(a1)
	swap	d0
	
	addi.l	#ScrLBpl*h_L, d0
	
	addq.w	#8, a1
	
	dbra	d1, POINTBP

	rts

view_buffer	dc.l	SCREEN_L	; displayed buffer
draw_buffer	dc.l	SCREEN_L_2	; drawn buffer

```	


Obviously we need to store 2 copies of the screen:


```
SCREEN_L:
	ds.b	ScrLBpl*h_L*bpls_L
SCREEN_L_2:
	ds.b	ScrLBpl*h_L*bpls_L
```

[1]: http://corsodiassembler.ramjam.it/index_en.htm
