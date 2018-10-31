# Amiga playground

A repository dedicated to demo written in asm

## Premise

Most of the code contained in these demo was taken or inspired from RamJam italian course, which is downloadable from [this link][1]

## Demo 1

![screenshot](https://github.com/fstarred/amiga_playground/blob/master/docs/demo_1.png?raw=true) 

### POI

#### Ball animation / move

The animated ball is composed by a total of 4 sprites of 16x32, in which 2 of these are in ATTACHED mode in order to use 16 colors instead of only 4 (3 + background).

Either sprite animation and move are almost universal routines taken from RamJam course.

The *sprite animation* routine need to set up the frames involved for the animation loop.

The *sprite move* routine get the actual X and Y pos from a precalculated position table and then call* generic_sprite_move* which takes care of move the sprite on the right position of the screen.

Both X and Y coords are pixel measures, so for a standard LORES mode X should range of 0-319 and Y of 0-255

#### Top and bottom margin bars

The *move_tb_margin_bars* routine does the carousel effect with both top and bottom horizontal bars, therefore each color bar starting from the first position scroll down of one till the last one which takes the first position, like a pile stack.

#### Playfield stars

The *move_stars* routines, which is basically taken from RamJam course, draw a playfield made of stars moving at 3 different speed: To enrich the depth effect of the space, stars were drawn with several colours using the copperlist.

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

#### Text

The *show_text* routine can be divided on a 4 phase infinite loop:

1. print current text

On this phase, each line of current text is plotted on each VBLANK: 
By doing this, we don't worry of printing the whole text once and taking too much load on the CPU.

2. fade in 

On this phase, text is faded in using a precalc colour table. 

Notice that *tabpointer* may point to 3 different set of colours, each of one is composed by 17 values of red, green and blue.

3. fade out

Same logic of *fade in* routine, but with inverted color progression of *tabpointer*

4. clear text

Clear text by writing all zero on all bitplanes in one blit (channel D mode).
This does not involve the stars wich are sprites indeed

[1]: http://corsodiassembler.ramjam.it/index_en.htm
