## Demo 2

![screenshot](https://github.com/fstarred/amiga_playground/blob/master/docs/demo_2.png?raw=true) 

## Premise

Most of the code present on this repository is inspired from [RamJam italian course][1]

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

[1]: http://corsodiassembler.ramjam.it/index_en.htm
