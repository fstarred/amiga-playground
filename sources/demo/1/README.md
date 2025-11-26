# Demo 1

![screenshot](https://github.com/fstarred/amiga_playground/blob/master/docs/demo_1.png?raw=true) 

## Premise

Most of the code present on this repository is inspired from [RamJam italian course][1]

## Ball animation / move

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

## Top and bottom margin bars

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


## Starfield

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

## Display text

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

## Interleaved mode

Text image (and so bitplanes) are stored in *interleaved mode*.
To better explain the difference, have a look on how bitplanes are disposed on standard mode:

### STANDARD BITPLANE

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


### INTERLEAVED (OR RAWBLIT) BITPLANE

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

[1]: http://corsodiassembler.ramjam.it/index_en.htm
