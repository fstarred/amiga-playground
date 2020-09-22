# Amiga playground

Amiga demo written in assembly

## Premise

Most of the code present on this repository is inspired from RamJam italian course, which is downloadable from [this link][1]

## How to run the demo

1. Download and run your favourite version of Asm-One; all the demo and examples here were tested with **1.02** and **1.20**
2. Select the workspace memory (100 KB is good)
3. Load the source
4. Type 'a' (assemble) and then type 'j' (jump)

## Demo 1

![screenshot](https://github.com/fstarred/amiga_playground/blob/master/docs/demo_1.png?raw=true) 

#### Ball animation / move

The animated ball is composed by 4 sprites of 16x32px, in which 2 are in ATTACHED mode. This allow to use 16 colors instead of the standard 4 expected for standard sprites (3 + background).

```    
frame1:

    dc.w $0000,$0000
    dc.w $0000,$0000,$0000,$0000,$0007,$0007,$003f,$003f
    dc.w $00ff,$00ff,$03ff,$03ff,$07fe,$07ff,$0ffe,$07ff
    dc.w $07fe,$07ff,$03fe,$07ff,$03fe,$01ff,$003d,$00fe
    dc.w $000f,$0000,$0001,$000e,$0000,$40ff,$0000,$03ff
    dc.w $0000,$3ffe,$0000,$5ffe,$0000,$4ff8,$0000,$01e0
    dc.w $0000,$0000,$2000,$2000,$0000,$1000,$0000,$1800
    dc.w $0400,$0600,$0100,$0780,$0000,$0382,$0000,$01c2
    dc.w $0000,$00fe,$0000,$003f,$0000,$0007,$0000,$0000
    dc.w 0,0

frame1a:
    dc.w $0000,$0080 ; ATTACHED MODE! bit 7 set for odd sprite
    dc.w $0000,$0000,$0000,$0007,$0004,$003b,$0040,$00ff
    dc.w $0100,$01ff,$0000,$03ff,$0000,$07ff,$0800,$0fff
    dc.w $0800,$1fff,$0000,$1fff,$0201,$3fff,$0102,$3fff
    dc.w $0030,$3fff,$0001,$7ff0,$0000,$3f00,$4000,$3c00
    dc.w $0001,$0000,$2001,$0000,$1007,$0000,$261f,$0000
    dc.w $21ff,$0000,$0c3f,$0000,$1f07,$0000,$1f82,$0000
    dc.w $0380,$0000,$0680,$0000,$0382,$0000,$01c2,$0000
    dc.w $00fe,$0000,$003f,$0000,$0007,$0000,$0000,$0000
    dc.w 0,0
    
    [...]
```

Either sprite animation and move routines are ripped from RamJam course.

The *sprite animation* routine roll up the *FRAMETAB* table in an infinite loop, so the current frame animation address is load on SPRxPTH and SPRxPTL registers.

```
    lea FRAMETAB(PC), a0 ; 
    move.l  (a0),d0     ; save current first frame address to d0
    move.l  4(a0),(a0)  ; scroll frame to 1st position
    move.l  4*2(a0),4(a0)   ; scroll frame to 2nd position
    move.l  4*3(a0),4*2(a0) ; scroll frame to 3rd position
    move.l  4*4(a0),4*3(a0) ; scroll frame to 4th position
    move.l  4*5(a0),4*4(a0) ; scroll frame to 5th position
    move.l  4*6(a0),4*5(a0) ; scroll frame to 6th position
    move.l  4*7(a0),4*6(a0) ; scroll frame to 7th position
    move.l  d0,4*7(a0)  ; put saved frame to last position
    
    move.l  FRAMETAB(PC),d0 ; SPRITE_1 address
    lea SPRITEPOINTERS,a1 ; SPRITE pointer
    move.w  d0,6(a1) ; copy L word of sprite address to pointer
    swap    d0       ; swap the the two words
    move.w  d0,2(a1) ; copy the H word of sprite address to pointer
    swap    d0
    
    add.l   #sprite_frame_offset,d0  ; the sprite is $44 bytes ahead    
    addq    #8,a1    ; move SPRITE_POINTERS pointer to next sprite
    move.w  d0,6(a1) ; copy L word of sprite address to pointer
    swap    d0       ; swap the the two words
    move.w  d0,2(a1) ; copy the H word of sprite address to pointer 
    swap    d0
    
    ...
```    

The *sprite move* routine get the actual X and Y pos from a precalculated position table and then call *generic_sprite_move* routine which take care of moving the sprite accross the screen.

``` 
sprite_move:
    addq.l  #1,tab_y_pointer     ; point to next TAB Y
    move.l  tab_y_pointer(PC),a0 ; copy pointer y to A0
    cmpi.l   #ENDTABY-1,a0  ; check if Y end is reached
    bne.s   move_y_tab  ; 
    move.l  #TABY-1,tab_y_pointer ; reset to first tab Y
move_y_tab:
    moveq   #0,d4       ; clean D4
    move.b  (a0),d4     ; copy Y value to D4

    addq.l  #2,tab_x_pointer ; point to next TAB X
    move.l  tab_x_pointer(PC),a0 ; copy pointer x to a0
    cmpi.l   #ENDTABX-2,a0 ; check if X end is reached
    bne.s   move_x_tab
    move.l  #TABX-2,tab_x_pointer ; reset to first tab X
move_x_tab:
    moveq   #0,d3       ; clean D3
    move.w  (a0),d3 ; copy X value to D3
``` 

Both X and Y coords are pixel values, so for a standard LORES mode X coord may range between 0 and 320 and Y within 0 and 255.

So said, the precalc sine tabs of *TABX* is made of word values, whereas *TABY* is made of bytes.

The sine tables values were created using **IS** (Create Sine) **AsmOne** command, available from version **1.07**.

When the right margin is reached, the animating ball moves behind the text. 

When the ball reaches the left margin it appers in front of the text instead.

This can be done by setting the **BPLCON2** register.

```
    
;CODE      |    000    |    001    |    010    |    011    |    100    |
;----------------------------------------------------------------------------
;PRI. MAX  | PLAYFIELD | COUPLE 1  | COUPLE 1  | COUPLE 1  | COUPLE 1  |
;          | COUPLE 1  | PLAYFIELD | COUPLE 2  | COUPLE 2  | COUPLE 2  |
;          | COUPLE 2  | COUPLE 2  | PLAYFIELD | COUPLE 3  | COUPLE 3  |
;          | COUPLE 3  | COUPLE 3  | COUPLE 3  | PLAYFIELD | COUPLE 4  |
;PRI. MIN  | COUPLE 4  | COUPLE 4  | COUPLE 4  | COUPLE 4  | PLAYFIELD |

.check_right_margin
    cmpi #$11A, (a0)
    bne.s   check_left_margin
    clr.w   SPRITE_PRIORITY ; all sprites over PLAYFIELD
    bra.s   exit_sprite_move

check_left_margin:
    tst (a0)
    bne.s   exit_sprite_move    
    move.w  #$0012, SPRITE_PRIORITY ; sprite couple (1,2) (3,4) behind PLAYFIELD
    
    ...
    
COPPERLIST:
       
    dc.w    $104 

SPRITE_PRIORITY:
    dc.w    $0012 ; sprite couple 1,2 over playfield 1  
                 ; code 010 twice (%010010%)
    
```

#### Top and bottom margin bars

The *move_tb_margin_bars* routine realize a carousel effect on top and bottom horizontal bars of the screen.
This mean each color roll down of a position until the last one, whereas the latter takes the 1st position, like a pile stack.

```
************************************************************************
*	rolling color routine                                          *
*	<INPUT>                                                        *
*	A0 = HORIZONTAL BAR (STARTING FROM FIRST COLOR)		       *
************************************************************************

rolling_color_hbar: 
    
    move.w  2+8(a0),2+0(a0) ; 07
    move.w  2+16(a0),2+8(a0)    ; 17
    move.w  2+24(a0),2+16(a0)   ; 27
    move.w  2+32(a0),2+24(a0)   ; 37
    move.w  2+40(a0),2+32(a0)   ; 47
    move.w  2+48(a0),2+40(a0)   ; 57
    move.w  2+56(a0),2+48(a0)   ; 67
    move.w  2+64(a0),2+56(a0)   ; 77
    move.w  2+72(a0),2+64(a0)   ; 87
    move.w  2+80(a0),2+72(a0)   ; 97
    move.w  2+88(a0),2+80(a0)   ; a7
    move.w  2+96(a0),2+88(a0)   ; b7
    move.w  2+104(a0),2+96(a0)  ; c7
    move.w  2+112(a0),2+104(a0) ; d7
    move.w  2+0(a0),2+112(a0)   ; e7

    rts
```


#### Starfield

The *move_stars* routine is another routine taken from RamJam course; it draws a starfield composed by objects moving with 3 different speeds.
To enrich the depth effect of the space, stars may be more bright or dark using properly *WAIT* and *MOVE* commands of the COPPERLIST.

```
STAR_S_COL = $0444
STAR_M_COL = $0999
STAR_F_COL = $0eee


    ; set star color according to its speed
    ; slow are dark
    ; medium are mid-bright 
    ; fast are bright
    
    dc.w $5407,$fffe
    dc.w $01b2,STAR_M_COL   ; medium (col17 sprite a)
    dc.w $5507,$fffe
    dc.w $01b2,STAR_S_COL   ; slow
    dc.w $5707,$fffe
    dc.w $01b2,STAR_F_COL   ; fast
    dc.w $5907,$fffe
    dc.w $01b2,STAR_M_COL   ; medium (col17 sprite a)
    dc.w $5b07,$fffe
```

#### Display text

The *show_text* routine is divided by 4 stages or routines that are addressed on a rout_table.

```
rout_table:
	dc.l	0 ; not assigned	; 0
	dc.l	print_new_text		; 1
	dc.l	fade_in_quick		; 2
	dc.l	fade_out_quick		; 3
	dc.l	clear_text		; 4
```
Basically there is a label that contains the stage counter value, and after a stage is completed counter increase.

This is how the current stage routine is called:

```
    move.b  text_phase,d0	; use routine tab
    
    add.w    d0,d0
    add.w    d0,d0	; Every routine distances each one of a 32 bit address (dc.l)

    move.l   rout_table(pc,d0.w), a0
    jmp	     (a0)
```

1. print current text

On this stage, we take care of plotting a single line of the current text block on VBLANK event, and so the next one until last line is reached. 
By doing this, we avoid loading too much the CPU.

```
***************************************************************************
*   print text routine                                                    *
*                                                                         *
*   <INPUT>                                                               *
*   A0 = TEXT address pointer                                             *
*   A3 = BITPLANE address pointer                                         *
*                                                                         *
*   <OUTPUT>                                                              *
*   A0 = TEXT address pointer + TEXT_COLS                                 *
*   A3 = BITPLANE address pointer + BITPLANE text line height             *
*                                                                         *
***************************************************************************
print_text:

.print_row:
    moveq   #TEXT_COLS-1,d0 ; NUMBER OF COLUMNS in D0

print_char:
    moveq   #0,d2       ; 
    move.b  (a0)+,d2    ; point to next char in D2
    subi.b   #$20,d2     ; subtract 32 ASCII chars to d2                     
    add.l   d2,d2       ; get the char offset, because
                ; every char is 16 pixel
    move.l  d2,a2       ; copy the offset to A2

    add.l   #FONT,a2    ; retrieve the char we need

    BLTWAIT BWT1
    
    dbra    d0,print_char   ; print char

    ;   40*(bpls-1) skip all bitplane line (excluding the first one)
    ;   (40*FONT_HEIGHT)*bpls   distance between row
    add.w   #ScrBpl*(bpls-1)+(ScrBpl*FONT_HEIGHT)*bpls,a3   ; jump to next bitplane line
    ;lea    +(ScrBpl*(bpls-1)+(ScrBpl*FONT_HEIGHT)*bpls)(a3), a3 ; same as above

    ; ********************************
    ; uncomment code below if TEXT_COLS < 20

    addi   #(20-TEXT_COLS), a0
    add.w  #(ScrBpl-(TEXT_COLS*2)), a3
    ; ********************************

    rts
```


2. fade in 

On this phase, text is faded in using a precalc colour table. 

Notice that *tabpointer* may point to 3 different set of colours, each of one is composed by 17 values of red, green and blue.

3. fade out

Same logic of *fade in* routine, but with inverted color progression of *tabpointer*

4. clear text

Clear all text on the screen by blitting with only channel D enabled.
The deletion does not involve the starfield that is independent from bitplanes. 

#### Interleaved mode

Text image (and so bitplanes) are stored in *interleaved mode*.
To better explain the difference, have a look on how bitplanes are disposed on standard mode:

###### STANDARD BITPLANE

line 0 BITPLANE 1<br/>
line 1 BITPLANE 1<br/>
line 2 BITPLANE 1<br/>
..<br/>
line 255 BITPLANE 1<br/>
<br/>
line 0 BITPLANE 2<br/>
line 1 BITPLANE 2<br/>
line 2 BITPLANE 2<br/>
..<br/>
line 255 BITPLANE 2<br/>
<br/>
line 0 BITPLANE 3<br/>
line 1 BITPLANE 3<br/>
line 2 BITPLANE 3<br/>
..<br/>
line 255 BITPLANE 3<br/>
.. and so on


###### INTERLEAVED (OR RAWBLIT) BITPLANE

line 0 BITPLANE 1<br/>
line 0 BITPLANE 2<br/>
line 0 BITPLANE 3<br/>
line 1 BITPLANE 1<br/>
line 1 BITPLANE 2<br/>
line 1 BITPLANE 3<br/>
...<br/>
line 255 BITPLANE 1<br/>
line 255 BITPLANE 2<br/>
line 255 BITPLANE 3<br/>



Setting BITPLANE as INTERLEAVED:

1. Make point the next BPLxPTH and BPLxPTL after the next line of the previous BITPLANE address (Tipically 40 bytes for LORES and 80 for HIRES)

```
    move.l  #SCREEN,d0  ; point to bitplane
    lea BPLPOINTERS,a1  ; 
    MOVEQ   #bpls-1,d1      ; 2 BITPLANE
POINTBP:
    move.w  d0,6(a1)    ; copy low word of pic address to plane
    swap    d0          ; swap the the two words
    move.w  d0,2(a1)    ; copy the high word of pic address to plane
    swap    d0          ; swap the the two words

    add.l   #40,d0      ; BITPLANE point to next byte line data
                        ; instead of the standard raw
                        ; where bitplane is immediately
                        ; after the previous bitplane
                        ; standard raw (40*256)
                        ; blitter raw (40)
    addq.w  #8,a1       ; the next bpl starts one row
                ; after the previous one
    dbra    d1,POINTBP
```

2. Set the BITPLANE MODULO value to skip the others BITPLANE data. The formula is (Fetched bytes x line) * (number of bitplanes -1).
So let's say we have a 3 bitplanes LORES, the value will be: x = 40 * (3-1) = 80

```
    dc.w    $108,ScrBpl*(bpls-1)    ; Bpl1Mod (interleaved) 
    dc.w    $10a,ScrBpl*(bpls-1)    ; Bpl2Mod (interleaved)
```


## Demo 2

![screenshot](https://github.com/fstarred/amiga_playground/blob/master/docs/demo_2.png?raw=true) 


#### Logo

The logo is blitted before the main loop; 

the logo itself was saved with 2 palette set, one full color and one Black&White

```
LOGO_COLOR:
	dc.w $0180,$0000,$0182,$018f,$0184,$0148,$0186,$0455
	dc.w $0188,$005b,$018a,$0999,$018c,$007f,$018e,$0124
	dc.w $0190,$0268,$0192,$0ddd,$0194,$068a,$0196,$0bbb
	dc.w $0198,$0677,$019a,$00af,$019c,$0eff,$019e,$0037


START_GRAY:
	dc.w	$5b07,$fffe
	
	;dc.w	$2c07,$fffe
	;dc.w	$7c07,$fffe

LOGO_GRAY:

	dc.w $0180,$0000,$0182,$099a,$0184,$0778,$0186,$0455
	dc.w $0188,$0899,$018a,$0999,$018c,$0aaa,$018e,$0444
	dc.w $0190,$0888,$0192,$0bbb,$0194,$099a,$0196,$0bbb
	dc.w $0198,$0677,$019a,$09aa,$019c,$0bbb,$019e,$0555
```


#### Vertical Bar 

The vertical bar moving around the logo is a sprite activated with DIRECT ACCESS to register instead of DMA access.

By using this mode, the rules are the following:

1. There is no need to set *SPRxPTH* and *SPRxPTL* registers
2. Sprite is enabled/disabled by accessing SPRxCTL register on the COPPERLIST.
3. Sprite data is automatically drawn each line until is disabled (see the rule above)

In this mode it is also possible to redraw the sprite on the same vertical line by disabling and reactivating it using SPRxCTL register on the proper column of the copperlist

#### Color VS Gray effect

The logo was produces using 2 different palettes, one colourized and one with gray tones.
To make the up & down color effect, it is enough to set a palette to a fixed vertical position and to delay the other palette.

```
LOGO_COLOR:
	dc.w $0180,$0000,$0182,$018f,$0184,$0148,$0186,$0455
	dc.w $0188,$005b,$018a,$0999,$018c,$007f,$018e,$0124
	dc.w $0190,$0268,$0192,$0ddd,$0194,$068a,$0196,$0bbb
	dc.w $0198,$0677,$019a,$00af,$019c,$0eff,$019e,$0037


START_GRAY:
	dc.w	$5b07,$fffe	

LOGO_GRAY:

	dc.w $0180,$0000,$0182,$099a,$0184,$0778,$0186,$0455
	dc.w $0188,$0899,$018a,$0999,$018c,$0aaa,$018e,$0444
	dc.w $0190,$0888,$0192,$0bbb,$0194,$099a,$0196,$0bbb
	dc.w $0198,$0677,$019a,$09aa,$019c,$0bbb,$019e,$0555
```


#### Equalizer

Equalizer is composed by four bars that increase its height with a repeated pattern according to channel volume

```
BAR:	
	dc.w	%0000000000000000, %0000000000000000, %0000000000000000, %0000000000000000
	dc.w	%1010101000000000, %1010101000000000, %1010101000000000, %1010101000000000
```

With *Blitter* is possible to draw a repeated pattern for *x* times by just increasing the BLTSIZE height / width value.

To see if channel is "touched" or played, there is the register *pt_audchanXtemp* (where x can be 1,2,3,4).
The channel volume can be fetched from the 19th byte of the above register.

#### Scrolling text

Font text is stored on 3 bitplanes non-interleaved data.
The current font char address may be get by reading a lookup table data.

```
FONT_ADDRESS_LIST:
	dc.l FONT	
	dc.l FONT+4	
	dc.l FONT+8
	dc.l FONT+12,FONT+16,FONT+20,FONT+24,FONT+28,FONT+32,FONT+36

	; 2nd COLUMN (40 bytes*32)
	dc.l FONT+1280		
	dc.l FONT+1284
	dc.l FONT+1288
	dc.l FONT+1292
	dc.l FONT+1296,FONT+1300,FONT+1304,FONT+1308,FONT+1312,FONT+1316

	; 3rd COLUMN (40 bytes*32*2)
	dc.l FONT+2560,FONT+2564,FONT+2568,FONT+2572,FONT+2576,FONT+2580
	dc.l FONT+2584,FONT+2588,FONT+2592,FONT+2596

	; 4th COLUMN (40 bytes*32*3)
	dc.l FONT+3840,FONT+3844,FONT+3848,FONT+3852,FONT+3856,FONT+3860
	dc.l FONT+3864,FONT+3868,FONT+3872,FONT+3876

	; 5th COLUMN (40 bytes*32*4)
	dc.l FONT+5120,FONT+5124,FONT+5128,FONT+5132,FONT+5136,FONT+5140
	dc.l FONT+5144,FONT+5148,FONT+5152,FONT+5156
	
	; 6th COLUMN (40 bytes*32*5)
	dc.l FONT+6400,FONT+6404,FONT+6408,FONT+6412,FONT+6416,FONT+6420
	dc.l FONT+6424,FONT+6428,FONT+6432,FONT+6436
```

Font size is 32x32px, so table address was built following these rules: 
1. Font width is 32px, therefore the distance between each font in the same column is 4 bytes
2. Distance between column can be calculated with the formula: (bytes per line * font height * col_x) = (40 * 32 * col_x).

![screenshot](https://github.com/fstarred/amiga_playground/blob/master/docs/kefrens_converter.JPG?raw=true)

The scrolling text effect can be achieved by drawing next character outer the right side of the screen, and then do a shift blit on the whole part of the screen of the text area with DESC mode, because we want text to scroll towards left direction.

In order to print font character out the screen, we need to extend the bitplane size by adding the space needed for the font; 
in this case we must initialize all LORES bitplanes with (40+4) * 256 bytes.

If fetched line data doesn't change, we need to set BITPLANE MODULO = + 4 in order to skip the font to the right margin

```
	dc.w	$108,+4 ; Bpl1Mod  +4
	dc.w	$10a,+4 ; Bpl2Mod  +4
```

#### Mirror effect

The well-know Amiga mirror effect can be achieved by setting the *BPLxMOD* register to a negative value, often calcuted as 
x = -((bytes per line * y) + (y-1 * *BPLxMOD*)).

In this way, the next line data will jump and fetch the "old" line data.

Notice the above formula won't work for INTERLEAVED bitplane.



## Demo 3

![screenshot](https://github.com/fstarred/amiga_playground/blob/master/docs/demo_3.png?raw=true) 

#### HIRES and LORES

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



#### Chessboard

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

#### Chessboard animation

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


#### Scroll header screen

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
	

#### Copper bars

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


#### Sprite animation and move

This works exactly as Demo 1; as a plus we make the ball rolling faster as it approaches the text.

```
ANIMATION_SLOW = 4
ANIMATION_FAST = 2

animation_frame_delay:	dc.w	ANIMATION_SLOW
```

#### Interactive camel scrolling text

The effect is realized in 6 steps:

1. Print next char on a memory buffer of (40+font width bytes) * (font height pixels)
2. Scroll text area of the memory buffer using SHIFT BLIT on DESC mode (see Demo 2)
3. Copy text buffer to SCREEN
4. Calculate all the involved points needed to create the camel effect
5. Clear dirty area
6. Create the camel effect

The camel effect takes inspiration from the well-know sinus scroll, where each slice of text (usually 1,2 or 4 pixel) is drawn at different height from each other; 
Every piece of text is BLITTED with BLTCON0/1 = 0bfa0000 and A,C,D channels enabled, in order to do an A or C COPY where A = TEXT SLICE and C = SCREEN

The low edge of the text is reached on the ball sprite Y+HEIGHT position.

#### Double buffering

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

## Trainers

### How to create a trainer (DOS disk)

To create a game trainer, you have to:

1. Create a splash screen with available menu, then store user's selection somewhere on available RAM
2. Create a patch code
3. Call [LoadSeg()][2] function with game executable. This will load file and allocate it on available ram, returning the pointer on it.
4. Copy the patch code on available ram
5. Jump to that pointer

### Create a splash screen

If you have no idea where to start, just take a look to existing sources on [this link][3]

![screenshot](https://github.com/fstarred/amiga-playground/blob/master/docs/deflktor_trainer.png?raw=true) 

### Create a patch code

First off, it is enough to say that no programming skills are required for finding some basic features like infinite lives, time, etc etc.

It is just enough to choose your favourite debugger - if you use an emulator, WinUAE has its own - otherwise a freeze cartridge like Action Replay may help you.

Once you find the memory address where lives, time, or whatever else is stored, add a watch on it in order to find out the opcode that cause a decrement on that value: 

Often you'll find something like:
```	
    SUBQ #1, Dx 
    or
    SUB #1, $someaddress
```	
If you see something like above, you are likely on the right way.
In order to avoid subtracting that value, replace the opcodes with NOP.
Example:

```
    0005AEEA 5379 0005 907c           SUBQ.W #$01,$0005907c ; subtract 1 on memory content located at $5907c 
``` 
Your patch code will replace 5379 0005 907c with
```
    LEA	        $5AEEA,A0        ; LOAD ADDR $5AEEA on A0
    MOVE.L	#$4E714E71,D1    ; STORE NOP (4E71) OPCODE ON D1 TWICE
    MOVE.L	D1,(A0)+         ; REPLACE ORIGINAL OPCODE WITH 3 NOP
    MOVE.W	D1,(A0)
```
The patch code must be called in place of the JMP code that game calls after all data is loaded / depacked (the final JMP on code).

Let's say that the final JMP is located at $80 from the pointer returned by LoadSeg():

```
	LEA	SPARE_MEM,A3		;SPARE MEMORY FOR PATCH
	MOVE.L	A3,$82(A1)	        ;COPY NEW ADDRESS INTO FINAL JMP (WHICH IS LOCALTED AT INITIAL FILE ADDRESS + $80)

	LEA	PATCH_BEGIN(PC),A2	;POINTER TO PATCH CODE	
```
In order to find all JMP from the file pointer, you may use a search with 4EF9; for example, using WinUAE debugger, the command is:

s 4EF9 \<address\>

*NOTE*
OPCODES can be found either on some 68k documentations or with use of assembler. In the latter case, if you use DEBUGGER on ASM-ONE, you can see on bottom of the screen the opcode of the current instruction.

### Calling LoadSeg function

Here's a snippet that shows how to use LoadSeg

```
LOADEXEC
	MOVE.L	4.W,A6			;GET EXECBASE
	LEA	DOSLIB(PC),A1		;POINTER TO 'DOS.LIBRARY'
	JSR	-$198(A6)		;OPEN OLD DOS.LIBRARY
	TST.L	D0			;IF D0 = 0 THEN LIBRAY OPEN FAILED
	BEQ.W	PROBLEM
	MOVE.L	D0,A6			;PUT DOS.LIBRARY BASE ADDRESS IN A6
	
	LEA	FILENAME(PC),A0		;GET FILENAME PC RELATIVE
	MOVE.L	A0,D1			;MOVE FILENAME INTO D1
	JSR	-$96(A6)		;CALL LOADSEG
	LSL.L	#2,D0			;CONVERT FROM BCPL TO STANDARD POINTER
	MOVE.L	D0,A0			;MOVE ADDRESS INTO A0
```
### Copy the patch code on available ram

Here's a snippet that shows how to reallocate a piece of code into memory

```
	LEA	PATCH_BEGIN(PC),A2		;POINTER TO PATCH CODE

	LEA	SPARE_MEM,A3		;SPARE MEMORY FOR PATCH
	MOVE.L	A3, $B2(A1)		;COPY NEW ADDRESS INTO FINAL JMP (WHICH IS LOCALTED AT INITIAL FILE ADDRESS + $B0)
	
        MOVE.W	#(PATCH_END-PATCH_BEGIN)-1,D0    ;SIZE OF PATCH TO COPY
COPY_PATCH:
	MOVE.B	(A2)+,(A3)+		;COPY FROM START OF PATCH ROUTINE
					;TO SPARE MEMORY
	DBRA	D0,COPY_PATCH		;SUBRACT FROM PATCH SIZE AND LOOP
					;UNTIL COPIED
	JMP	4(A0)			;EXECUTE FILE LOADED BY LOADSEG
	
	
PATCH_BEGIN
; some code here
PATCH_END
```	

[1]: http://corsodiassembler.ramjam.it/index_en.htm
[2]: http://amigadev.elowar.com/read/ADCD_2.1/Includes_and_Autodocs_2._guide/node02C5.html
[3]: https://flashtro.com/category/source/ctsource/amigasources/
