*********************************************
*
*	   STARRED MEDIASOFT
*
*		DEMO 1
*
*		VER 1.1 (2018)
*
*
*********************************************

    SECTION Code,CODE   ; This command will run the below code
                ; on FAST RAM (if enough) or CHIP RAM

DMASET  = %1000001111100000
;         %-----axbcdefghij
;   a: Blitter Nasty
;   x: Enable DMA
;   b: Bitplane DMA (if this isn't set, sprites disappear!)
;   c: Copper DMA
;   d: Blitter DMA
;   e: Sprite DMA
;   f: Disk DMA
;   g-j: Audio 3-0 DMA

INTENA=     %1010000000000000
;           -FEDCBA9876543210

;   F   SET/CLR 0=clear, 1=set bits that are set to 1 below
;   E   INTEN   Enable interrupts below (master toggle)
;   D   EXTER   Level 6 External interrupt
;   C   DSKSYN  Level 5 Disk Sync value found
;   B   RBF Level 5 Receive Buffer Full (serial port)
;   A   AUD3    Level 4 Audio Interrupt channel 3
;   9   AUD2    Level 4 Audio Interrupt channel 2
;   8   AUD1    Level 4 Audio Interrupt channel 1
;   7   AUD0    Level 4 Audio Interrupt channel 0
;   6   BLIT    Level 3 Blitter Interrupt
;   5   VERTB   Level 3 Vertical Blank Interrupt
;   4   COPER   Level 3 Copper Interrupt
;   3   PORTS   Level 2 CIA Interrupt (I/O ports and timers)
;   2   SOFT    Level 1 Software Interrupt
;   1   DSKBLK  Level 1 Disk Block Finished Interuppt
;   0   TBE Level 1 Transmit Buffer Empty Interrupt (serial port)


;;    ---  screen buffer dimensions  ---

w   =320    ; Screen width
h   =256    ; Screen height
bplsize =w*h/8  ; Bitplane size (bytes)
ScrBpl  =w/8    ; Screen line size (bytes)

bpls = 2    ; bitplanes enabled

;wbl = $2c (for copper monitor only)
wbl = 303

BLTWAIT MACRO
    tst $dff002 ;for compatibility
\1
    btst #6,$dff002 ; DMACONR
    bne.s \1
    ENDM

LMOUSE  MACRO
;\1
    btst    #6,$bfe001  ; check L MOUSE btn
    bne.s   \1
    ENDM


RMOUSE  MACRO
;\1
    btst    #2,$dff016  ; check L MOUSE btn
    beq.s   \1
    ENDM

    
*****************************************************************************
    incdir  "dh1:amiga-playground/startup/borchen/"
    include "startup.s" ; 
    incdir  "dh1:amiga-playground/replay/"
    include "pt2.3a_replay_cia.s"   
*****************************************************************************

WAITVB  MACRO
    move.l  $dff004,d0      ; wait
    and.l   #$0001ff00,d0       ; for
    cmp.l   #wbl<<8,d0      ; rasterline 303
    bne.s   \1
    ENDM

WAITVB2 MACRO
    move.l  $dff004,d0      ; wait
    and.l   #$0001ff00,d0       ; for
    cmp.l   #wbl<<8,d0      ; rasterline 303
    beq.s   \1
    ENDM

    
Start:  
;   bra.s   main
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
    
    

    move.w  #DMASET,$dff096     ; enable necessary bits in DMACON
    move.w  #INTENA,$dff09a     ; INTENA
    
    move.l  #COPPERLIST,$dff080 ; COP1LCH set custom copperlist
    moveq   #0,d0
    move.w  d0,$dff088		; COPJMP1 activate copperlist
    move.w  d0,$dff1fc		; FMODE - BPL32

    bsr.w   SetCIAInt
    bsr mt_init
    st  mt_Enable
Main:
    WAITVB  Main

;   ***** COPPER MONITOR
;   move.w  #$F00, $dff180

    bsr.w   sprite_animation
    bsr.w   sprite_move
    bsr.w   move_tb_margin_bars
    bsr.w   move_stars
    bsr.w   show_text   

;   **** COPPER MONITOR
;   move.w  #0, $dff180

Wait    WAITVB2 Wait

WaitRm:
    RMOUSE WaitRm

    LMOUSE Main
    
    BSR mt_end
    BSR ResetCIAInt
    
    rts

    


; this routine animate the sprite
; by scrolling each frame on top, then placing
; the first frame on last position
; doing a continue rotation cycle

ANIMATION_FRAME_DELAY = 5

sprite_frame_offset = $88 ; distance between frames

sprite_animation:
    addq.b  #1,animation_counter ; increase animation_counter
    cmp.b   #ANIMATION_FRAME_DELAY,animation_counter 
    bne.w   do_nothing     ; do not cycle next animation frame
    clr.b   animation_counter
    
    lea FRAMETAB(PC),a0 ; 
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
    
    add.l   #sprite_frame_offset,d0  ; the sprite is $44 bytes ahead    
    addq    #8,a1    ; move SPRITE_POINTERS pointer to next sprite
    move.w  d0,6(a1) ; copy L word of sprite address to pointer
    swap    d0       ; swap the the two words
    move.w  d0,2(a1) ; copy the H word of sprite address to pointer 
    swap    d0
    
    add.l   #sprite_frame_offset,d0  ; the sprite is $44 bytes ahead    
    addq    #8,a1    ; move SPRITE_POINTERS pointer to next sprite
    move.w  d0,6(a1) ; copy L word of sprite address to pointer
    swap    d0       ; swap the the two words
    move.w  d0,2(a1) ; copy the H word of sprite address to pointer 
    ;swap   d0
    
do_nothing:
    rts

animation_counter:
    dc.w    0

; This is the tab of frames which create the sprite animation
; Every time the framex is loaded, it scroll to the end of the tab
; so that the others frames scroll up

FRAMETAB:
    dc.l    frame1
    dc.l    frame2
    dc.l    frame3
    dc.l    frame4
    dc.l    frame5
    dc.l    frame6
    dc.l    frame7
    dc.l    frame8
    

BALL_HEIGHT = 32
BALL_WIDTH = 32



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

    moveq   #0,d2	; clean D2
    
    move.l  FRAMETAB(PC),a1 ; indirizzo sprite 0
    move.w  d4,d0       ; copy Y to D0
    move.w  d3,d1       ; copy X to D1
    move.b  #BALL_HEIGHT,d2     ; copy Height to D2
    bsr.s   generic_sprite_move ; 

    lea sprite_frame_offset(a1),a1  ; move to next sprite
    move.w  d4,d0       ; prepare variables
    move.w  d3,d1
    bsr.s   generic_sprite_move 
    
    lea sprite_frame_offset(a1),a1  ; move to next sprite
    add.w   #BALL_WIDTH/2,d3    ; the last half of the ball
    move.w  d4,d0       
    move.w  d3,d1
    bsr.s   generic_sprite_move 
    
    lea sprite_frame_offset(a1),a1  ; move to next sprite
    move.w  d4,d0       
    move.w  d3,d1
    bsr.s   generic_sprite_move 

.check_right_margin
    cmpi #$11A, (a0)
    bne.s   check_left_margin
    clr.w   SPRITE_PRIORITY ; all sprites over PLAYFIELD
    bra.s   exit_sprite_move

check_left_margin:
    tst (a0)
    bne.s   exit_sprite_move    
    move.w  #$0012, SPRITE_PRIORITY ; sprite couple (1,2) (3,4) behind PLAYFIELD

exit_sprite_move:   
    rts
    

*************************************
*   generic_sprite_move             *
*                                   *
*   <INPUT>                         *
*   A1: SPRITE DATA                 *
*   D0: Y SPRITE COORD              *
*   D1: X SPRITE COORD              *
*   D2: H SPRITE COORD              *
*                                   *
*************************************
generic_sprite_move: 
; vertical position section
    add.w   #$2c,d0     ; add vertical offset to y 

    move.b  d0,(a1)     ; copy Y to VSTART
    btst.l  #8,d0       ; check if Y > $FF
    beq.s   no_vstart_set
    bset.b  #2,3(a1)    ; if Y > $FF, set VSTART bit
    bra.s   check_vstop
no_vstart_set:
    bclr.b  #2,3(a1)    ; if Y <= $FF, clear VSTART bit
check_vstop:
    
    add.w   d2,d0       ; add HEIGHT to Y 
                        ; in order to check final position
    move.b  d0,2(a1)    ; add Y+H to VSTOP
    btst.l  #8,d0       ; check if Y+H > $FF
    beq.s   no_vstop_set
    bset.b  #1,3(a1)    ; set VSTOP bit (Y+H > $FF)
    bra.s   check_x_coord
no_vstop_set:
    bclr.b  #1,3(a1)    ; clear VSTOP bit (Y+H <= $FF)
check_x_coord:

; horizontal position section
    addi.w  #128,d1     ; 128 - sprite center
    btst    #0,d1       ; is odd x position ?
    beq.s   clear_hstart_bit
    bset    #0,3(a1)    ; set HSTART bit (odd position)
    bra.s   translate_hstart_coord

clear_hstart_bit:
    bclr    #0,3(a1)    ; clear HSTART bit (even pos)
translate_hstart_coord:
    lsr.w   #1,d1       ; shift x position to right, translate x
    move.b  d1,1(a1)    ; set x to HSTART byte
    rts

tab_x_pointer:
    dc.l TABX-2
    
tab_y_pointer
    dc.l TABY-1

TABX:
    ; BEG: 0
    ; END: 45
    ; AMPLITUDE: 400

    DC.W    $0000,$0006,$000C,$0012,$0019,$001F,$0025,$002B,$0032,$0038
    DC.W    $003E,$0044,$004A,$0051,$0057,$005D,$0063,$0069,$006F,$0075
    DC.W    $007B,$0081,$0087,$008D,$0093,$0099,$009E,$00A4,$00AA,$00AF
    DC.W    $00B5,$00BB,$00C0,$00C6,$00CB,$00D0,$00D6,$00DB,$00E0,$00E6
    DC.W    $00EB,$00F0,$00F5,$00FA,$00FE,$0103,$0108,$010D,$0111,$0116
    
    ; BEG: 135
    ; END: 180
    ; AMPLITUDE: 400
    
    DC.W    $011A,$0116,$0111,$010D,$0108,$0103,$00FE,$00FA,$00F5,$00F0
    DC.W    $00EB,$00E6,$00E0,$00DB,$00D6,$00D0,$00CB,$00C6,$00C0,$00BB
    DC.W    $00B5,$00AF,$00AA,$00A4,$009E,$0099,$0093,$008D,$0087,$0081
    DC.W    $007B,$0075,$006F,$0069,$0063,$005D,$0057,$0051,$004A,$0044
    DC.W    $003E,$0038,$0032,$002B,$0025,$001F,$0019,$0012,$000C,$0006

ENDTABX
    
TABY:

    ; BEG: 270
    ; END: 345
    ; AMPLITUDE: 127
    DC.B    $81,$82,$82,$84,$85,$87,$8A,$8D,$90,$94,$98,$9D,$A2,$A7,$AD,$B3
    DC.B    $B9,$C0,$C7,$CE


    ; BEG: 195
    ; END: 270
    ; AMPLITUDE: 127
    DC.B    $E0,$DA,$D5,$D0,$CB,$C6,$C1,$BC,$B8,$B3,$AF,$AB,$A7,$A3,$9F,$9C
    DC.B    $98,$95,$93,$90,$8D,$8B,$89,$87,$86,$85,$83,$83,$82,$82


    ; BEG: 90
    ; END: 180
    ; AMPLITUDE: 127
    DC.B    $7F,$7E,$7D,$7C,$7B,$78,$76,$72,$6F,$6B,$66,$61,$5C,$56,$50,$4A
    DC.B    $44,$3D,$36,$2E,$27,$1F,$17,$0F,$07

    ; BEG: 0
    ; END: 90
    ; AMPLITUDE: 127    
    DC.B    $00,$07,$0F,$17,$1F,$27,$2E,$36,$3D,$44,$4A,$50,$56,$5C,$61,$66
    DC.B    $6B,$6F,$72,$76,$78,$7B,$7C,$7D,$7E


ENDTABY

    
**************************************************************
*                                                            *
*   bar scrolling color                                      *
*                                                            *
**************************************************************

BAR_MOVE_VB_DELAY = 3

bar_move_counter:   dc.w    BAR_MOVE_VB_DELAY

move_tb_margin_bars:

    move.w  bar_move_counter, d0
    subq    #1, d0
    tst d0
    bne.s   exit_margin_bar 
    
    move    #BAR_MOVE_VB_DELAY, d0  ; reset counter
    lea TOP_MARGIN_BAR, a0
    bsr.s   rolling_color_hbar
    lea BOTTOM_MARGIN_BAR, a0
    bsr.s   rolling_color_hbar
    
exit_margin_bar:
    move.w  d0, bar_move_counter
    rts

************************************************************************
*	rolling color routine                                          *
*	<INPUT>                                                        *
*	A0 = HORIZONTAL BAR (STARTING FROM FIRST COLOR		       *
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


****************************************************************************
*                                                                          *
*   move stars routine  ripped from (RamJam course)                        *
*                                                                          *
****************************************************************************

STAR_MOVE_DELAY = 2
star_move_progress  dc.w    0


STAR_S_COL = $0444
STAR_M_COL = $0999
STAR_F_COL = $0eee
;STAR_S_COL = $0f00
;STAR_M_COL = $00f0
;STAR_F_COL = $00ff


move_stars:
    addq.b  #1,star_move_progress
    cmpi.b  #STAR_MOVE_DELAY,star_move_progress
    bne exit_move_stars 
    
    lea SPRITEPOINTERS,a1   ; SPRITE pointer
    
    move.l  #STARFIELD_SPRITE,d0        
    addi.w   #8*(5-1),a1         
    move.w  d0,6(a1)    
    swap    d0              
    move.w  d0,2(a1)       

    lea STARFIELD_SPRITE,a0     ; let a0 point to SPRITE

    
; this routine process 3 stars each loop
; 1 - medium speed
; 2 - slow speed
; 3 - fast speed
move_loop:  

;  medium speed star - 2 pixel move

    cmpi.b  #$f0,1(a0)  ; check if star reached end screen
    bne.s   move_star_ms    ; if Z is not set move star
    move.b  #$30,1(A0)  ; if Z is set reset HSTART
move_star_ms:
    addq.b  #1,1(a0)    ; move sprite of 2 pixels
    addq.w  #8,a0       ; point to next sprite

; slow speed star - 1 pixel move

    cmpi.b  #$f0,1(a0)  ; check if star reached end screen
    bne.s   move_star_ls    ; if Z is not set move star
    move.b  #$30,1(a0)  ; if Z is set reset HSTART
move_star_ls:
    bchg    #0,3(a0)    ; check bit 0 SPR0CTL and change it
    beq.s   next_sprite ; if Z is set then go next sprite
    addq.b  #1,1(a0)    ; move slow sprite
next_sprite:
    addq.w  #8,a0       ; point to next sprite

; fast speed star - 4 pixel move

    cmpi.b  #$f0,1(a0)  ; check if star reached end screen
    bne.s   move_star_fs    ; if Z is not set move star
    move.b  #$30,1(a0)  ; if Z is set reset HSTART
move_star_fs:
    addq.b  #2,1(A0)    ; move fast sprite
    addq.w  #8,A0       ; point to next sprite

    cmp.l   #STARFIELD_SPRITE_END,A0    ; check if SPRITE_END reached
    bcs.s   move_loop   ; if lower repeat loop
    clr.b   star_move_progress
exit_move_stars:
    rts         ; end routine
    

***************************************************************************



*******************************
*                             *
*   CONSTANTS                 *
*                             *
*******************************


FONTSET_WIDTH   = 944   ; pixel
FONTSET_HEIGHT  = 16    ; pixel

FONT_WIDTH = 16 ; pixel
FONT_HEIGHT = 16    ; pixel

TEXT_ROWS = 10  
TEXT_COLS = 20-4

TEXT_VOFFSET = (ScrBpl*2*FONT_HEIGHT)*bpls
TEXT_HOFFSET = 4

TEXT_LENGTH = TEXT_COLS*TEXT_ROWS
DELAY_TEXT_BEFORE  = 50*1  ; delay before text is shown
DELAY_TEXT_AFTER   = 50*5  ; defay after  text is shown

text_vb_counter dc.w    DELAY_TEXT_BEFORE      ; vertical blank counter
text_offset_pointer dc.l    TEXT_1  ; address pointer to displayed text
text_message_counter    dc.w    0   ; current text counter
text_loading_progress   dc.w    0   ; blit text progress
text_screen_offset_pointer  dc.l    SCREEN+TEXT_VOFFSET+TEXT_HOFFSET
text_anim_in_progress	dc.b	0
text_phase	dc.b	0

show_text:
    btst    #0,text_anim_in_progress
    bne.s   do_text_animation
    subq.w  #1,text_vb_counter
    tst text_vb_counter
    beq.s   prepare_next_phase
    rts
prepare_next_phase:
    st  text_anim_in_progress
    addq.b  #1,text_phase
    clr.w   text_vb_counter
    moveq   #0,d0
do_text_animation:
    move.b  text_phase,d0	; use routine tab
    ;cmpi.b  #1,d0
    ;beq.s   print_new_text
    ;cmpi.b  #2,d0
    ;beq.w   fade_in_quick
    ;cmpi.b  #3,d0
    ;beq.w   fade_out_quick
    ;cmpi.b  #4,d0
    ;beq.w   clear_text

    add.w    d0,d0
    add.w    d0,d0	

    move.l   rout_table(pc,d0.w), a0
    jmp	     (a0)

    rts

rout_table:
	dc.l	0 ; not assigned	; 0
	dc.l	print_new_text		; 1
	dc.l	fade_in_quick		; 2
	dc.l	fade_out_quick		; 3
	dc.l	clear_text		; 4

    
print_new_text: 
    move.l  text_offset_pointer(PC), a0
    move.l  text_screen_offset_pointer(PC), a3
    move.w  text_loading_progress(PC), d1
    bsr.s   print_text
    addq    #1, d1  ; next row pointer
    cmpi.w  #TEXT_ROWS, d1  ; check if end of text is reached
    bne.s   exit_print_new_text 
.end_text_reached:
    ; *******
    ; uncomment code below if TEXT_ROWS < 10
    ;addi   #20*(10-TEXT_ROWS), a0
    ; *******
    cmpi.l  #END_TEXT, a0
    bne.s   no_all_messages_finished
.reset_to_first_message
    lea TEXT_1, a0  ; reset text_offset_pointer to TEXT_1
no_all_messages_finished:
    lea SCREEN+TEXT_VOFFSET+TEXT_HOFFSET, a3 ; reset bitplane pointer to VOFFSET
    moveq   #0,d1
    bclr    #0,text_anim_in_progress    
    move.w  #1,text_vb_counter
exit_print_new_text:
    move.l  a0, text_offset_pointer
    move.l  a3, text_screen_offset_pointer
    move.w  d1, text_loading_progress
    rts
    
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
    
    move.l  #$09f00000,$dff040  ;A->D copy, no shifts, ascending mode
    move.l  #$ffffffff,$dff044  ;no masking of first/last word
        
    move.w  #(FONTSET_WIDTH-FONT_WIDTH)/8,$dff064   ;A modulo=bytes to skip between lines
    move.w  #ScrBpl-FONT_WIDTH/8,$dff066    ;D modulo=bytes to skip between lines
    move.l  a2,$dff050  ;source graphic top left corner
    move.l  a3,$dff054  ;destination top left corner
    move.w  #(bpls*FONTSET_HEIGHT*64)+FONT_WIDTH/16,$dff058 ;rectangle size, starts blit

    addq.w  #FONT_WIDTH/8,a3        ; point to next column (16 pixel)

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

TEXT_1:     ;         11111111112
	    ;12345678901234567890
    dc.b    'HI ALL AMIGAS!!!****' ; 1
    dc.b    '                ****' ; 2
    dc.b    '   THIS IS THE  ****' ; 3
    dc.b    ' FIRST LITTLE   ****' ; 4
    dc.b    '   DEMO BY      ****' ; 5
    dc.b    '                ****' ; 6
    dc.b    '     STARRED    ****' ; 7
    dc.b    '    MEDIASOFT   ****' ; 8
    dc.b    '                ****' ; 9
    dc.b    '                ****' ; 10

TEXT_2:     ;         11111111112
	    ;12345678901234567890
    dc.b    '                ****' ; 1
    dc.b    '    YOU MAY     ****' ; 2
    dc.b    '   FOLLOW SMS   ****' ; 3
    dc.b    '   PROJECT BY   ****' ; 4
    dc.b    '  SEARCHING FOR ****' ; 5
    dc.b    '      USER      ****' ; 6
    dc.b    '   "FSTARRED"   ****' ; 7
    dc.b    '                ****' ; 8
    dc.b    '   ON GITHUB    ****' ; 9
    dc.b    '                ****' ; 10

TEXT_3:     ;         11111111112
	    ;12345678901234567890
    dc.b    '                ****' ; 1
    dc.b    '                ****' ; 2
    dc.b    '                ****' ; 3
    dc.b    '  THE SONG YOU  ****' ; 4
    dc.b    'ARE LISTENING IS****' ; 5
    dc.b    '    CALLED      ****' ; 6
    dc.b    '                ****' ; 7
    dc.b    '   TOWARDS      ****' ; 8
    dc.b    '    A NEW       ****' ; 9
    dc.b    '    DECADE      ****' ; 10

TEXT_4:     ;         11111111112
	    ;12345678901234567890
    dc.b    '                ****' ; 1
    dc.b    '   IT WAS MADE  ****' ; 2
    dc.b    '  USING RENOISE ****' ; 3
    dc.b    '      AND       ****' ; 4
    dc.b    '    XRNS2XMOD   ****' ; 5
    dc.b    '     A TOOL     ****' ; 6
    dc.b    '      THAT      ****' ; 7
    dc.b    '    CONVERT     ****' ; 8
    dc.b    '   MODERN XRNS  ****' ; 9
    dc.b    '   TO AMIGA MOD ****' ; 10

TEXT_5:     ;         11111111112
	    ;12345678901234567890
    dc.b    '     WELL,      ****' ; 1
    dc.b    ' THE MAIN REASON****' ; 2
    dc.b    '  BEHIND THIS   ****' ; 3
    dc.b    '  IS PROTRACKER ****' ; 4
    dc.b    ' GUI MAY LOOK   ****' ; 5
    dc.b    'A BIT "OUTDATED"****' ; 6
    dc.b    ' THESE DAYS...  ****' ; 7
    dc.b    '                ****' ; 8
    dc.b    '                ****' ; 9
    dc.b    '                ****' ; 10

TEXT_6:     ;         11111111112
	    ;12345678901234567890
    dc.b    '                ****' ; 1
    dc.b    '                ****' ; 2
    dc.b    '   HOWEVER...   ****' ; 3
    dc.b    '                ****' ; 4
    dc.b    '                ****' ; 5
    dc.b    '                ****' ; 6
    dc.b    '                ****' ; 7
    dc.b    '                ****' ; 8
    dc.b    '                ****' ; 9
    dc.b    '                ****' ; 10
    
TEXT_7:     ;         11111111112
	    ;12345678901234567890
    dc.b    '                ****' ; 1
    dc.b    '                ****' ; 2
    dc.b    ' I WANT TO GREET****' ; 3
    dc.b    '    ALL THE     ****' ; 4
    dc.b    '   EAB   FORUM  ****' ; 5
    dc.b    '   USERS WHOSE  ****' ; 6
    dc.b    '  EFFORT HELPED ****' ; 7
    dc.b    '     ME A LOT   ****' ; 8
    dc.b    '                ****' ; 9
    dc.b    '                ****' ; 10
    

TEXT_8:     ;         11111111112
	    ;12345678901234567890
    dc.b    ' A SPECIAL      ****' ; 1
    dc.b    ' GREETINGS TO:  ****' ; 2
    dc.b    '                ****' ; 3
    dc.b    'CHIP, OZZYBOSHI,****' ; 4
    dc.b    '  AMIGASYSTEM,  ****' ; 5
    dc.b    '   ROSS AND ... ****' ; 6
    dc.b    ' MANY OTHERS !! ****' ; 7
    dc.b    '                ****' ; 8
    dc.b    '                ****' ; 9
    dc.b    '                ****' ; 10

TEXT_9:     ;         11111111112
	    ;12345678901234567890
    dc.b    '                ****' ; 1
    dc.b    '  ALSO I WANT   ****' ; 2
    dc.b    '  TO SAY MANY   ****' ; 3
    dc.b    '   THANKS TO    ****' ; 4
    dc.b    '   SLAMY A.Z.   ****' ; 5
    dc.b    '     FOR HIS    ****' ; 6
    dc.b    ' CONTRIBUTE AND ****' ; 7
    dc.b    '  GREAT EFFORT  ****' ; 8
    dc.b    '  ON XRNS2XMOD  ****' ; 9
    dc.b    '                ****' ; 10
    
TEXT_10:    ;         11111111112
	    ;12345678901234567890
    dc.b    '                ****' ; 1
    dc.b    ' GRAPHICS BY:   ****' ; 2
    dc.b    '    FSTARRED    ****' ; 3
    dc.b    '                ****' ; 4
    dc.b    ' MUSIC BY:      ****' ; 5
    dc.b    '    FSTARRED    ****' ; 6
    dc.b    '                ****' ; 7
    dc.b    ' CODE BY:       ****' ; 8
    dc.b    '    FSTARRED    ****' ; 9
    dc.b    '                ****' ; 10

TEXT_11:    ;         11111111112
	    ;12345678901234567890
    dc.b    '                ****' ; 1
    dc.b    '  STARRED       ****' ; 2
    dc.b    '     MEDIASOFT  ****' ; 3
    dc.b    '                ****' ; 4
    dc.b    '      2018      ****' ; 5
    dc.b    '                ****' ; 6
    dc.b    '       ITALY    ****' ; 7
    dc.b    '                ****' ; 8
    dc.b    '                ****' ; 9
    dc.b    '                ****' ; 10
END_TEXT
    
;**************************************

fade_counter    dc.w    FADE_STEP_COUNT
FADE_STEP_COUNT = 17
AVAILABLE_COLORS = 3

tabpointer:
    dc.l    TAB_COLOR_1
TAB_COLOR_1:
    dc.w    $0, $0, $11, $12, $23, $23, $134, $135, $146, $156, $157, $268, $269, $279, $27a, $28b, $39c        ; blue
    dc.w    $0, $0, $110, $121, $231, $241, $352, $362, $473, $483, $593, $5a4, $6b4, $6c4, $7d5, $7e5, $8f6    ; green
    dc.w    $0, $0, $100, $211, $311, $421, $522, $632, $733, $833, $943, $a44, $b54, $c54, $d65, $e65, $f76    ; red
ETAB_COLOR_1
TAB_COLOR_2:
    dc.w    $0, $0, $1, $2, $13, $13, $114, $125, $126, $126, $137, $238, $239, $249, $24a, $24b, $35c
    dc.w    $0, $0, $10, $20, $120, $130, $140, $140, $251, $261, $261, $271, $381, $381, $391, $3a1, $4b2      
    dc.w    $0, $0, $100, $200, $200, $300, $410, $410, $511, $611, $611, $721, $821, $821, $921, $a21, $b32
TAB_COLOR_3:
    dc.w    $0, $0, $1, $1, $2, $2, $3, $3, $104, $105, $105, $106, $106, $107, $107, $108, $219
    dc.w    $0, $0, $0, $10, $10, $20, $20, $30, $130, $130, $140, $140, $150, $150, $160, $160, $270
    dc.w    $0, $0, $0, $100, $100, $200, $200, $300, $300, $300, $400, $400, $500, $500, $600, $600, $700

fade_in_quick:
    moveq   #0,d0
    move.w  fade_counter, d0
    subq    #1,d0       
    move.l  tabpointer(PC),a0   
    lea TEXT_COLORS+2,a1
    move.w  (a0),(a1)
    ; distance between TAB_COLOR_1 and TAB_COLOR_2
    ; 2 bytes * AVAILABLE_COLORS*FADE_STEP_COUNT
    move.w  2*AVAILABLE_COLORS*FADE_STEP_COUNT(a0),4(a1) 
    ; same as above, skip also TAB_COLOR_2
    move.w  2*2*AVAILABLE_COLORS*FADE_STEP_COUNT(a0),8(a1) ; distance between TAB_COLOR_1 and TAB_COLOR_3
    move.w  d0, fade_counter    
    tst d0
    beq.s   end_fade_in_quick
    addq.l  #2, tabpointer
    rts
end_fade_in_quick:
    move.w  #FADE_STEP_COUNT, fade_counter  ; reset fade counter
    bclr    #0,text_anim_in_progress
    move.w  #DELAY_TEXT_AFTER, text_vb_counter
    rts
    

;TAB_COLOR_SIZE = 3
    
;fade_in:
;   cmp.w   #17,fade_phase
;   beq.s   end_fade_in
;   moveq   #0,d0
;   move.w  fade_phase(PC),d0
;   moveq   #TAB_COLOR_SIZE-1,d7        ; 
;   lea TabColoriPic(PC),a0 
;   lea TEXT_COLORS+2,a1        
;   bsr.s   Fade
;   addq.w  #1,fade_phase
;   rts
;end_fade_in:
;   bclr    #0,text_anim_in_progress    
;   rts


*****************************************************************************
*       Fade routine (take from RamJam course)                              *
* Input:                                                                    *
*                                                                           *
* d7 = colors number - 1                                                    *
* a0 = address colour table                                                 *
* a1 = address of the copperlist colour                                     *
* d0 = fade phase                                                           *
*                                                                           * 
*****************************************************************************

;Fade:
;;  BLUE value
;
;   move.w  (a0),d4     ; table color in D4
;   and.w   #$00f,d4    ; get blue value
;   mulu.w  d0,d4       ; mul by the current phase
;   asr.w   #4,d4       ; div by 16
;   and.w   #$00f,d4    ; get blue value
;   move.w  d4,d5       ; save blue value in d5
;
;;  GREEN value
;
;   move.w  (a0),d4     ; table color in d4
;   and.w   #$0f0,d4    ; get green value
;   mulu.w  d0,d4       ; mul by the current phase
;   asr.w   #4,d4       ; div by 16
;   and.w   #$0f0,d4    ; get green value
;   or.w    d4,d5       ; save blue+green value in d5
;
;;  RED value
;
;   move.w  (a0)+,d4    ; table color in d4 and point to next value
;   and.w   #$f00,d4    ; get red value
;   mulu.w  d0,d4       ; mul by the current phase
;   asr.w   #4,d4       ; div by 16
;   and.w   #$f00,d4    ; get red value
;   or.w    d4,d5       ; save blue+green+red value in d5
;
;   move.w  d5,(a1)     ; put the final value in a1
;   addq.w  #4,a1       ; go to next colour in the copperlist
;   dbra    d7,fade     ; do loop for all color table
;   rts

fade_out_quick:
    moveq   #0,d0
    move.w  fade_counter, d0
    subq    #1,d0       
    move.l  tabpointer(PC),a0
    lea TEXT_COLORS+2,a1        
    move.w  (a0),(a1)
    move.w  2*AVAILABLE_COLORS*FADE_STEP_COUNT(a0),4(a1) ; distance between TAB_COLOR_1 and TAB_COLOR_2
    move.w  2*2*AVAILABLE_COLORS*FADE_STEP_COUNT(a0),8(a1) ; distance between TAB_COLOR_1 and TAB_COLOR_3
    move.w  d0, fade_counter    
    tst d0
    beq.s   end_fade_out_quick
    subq.l  #2, tabpointer
    rts
end_fade_out_quick: 
    move.w  #FADE_STEP_COUNT,fade_counter
    move.w  #1,text_vb_counter
    bclr    #0,text_anim_in_progress
    
    ; end of tab color reached ?
    cmpi.l  #ETAB_COLOR_1-(FADE_STEP_COUNT*2),tabpointer
    bne.s   no_reset_tabpointer
    move.l  #TAB_COLOR_1, tabpointer    ; reset tab_pointer
    bra.s   exit_fade_out_quick
no_reset_tabpointer:    ; go next TAB_COLOR
    add.l   #FADE_STEP_COUNT*2, tabpointer  ; FADE_STEP_COUNT*2 bytes
exit_fade_out_quick:
    rts

clear_text:
    BLTWAIT BWT2
        
    move.w  #$0100,$dff040   ; BLTCON0: enable destination D (only write)
    move.w  #$0000,$dff042   ; BLTCON1: disabled
    move.l  #SCREEN+TEXT_VOFFSET,$dff054     ; BLTDPT: destination 
    move.w  #ScrBpl-(FONT_WIDTH/8*TEXT_COLS),$dff066     ; BLTDMOD: 
    move.w  #(bpls*TEXT_ROWS*(FONT_HEIGHT+1)*64)+FONT_WIDTH/8*TEXT_COLS/2,$dff058 ; BLTSIZE: rectangle size 
.next_phase
    bclr    #0,text_anim_in_progress
    clr.b   text_phase
    move.w  #DELAY_TEXT_BEFORE, text_vb_counter
    rts

;TabColoriPic:
;   dc.w $039c,$035c,$0219

    
;fade_out:
;   tst.w   fade_phase  ; 
;   beq.s   end_fade_out
;   subq.w  #1,fade_phase   ; 
;   moveq   #0,d0
;   move.w  fade_phase(PC),d0
;   moveq   #TAB_COLOR_SIZE-1,d7
;   lea TabColoriPic(PC),a0 
;   lea TEXT_COLORS+2,a1        
;   bsr.w   Fade
;   rts
;   
;end_fade_out:
;   ; clear text routine
;   BLTWAIT BWT3
;       
;   move.w  #$0100,$dff040   ; BLTCON0: enable destination D (only write)
;   move.w  #$0000,$dff042   ; BLTCON1: disabled
;   move.l  #SCREEN+TEXT_VOFFSET,$dff054     ; BLTDPT: destination 
;   move.w  #ScrBpl-(FONT_WIDTH/8*TEXT_COLS),$dff066     ; BLTDMOD: 
;   move.w  #(bpls*TEXT_ROWS*(FONT_HEIGHT+1)*64)+FONT_WIDTH/8*TEXT_COLS/2,$dff058 ; BLTSIZE: rectangle size 
;   
;   bclr    #0,text_anim_in_progress
;   clr.b   text_phase
;   cmp.b   #TEXT_COUNT, text_message_counter
;   bne.s   exit_fade_out
;.reset_text_loop
;   clr.l   text_offset_pointer
;   clr.b   text_message_counter
;exit_fade_out: 
;   rts


*****************************************************************************

    SECTION Copper,DATA_C

COPPERLIST:
SPRITEPOINTERS:
    dc.w    $120,$0000,$122,$0000,$124,$0000,$126,$0000,$128,$0000  ; clear sprite pointers
    dc.w    $12a,$0000,$12c,$0000,$12e,$0000,$130,$0000,$132,$0000  ; clear sprite pointers
    dc.w    $134,$0000,$136,$0000,$138,$0000,$13a,$0000,$13c,$0000  ; clear sprite pointers
    dc.w    $13e,$0000

    dc.w    $8E,$2c81   ; DiwStrt
    dc.w    $90,$2cc1   ; DiwStop
    dc.w    $92,$38     ; DdfStart
    dc.w    $94,$d0     ; DdfStop
    dc.w    $102,0      ; BplCon1
    dc.w    $104,0      ; BplCon2
    dc.w    $108,ScrBpl*(bpls-1)    ; Bpl1Mod (interleaved) 
    dc.w    $10a,ScrBpl*(bpls-1)    ; Bpl2Mod (interleaved)

    dc.w    $100,bpls*$1000+$200    ; bplcon0 - bitplane lowres

BPLPOINTERS:
    dc.w $e0,$0000,$e2,$0000    ;bitplane 1
    dc.w $e4,$0000,$e6,$0000    ;bitplane 2
    
    ; ball sprite color palette (from 17 to 31)
    
    dc.w $01a2,$0887,$01a4,$0900,$01a6,$0555
    dc.w $01a8,$0600,$01aa,$0955,$01ac,$0222,$01ae,$0ed4
    dc.w $01b0,$0e01,$01b2,$0a69,$01b4,$0eaa,$01b6,$0eee
    dc.w $01b8,$0e54,$01ba,$0e6c,$01bc,$0aaa,$01be,$0777


    
;CODE      |    000    |    001    |    010    |    011    |    100    |
;----------------------------------------------------------------------------
;PRI. MAX  | PLAYFIELD | COUPLE 1  | COUPLE 1  | COUPLE 1  | COUPLE 1  |
;          | COUPLE 1  | PLAYFIELD | COUPLE 2  | COUPLE 2  | COUPLE 2  |
;          | COUPLE 2  | COUPLE 2  | PLAYFIELD | COUPLE 3  | COUPLE 3  |
;          | COUPLE 3  | COUPLE 3  | COUPLE 3  | PLAYFIELD | COUPLE 4  |
;PRI. MIN  | COUPLE 4  | COUPLE 4  | COUPLE 4  | COUPLE 4  | PLAYFIELD |
    
    dc.w    $104 

SPRITE_PRIORITY:
    dc.w    $0012 ; sprite couple 1,2 over playfield 1  
                 ; code 010 twice (%010010%)
    
    dc.w $0180,$0000

    dc.w $4207,$fffe
TOP_MARGIN_BAR:
    dc.w $0180,$0032
    dc.w $4217,$fffe
    dc.w $0180,$0042
    dc.w $4227,$fffe
    dc.w $0180,$0052
    dc.w $4237,$fffe
    dc.w $0180,$0062
    dc.w $4247,$fffe
    dc.w $0180,$0082
    dc.w $4257,$fffe
    dc.w $0180,$0592
    dc.w $4267,$fffe
    dc.w $0180,$09a2
    dc.w $4277,$fffe
    dc.w $0180,$0ac2
    dc.w $4287,$fffe
    dc.w $0180,$09a2
    dc.w $4297,$fffe
    dc.w $0180,$0592
    dc.w $42a7,$fffe
    dc.w $0180,$0082
    dc.w $42b7,$fffe
    dc.w $0180,$0062
    dc.w $42c7,$fffe
    dc.w $0180,$0052
    dc.w $42d7,$fffe
    dc.w $0180,$0042
    dc.w $42e7,$fffe
    dc.w $0180,$0032
ETOP_MARGIN_BAR:
    dc.w $4307,$fffe
    dc.w $0180,$0000



TEXT_COLORS:
    dc.w $0182,$0000
    dc.w $0184,$0000
    dc.w $0186,$0000

;   GREEN
;   dc.w $0182,$08f6
;   dc.w $0184,$04b2
;   dc.w $0186,$0270

;   RED
;   dc.w $0182,$0f76
;   dc.w $0184,$0b32
;   dc.w $0186,$0700



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
    dc.w $01b2,STAR_S_COL   ; slow
    dc.w $5d07,$fffe
    dc.w $01b2,STAR_F_COL   ; fast
    dc.w $5f07,$fffe
    dc.w $01b2,STAR_M_COL   ; medium (col17 sprite a)
    dc.w $6107,$fffe
    dc.w $01b2,STAR_S_COL   ; slow
    dc.w $6307,$fffe
    dc.w $01b2,STAR_F_COL   ; fast
    dc.w $6507,$fffe
    dc.w $01b2,STAR_M_COL   ; medium (col17 sprite a)
    dc.w $6707,$fffe
    dc.w $01b2,STAR_S_COL   ; slow
    dc.w $6907,$fffe
    dc.w $01b2,STAR_F_COL   ; fast
    dc.w $6b07,$fffe
    dc.w $01b2,STAR_M_COL   ; medium (col17 sprite a)
    dc.w $6d07,$fffe
    dc.w $01b2,STAR_S_COL   ; slow
    dc.w $6f07,$fffe
    dc.w $01b2,STAR_F_COL   ; fast
    dc.w $7107,$fffe
    dc.w $01b2,STAR_M_COL   ; medium (col17 sprite a)
    dc.w $7307,$fffe
    dc.w $01b2,STAR_S_COL   ; slow
    dc.w $7507,$fffe
    dc.w $01b2,STAR_F_COL   ; fast
    dc.w $7707,$fffe
    dc.w $01b2,STAR_M_COL   ; medium (col17 sprite a)
    dc.w $7907,$fffe
    dc.w $01b2,STAR_S_COL   ; slow
    dc.w $7b07,$fffe
    dc.w $01b2,STAR_F_COL   ; fast
    dc.w $7d07,$fffe
    dc.w $01b2,STAR_M_COL   ; medium (col17 sprite a)
    dc.w $7f07,$fffe
    dc.w $01b2,STAR_S_COL   ; slow
    dc.w $8107,$fffe
    dc.w $01b2,STAR_F_COL   ; fast
    dc.w $8307,$fffe
    dc.w $01b2,STAR_M_COL   ; medium (col17 sprite a)
    dc.w $8507,$fffe
    dc.w $01b2,STAR_S_COL   ; slow
    dc.w $8707,$fffe
    dc.w $01b2,STAR_F_COL   ; fast
    dc.w $8907,$fffe
    dc.w $01b2,STAR_M_COL   ; medium (col17 sprite a)
    dc.w $8b07,$fffe
    dc.w $01b2,STAR_S_COL   ; slow
    dc.w $8d07,$fffe
    dc.w $01b2,STAR_F_COL   ; fast
    dc.w $8f07,$fffe
    dc.w $01b2,STAR_M_COL   ; medium (col17 sprite a)
    dc.w $9107,$fffe
    dc.w $01b2,STAR_S_COL   ; slow
    dc.w $9307,$fffe
    dc.w $01b2,STAR_F_COL   ; fast
    dc.w $9507,$fffe
    dc.w $01b2,STAR_M_COL   ; medium (col17 sprite a)
    dc.w $9707,$fffe
    dc.w $01b2,STAR_S_COL   ; slow
    dc.w $9907,$fffe
    dc.w $01b2,STAR_F_COL   ; fast
    dc.w $9b07,$fffe
    dc.w $01b2,STAR_M_COL   ; medium (col17 sprite a)
    dc.w $9d07,$fffe
    dc.w $01b2,STAR_S_COL   ; slow
    dc.w $9f07,$fffe
    dc.w $01b2,STAR_F_COL   ; fast
    dc.w $a107,$fffe
    dc.w $01b2,STAR_M_COL   ; medium (col17 sprite a)
    dc.w $a307,$fffe
    dc.w $01b2,STAR_S_COL   ; slow
    dc.w $a507,$fffe
    dc.w $01b2,STAR_F_COL   ; fast
    dc.w $a707,$fffe
    dc.w $01b2,STAR_M_COL   ; medium (col17 sprite a)
    dc.w $a907,$fffe
    dc.w $01b2,STAR_S_COL   ; slow
    dc.w $ab07,$fffe
    dc.w $01b2,STAR_F_COL   ; fast
    dc.w $ad07,$fffe
    dc.w $01b2,STAR_M_COL   ; medium (col17 sprite a)
    dc.w $af07,$fffe
    dc.w $01b2,STAR_S_COL   ; slow
    dc.w $b107,$fffe
    dc.w $01b2,STAR_F_COL   ; fast
    dc.w $b307,$fffe
    dc.w $01b2,STAR_M_COL   ; medium (col17 sprite a)
    dc.w $b507,$fffe
    dc.w $01b2,STAR_S_COL   ; slow
    dc.w $b707,$fffe
    dc.w $01b2,STAR_F_COL   ; fast
    dc.w $b907,$fffe
    dc.w $01b2,STAR_M_COL   ; medium (col17 sprite a)
    dc.w $bb07,$fffe
    dc.w $01b2,STAR_S_COL   ; slow
    dc.w $bd07,$fffe
    dc.w $01b2,STAR_F_COL   ; fast
    dc.w $bf07,$fffe
    dc.w $01b2,STAR_M_COL   ; medium (col17 sprite a)
    dc.w $c107,$fffe
    dc.w $01b2,STAR_S_COL   ; slow
    dc.w $c307,$fffe
    dc.w $01b2,STAR_F_COL   ; fast
    dc.w $c607,$fffe
    dc.w $01b2,STAR_M_COL   ; medium (col17 sprite a)
    dc.w $c807,$fffe
    dc.w $01b2,STAR_S_COL   ; slow
    dc.w $ca07,$fffe
    dc.w $01b2,STAR_F_COL   ; fast
    dc.w $cb07,$fffe
    dc.w $01b2,STAR_M_COL   ; medium (col17 sprite a)
    dc.w $cd07,$fffe
    dc.w $01b2,STAR_S_COL   ; slow
    dc.w $ab07,$fffe
    dc.w $01b2,STAR_F_COL   ; fast
    dc.w $d107,$fffe
    dc.w $01b2,STAR_M_COL   ; medium (col17 sprite a)
    dc.w $d307,$fffe
    dc.w $01b2,STAR_S_COL   ; slow
    dc.w $d507,$fffe
    dc.w $01b2,STAR_F_COL   ; fast
    dc.w $d707,$fffe
    dc.w $01b2,STAR_M_COL   ; medium (col17 sprite a)
    dc.w $d907,$fffe
    dc.w $01b2,STAR_S_COL   ; slow
    dc.w $db07,$fffe
    dc.w $01b2,STAR_F_COL   ; fast
    dc.w $dd07,$fffe
    dc.w $01b2,STAR_M_COL   ; medium (col17 sprite a)
    dc.w $df07,$fffe
    dc.w $01b2,STAR_S_COL   ; slow
    dc.w $e107,$fffe
    dc.w $01b2,STAR_F_COL   ; fast
    dc.w $e307,$fffe
    dc.w $01b2,STAR_M_COL   ; medium (col17 sprite a)
    dc.w $e507,$fffe
    dc.w $01b2,STAR_S_COL   ; slow
    dc.w $e707,$fffe
    dc.w $01b2,STAR_F_COL   ; fast
    dc.w $e907,$fffe
    dc.w $01b2,STAR_M_COL   ; medium (col17 sprite a)
    dc.w $eb07,$fffe
    dc.w $01b2,STAR_S_COL   ; slow
    dc.w $ed07,$fffe
    dc.w $01b2,STAR_F_COL   ; fast
    dc.w $ef07,$fffe
    dc.w $01b2,STAR_M_COL   ; medium (col17 sprite a)
    dc.w $f107,$fffe
    dc.w $01b2,STAR_S_COL   ; slow
    dc.w $f307,$fffe
    dc.w $01b2,STAR_F_COL   ; fast
    dc.w $f507,$fffe
    dc.w $01b2,STAR_M_COL   ; medium (col17 sprite a)
    dc.w $f707,$fffe
    dc.w $01b2,STAR_S_COL   ; slow
    dc.w $f907,$fffe
    dc.w $01b2,STAR_F_COL   ; fast
    dc.w $fb07,$fffe
    dc.w $01b2,STAR_M_COL   ; medium (col17 sprite a)
    dc.w $fd07,$fffe
    dc.w $01b2,STAR_S_COL   ; slow
    dc.w $ff07,$fffe
    
    dc.w $ffdf,$fffe
    
    dc.w $01b2,STAR_F_COL   ; fast
    dc.w $0107,$fffe
    dc.w $01b2,STAR_M_COL   ; medium (col17 sprite a)
    dc.w $0307,$fffe
    dc.w $01b2,STAR_S_COL   ; slow
    dc.w $0507,$fffe
    dc.w $01b2,STAR_F_COL   ; fast
    ; end star color copper set

    dc.w $1207,$fffe
BOTTOM_MARGIN_BAR:
    dc.w $0180,$0302
    dc.w $1217,$fffe
    dc.w $0180,$0402
    dc.w $1227,$fffe
    dc.w $0180,$0502
    dc.w $1237,$fffe
    dc.w $0180,$0602
    dc.w $1247,$fffe
    dc.w $0180,$0802
    dc.w $1257,$fffe
    dc.w $0180,$0952
    dc.w $1267,$fffe
    dc.w $0180,$0a92
    dc.w $1277,$fffe
    dc.w $0180,$0ca2
    dc.w $1287,$fffe
    dc.w $0180,$0a92
    dc.w $1297,$fffe
    dc.w $0180,$0952
    dc.w $12a7,$fffe
    dc.w $0180,$0802
    dc.w $12b7,$fffe
    dc.w $0180,$0602
    dc.w $12c7,$fffe
    dc.w $0180,$0502
    dc.w $12d7,$fffe
    dc.w $0180,$0402
    dc.w $12e7,$fffe
    dc.w $0180,$0302
EBOTTOM_MARGIN_BAR:
    dc.w $1307,$fffe
    dc.w $0180,$0000


;   dc.w $1207,$fffe
;   dc.w $0180,$00f2
;   dc.w $1307,$fffe
;   dc.w $0180,$0000
    
    
    dc.w    $FFFF,$FFFE ; End of copperlist

    
*****************************************************************************

    SECTION Data,DATA_C



    
; each sprite is composed by 4 words (8 bytes)
; example: $307A,$3100,$1000,$0000
; STR0POS   VSTART  $30
; STR0POS   HSTART  $7A
; SPR0CTL   VSTOP   $31
; SPR0CTL   bit 7-0 $00
;
; SPRITE DATA:
; $1000 $0000   where 1 is the pixel of the start
;
; be aware the sprite beyond $FF vertical position
; must have SPR0CTL bit 2 and 1 set ($06 or %0110) 

    
STARFIELD_SPRITE:
    ;dc.w    $307A,$3100,$1000,$0000,$3220,$3300,$1000,$0000
    ;dc.w    $34C0,$3500,$1000,$0000,$3650,$3700,$1000,$0000
    ;dc.w    $3842,$3900,$1000,$0000,$3A6D,$3B00,$1000,$0000
    ;dc.w    $3CA2,$3D00,$1000,$0000,$3E9C,$3F00,$1000,$0000
    ;dc.w    $40DA,$4100,$1000,$0000,$4243,$4300,$1000,$0000
    ;dc.w    $445A,$4500,$1000,$0000,$4615,$4700,$1000,$0000
    ;dc.w    $4845,$4900,$1000,$0000,$4A68,$4B00,$1000,$0000
    ;dc.w    $4CB8,$4D00,$1000,$0000,$4EB4,$4F00,$1000,$0000
    ;dc.w    $5082,$5100,$1000,$0000,$5292,$5300,$1000,$0000
    
    dc.w    $54D0,$5500,$1000,$0000,$56D3,$5700,$1000,$0000
    dc.w    $58F0,$5900,$1000,$0000,$5A6A,$5B00,$1000,$0000
    dc.w    $5CA5,$5D00,$1000,$0000,$5E46,$5F00,$1000,$0000
    dc.w    $606A,$6100,$1000,$0000,$62A0,$6300,$1000,$0000
    dc.w    $64D7,$6500,$1000,$0000,$667C,$6700,$1000,$0000
    dc.w    $68C4,$6900,$1000,$0000,$6AC0,$6B00,$1000,$0000
    dc.w    $6C4A,$6D00,$1000,$0000,$6EDA,$6F00,$1000,$0000
    dc.w    $70D7,$7100,$1000,$0000,$7243,$7300,$1000,$0000
    dc.w    $74A2,$7500,$1000,$0000,$7699,$7700,$1000,$0000
    dc.w    $7872,$7900,$1000,$0000,$7A77,$7B00,$1000,$0000
    dc.w    $7CC2,$7D00,$1000,$0000,$7E56,$7F00,$1000,$0000
    dc.w    $805A,$8100,$1000,$0000,$82CC,$8300,$1000,$0000
    dc.w    $848F,$8500,$1000,$0000,$8688,$8700,$1000,$0000
    dc.w    $88B9,$8900,$1000,$0000,$8AAF,$8B00,$1000,$0000
    dc.w    $8C48,$8D00,$1000,$0000,$8E68,$8F00,$1000,$0000
    dc.w    $90DF,$9100,$1000,$0000,$924F,$9300,$1000,$0000
    dc.w    $9424,$9500,$1000,$0000,$96D7,$9700,$1000,$0000
    dc.w    $9859,$9900,$1000,$0000,$9A4F,$9B00,$1000,$0000
    dc.w    $9C4A,$9D00,$1000,$0000,$9E5C,$9F00,$1000,$0000
    dc.w    $A046,$A100,$1000,$0000,$A2A6,$A300,$1000,$0000
    dc.w    $A423,$A500,$1000,$0000,$A6FA,$A700,$1000,$0000
    dc.w    $A86C,$A900,$1000,$0000,$AA44,$AB00,$1000,$0000
    dc.w    $AC88,$AD00,$1000,$0000,$AE9A,$AF00,$1000,$0000
    dc.w    $B06C,$B100,$1000,$0000,$B2D4,$B300,$1000,$0000
    dc.w    $B42A,$B500,$1000,$0000,$B636,$B700,$1000,$0000
    dc.w    $B875,$B900,$1000,$0000,$BA89,$BB00,$1000,$0000
    dc.w    $BC45,$BD00,$1000,$0000,$BE24,$BF00,$1000,$0000
    dc.w    $C0A3,$C100,$1000,$0000,$C29D,$C300,$1000,$0000     
    dc.w    $C43F,$C500,$1000,$0000,$C634,$C700,$1000,$0000     
    dc.w    $C87C,$C900,$1000,$0000,$CA1D,$CB00,$1000,$0000     
    dc.w    $CC6B,$CD00,$1000,$0000,$CEAC,$CF00,$1000,$0000
    dc.w    $D0CF,$D100,$1000,$0000,$D2FF,$D300,$1000,$0000     
    dc.w    $D4A5,$D500,$1000,$0000,$D6D6,$D700,$1000,$0000     
    dc.w    $D8EF,$D900,$1000,$0000,$DAE1,$DB00,$1000,$0000     
    dc.w    $DCD9,$DD00,$1000,$0000,$DEA6,$DF00,$1000,$0000     
    dc.w    $E055,$E100,$1000,$0000,$E237,$E300,$1000,$0000     
    dc.w    $E47D,$E500,$1000,$0000,$E62E,$E700,$1000,$0000
    dc.w    $E8AF,$E900,$1000,$0000,$EA46,$EB00,$1000,$0000
    dc.w    $EC65,$ED00,$1000,$0000,$EE87,$EF00,$1000,$0000
    dc.w    $F0D4,$F100,$1000,$0000,$F2F5,$F300,$1000,$0000
    dc.w    $F4FA,$F500,$1000,$0000,$F62C,$F700,$1000,$0000
    dc.w    $F84D,$F900,$1000,$0000,$FAAC,$FB00,$1000,$0000
    dc.w    $FCB2,$FD00,$1000,$0000,$FE9A,$FF00,$1000,$0000
    dc.w    $009A,$0106,$1000,$0000,$02DF,$0306,$1000,$0000 ; sprite beyond vpos $FF
    dc.w    $0446,$0506,$1000,$0000,$0688,$0706,$1000,$0000

    ;dc.w   $0899,$0906,$1000,$0000,$0ADD,$0B06,$1000,$0000
    ;dc.w   $0CEE,$0D06,$1000,$0000,$0EFF,$0F06,$1000,$0000
    ;dc.w   $10CD,$1106,$1000,$0000,$1267,$1306,$1000,$0000
    ;dc.w   $1443,$1506,$1000,$0000,$1664,$1706,$1000,$0000
    ;dc.w   $1823,$1906,$1000,$0000,$1A6D,$1B06,$1000,$0000
    ;dc.w   $1C4F,$1D06,$1000,$0000,$1E5F,$1F06,$1000,$0000
    ;dc.w   $2055,$2106,$1000,$0000,$2267,$2306,$1000,$0000
    ;dc.w   $2445,$2506,$1000,$0000,$2623,$2706,$1000,$0000
    ;dc.w   $2834,$2906,$1000,$0000,$2AF0,$2B06,$1000,$0000
STARFIELD_SPRITE_END:
    dc.w    $0000,$0000 ; end of sprite address
    
    
    incdir  "dh1:own/sprite/"


*****************************************
*             BALL SPRITE               *
*                                       *
*        4 sprites, 8 anim frames       *
*                                       *
*****************************************
    
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
    dc.w $0000,$0080
    dc.w $0000,$0000,$0000,$0007,$0004,$003b,$0040,$00ff
    dc.w $0100,$01ff,$0000,$03ff,$0000,$07ff,$0800,$0fff
    dc.w $0800,$1fff,$0000,$1fff,$0201,$3fff,$0102,$3fff
    dc.w $0030,$3fff,$0001,$7ff0,$0000,$3f00,$4000,$3c00
    dc.w $0001,$0000,$2001,$0000,$1007,$0000,$261f,$0000
    dc.w $21ff,$0000,$0c3f,$0000,$1f07,$0000,$1f82,$0000
    dc.w $0380,$0000,$0680,$0000,$0382,$0000,$01c2,$0000
    dc.w $00fe,$0000,$003f,$0000,$0007,$0000,$0000,$0000
    dc.w 0,0

    
frame1b:


    dc.w $0000,$0000
    dc.w $0000,$0000,$e000,$e000,$1800,$1c00,$0200,$0d00
    dc.w $0080,$0f00,$0000,$1f80,$0000,$3f80,$0000,$7f90
    dc.w $8000,$7f18,$8010,$7e18,$8070,$7e7c,$81e0,$7dfc
    dc.w $ffe0,$03fc,$ffc0,$0ffe,$ff80,$1ffe,$ff00,$3ffc
    dc.w $fe00,$fffc,$f000,$fffa,$e000,$f3f2,$c000,$fff0
    dc.w $4000,$fff0,$0000,$f1e0,$0000,$e1f0,$0000,$e1e0
    dc.w $0000,$e180,$0000,$e000,$0000,$0000,$0000,$0000
    dc.w $0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000
    dc.w 0,0



frame1c:
    dc.w $0000,$0080
    dc.w $0000,$0000,$0000,$e000,$1400,$ec00,$0300,$f100
    dc.w $0080,$f000,$0040,$e000,$0060,$c000,$0070,$8000
    dc.w $80f8,$8000,$81e8,$0000,$818c,$0000,$821c,$0000
    dc.w $fc1c,$0000,$8c3e,$0c00,$987e,$1800,$b0fc,$3000
    dc.w $61fc,$6000,$0ffa,$0000,$13f2,$0000,$3ff0,$0000
    dc.w $bff0,$0000,$f1e0,$0000,$e1f0,$0000,$e1e0,$0000
    dc.w $e180,$0000,$e000,$0000,$0000,$0000,$0000,$0000
    dc.w $0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000
    dc.w 0,0


frame2:


    dc.w $0000,$0000
    dc.w $0000,$0000,$0007,$0007,$003f,$003f,$0080,$0080
    dc.w $0100,$0100,$0200,$0200,$0400,$0400,$0800,$0c00
    dc.w $1800,$1800,$1800,$1803,$3006,$301f,$301c,$307f
    dc.w $0a70,$31ff,$07e0,$0fff,$0f00,$0fff,$0c01,$0ffe
    dc.w $0807,$0ff8,$13bf,$6f41,$14ff,$6f8f,$0ffe,$37df
    dc.w $0ffe,$10ff,$0e7e,$1fff,$0438,$077f,$0608,$077f
    dc.w $0200,$03be,$0000,$0780,$0000,$0200,$0000,$0000
    dc.w $0000,$0080,$0000,$0000,$0000,$0000,$0000,$0000
    dc.w 0,0


frame2a:
    dc.w $0000,$0080
    dc.w $0000,$0000,$0000,$0007,$0000,$003f,$0001,$00ff
    dc.w $0000,$01ff,$0000,$03ff,$0000,$07ff,$0070,$0fff
    dc.w $0079,$1fff,$007c,$1fff,$0861,$3fff,$0883,$3fff
    dc.w $0e0f,$3fff,$101f,$7fff,$10ff,$7fff,$13fe,$7ffe
    dc.w $1ff8,$77f8,$1f41,$0f41,$1f0e,$0c0e,$04dd,$04dc
    dc.w $28f9,$00f8,$0581,$0400,$1b47,$0000,$0977,$0000
    dc.w $0dbe,$0000,$0780,$0000,$0200,$0000,$0000,$0000
    dc.w $0080,$0000,$0000,$0000,$0000,$0000,$0000,$0000
    dc.w 0,0

    
frame2b:

    dc.w $0000,$0000
    dc.w $0000,$0000,$e000,$e000,$fc00,$f800,$7400,$fb00
    dc.w $1000,$3f80,$0800,$0780,$0c00,$1380,$4600,$3980
    dc.w $0300,$fc00,$0700,$f800,$0f80,$f180,$1f80,$e3c0
    dc.w $3f80,$c7c0,$7f00,$8fc0,$fe00,$3f00,$f800,$7ec4
    dc.w $e000,$f986,$c000,$e706,$0000,$8f06,$0000,$9f04
    dc.w $0000,$fe04,$0000,$c004,$0000,$8000,$0000,$8000
    dc.w $0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000
    dc.w $0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000
    dc.w 0,0




frame2c:
    dc.w $0000,$0080
    dc.w $0000,$0000,$0000,$e000,$0000,$fc00,$0800,$fc00
    dc.w $4800,$f800,$1840,$f000,$3460,$f800,$3a70,$fc00
    dc.w $fdf0,$fe00,$f9e0,$f800,$f160,$f100,$e360,$e300
    dc.w $c640,$c600,$8cc0,$8c00,$3900,$3800,$76c4,$7000
    dc.w $d986,$c000,$a706,$8000,$8f06,$0000,$9f04,$0000
    dc.w $fe04,$0000,$c004,$0000,$8000,$0000,$8000,$0000
    dc.w $0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000
    dc.w $0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000
    dc.w 0,0


frame3:


    dc.w $0000,$0000
    dc.w $0000,$0000,$0007,$0007,$003e,$003c,$00f0,$00f8
    dc.w $00e0,$00e0,$0080,$0040,$0000,$00c0,$01c0,$01e0
    dc.w $03e0,$07f0,$07e8,$0ff1,$0fe8,$1ff3,$1fe8,$3ff7
    dc.w $3fd8,$3feb,$7fbc,$7ffd,$7ede,$7f7e,$793f,$7fff
    dc.w $347e,$7afe,$09f8,$7df8,$53e0,$6e70,$13c0,$3ee0
    dc.w $3b80,$0fc0,$3800,$3f00,$1800,$1c00,$1800,$1c00
    dc.w $0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000
    dc.w $0000,$0000,$0000,$0000,$0000,$0001,$0000,$0000
    dc.w 0,0


frame3a:
    dc.w $0000,$0080
    dc.w $0000,$0000,$0000,$0007,$0002,$003f,$0000,$00ff
    dc.w $0190,$017f,$0080,$03ff,$0020,$07ff,$0210,$0fff
    dc.w $0008,$1fff,$0008,$1ffe,$000c,$3ffc,$0000,$3ff8
    dc.w $0024,$3fe0,$0062,$7fe0,$0121,$7f00,$06c0,$7e00
    dc.w $4a81,$7800,$7cc7,$78c0,$6c5f,$6040,$3ebe,$3280
    dc.w $0478,$0000,$17e0,$1000,$1400,$1000,$0404,$0000
    dc.w $0c00,$0000,$0000,$0000,$0000,$0000,$0000,$0000
    dc.w $0000,$0000,$0000,$0000,$0001,$0000,$0000,$0000
    dc.w 0,0


frame3b:

    dc.w $0000,$0000
    dc.w $0000,$0000,$0000,$8000,$0000,$0400,$0000,$0f00
    dc.w $0000,$0f80,$0000,$1800,$0000,$3000,$0000,$4000
    dc.w $0000,$8018,$0000,$0878,$0000,$01e4,$0180,$c3cc
    dc.w $0200,$c79c,$0000,$ce7e,$0000,$b8fe,$6000,$7bfe
    dc.w $7000,$7ffe,$3400,$7ffe,$0800,$7ffe,$0000,$7ffc
    dc.w $0000,$1ffc,$0000,$0ff8,$0000,$07f0,$0000,$07c0
    dc.w $0000,$0380,$0000,$0100,$0000,$0000,$0000,$0700
    dc.w $0000,$1f00,$0000,$3c00,$0000,$e000,$0000,$0000
    dc.w 0,0

frame3c:    
    dc.w $0000,$0080
    dc.w $0000,$0000,$4000,$e000,$0000,$f800,$0000,$f000
    dc.w $0000,$f000,$07c0,$e000,$08e0,$c000,$33b0,$8000
    dc.w $4e18,$0000,$f478,$0000,$fde4,$0000,$3e4c,$0000
    dc.w $3d9c,$0000,$3e7e,$0000,$78fe,$0000,$9bfe,$0000
    dc.w $8ffe,$0000,$cbfe,$0000,$f7fe,$0000,$7ffc,$0000
    dc.w $1ffc,$0000,$0ff8,$0000,$07f0,$0000,$07c0,$0000
    dc.w $0380,$0000,$0100,$0000,$0000,$0000,$0700,$0000
    dc.w $1f00,$0000,$3c00,$0000,$e000,$0000,$0000,$0000
    dc.w 0,0

frame4:

    dc.w $0000,$0000
    dc.w $0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000
    dc.w $0000,$0007,$0000,$0001,$0000,$002c,$0010,$0180
    dc.w $0037,$021f,$007f,$0033,$2044,$2d7f,$00b1,$2e7b
    dc.w $2166,$07bd,$6398,$67f7,$6620,$737f,$7ec1,$67be
    dc.w $7f07,$63f8,$6e0f,$11f1,$443f,$37c7,$06ff,$051f
    dc.w $03ff,$067f,$01ff,$03ff,$00ff,$00ff,$007c,$007f
    dc.w $0010,$003e,$0000,$0018,$0000,$0000,$0000,$001c
    dc.w $0000,$003f,$0000,$003f,$0000,$0007,$0000,$0000
    dc.w 0,0



frame4a:
    dc.w $0000,$0080
    dc.w $0000,$0000,$0000,$0007,$0000,$003f,$0000,$00ff
    dc.w $0000,$01f8,$001e,$03e0,$0073,$0780,$00ff,$0e20
    dc.w $1168,$1cc0,$0652,$1992,$00fb,$3278,$019a,$3070
    dc.w $0099,$3881,$0067,$5807,$457f,$483f,$353e,$2c3e
    dc.w $7bf8,$63f8,$29f1,$01f1,$0fc7,$07c7,$391e,$011e
    dc.w $3478,$0078,$32f0,$00f0,$1f00,$0000,$1f83,$0000
    dc.w $0fee,$0000,$03f8,$0000,$0000,$0000,$001c,$0000
    dc.w $003f,$0000,$003f,$0000,$0007,$0000,$0000,$0000
    dc.w 0,0

frame4b:

    dc.w $0000,$0000
    dc.w $0000,$0000,$0000,$0000,$0000,$0400,$0100,$0e00
    dc.w $0080,$8f00,$0040,$df80,$1fe0,$e060,$e1c0,$9e40
    dc.w $f3e0,$ece0,$3fe0,$e1e0,$7fe0,$e1f0,$dfe0,$a3f0
    dc.w $3fe0,$c7f0,$7fc0,$8ff0,$ff80,$1ff0,$ff00,$7ff0
    dc.w $fe00,$fff0,$fc00,$fff0,$f800,$fff0,$f000,$ff8c
    dc.w $e000,$fc0c,$8000,$f00c,$0000,$c018,$0000,$8018
    dc.w $0000,$0030,$0000,$0020,$0000,$0040,$0000,$0080
    dc.w $0000,$0100,$0000,$fc00,$0000,$e000,$0000,$0000
    dc.w 0,0


frame4c:
    dc.w $0000,$0080
    dc.w $0000,$0000,$0000,$e000,$0000,$f800,$0100,$f000
    dc.w $0080,$7000,$0040,$2000,$1980,$0600,$5e70,$1e40
    dc.w $2cd0,$2cc0,$c190,$0180,$a190,$2180,$a310,$a300
    dc.w $c610,$c600,$8c30,$8c00,$1870,$1800,$70f0,$7000
    dc.w $e1f0,$e000,$c3f0,$c000,$07f0,$0000,$0f8c,$0000
    dc.w $1c0c,$0000,$700c,$0000,$c018,$0000,$8018,$0000
    dc.w $0030,$0000,$0020,$0000,$0040,$0000,$0080,$0000
    dc.w $0100,$0000,$fc00,$0000,$e000,$0000,$0000,$0000
    dc.w 0,0

frame5:

    dc.w $0000,$0000
    dc.w $0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000
    dc.w $0000,$0000,$0000,$0000,$003e,$067f,$01fe,$0dff
    dc.w $07fe,$13ff,$0dff,$1ffe,$17fd,$1ffe,$0ffd,$27fe
    dc.w $0ff1,$1ffe,$5fe1,$7ffe,$3f01,$7ffe,$3c03,$7ffc
    dc.w $7007,$7ff8,$000f,$7ff1,$003f,$7fc7,$00fc,$3f1c
    dc.w $0780,$3800,$3e00,$0400,$1c00,$1c00,$1800,$1800
    dc.w $0000,$0800,$0000,$0000,$0000,$0000,$0000,$0100
    dc.w $0000,$00c0,$0000,$0038,$0000,$0007,$0000,$0000
    dc.w 0,0


frame5a:
    dc.w $0000,$0080
    dc.w $0000,$0000,$0001,$0007,$0001,$003f,$0001,$00ff
    dc.w $0001,$01ff,$000f,$03ff,$0080,$01ff,$0200,$03ff
    dc.w $0e00,$01ff,$1f01,$0eff,$1c00,$17ff,$2002,$27ff
    dc.w $100e,$1fff,$601e,$7fff,$40ff,$3ffe,$43fd,$7ffc
    dc.w $0ff9,$7ff8,$7ff0,$7ff0,$7fc6,$7fc6,$3f23,$3f00
    dc.w $39ff,$3800,$07ff,$0400,$1bff,$1800,$07fe,$0000
    dc.w $0ff8,$0000,$07e0,$0000,$0000,$0000,$0100,$0000
    dc.w $00c0,$0000,$0038,$0000,$0007,$0000,$0000,$0000
    dc.w 0,0

frame5b:


    dc.w $0000,$0000
    dc.w $0000,$0000,$6000,$e000,$7800,$fc00,$7000,$ff00
    dc.w $7180,$ff80,$0180,$3ec0,$83c0,$3d60,$0070,$3c70
    dc.w $0000,$7c18,$8000,$7e00,$8000,$7e00,$8000,$7c00
    dc.w $8000,$7800,$8000,$7000,$8000,$6000,$0000,$0000
    dc.w $0000,$0000,$0000,$0000,$0000,$0000,$0000,$f800
    dc.w $6000,$fe00,$0000,$ff80,$0000,$ffe0,$0000,$ffe0
    dc.w $0000,$ffe0,$0000,$ffe0,$0000,$ffc0,$0000,$ff00
    dc.w $0000,$fc00,$0000,$e000,$0000,$0000,$0000,$0000
    dc.w 0,0



frame5c:

    dc.w $0000,$0080
    dc.w $0000,$0000,$0000,$e000,$4400,$bc00,$4f00,$bf00
    dc.w $4f80,$bf80,$dec0,$fe80,$8320,$c100,$8380,$c000
    dc.w $83f8,$8000,$0180,$8000,$81c0,$0000,$83e0,$0000
    dc.w $87e0,$0000,$8fe0,$0000,$9fc0,$0000,$ff80,$0000
    dc.w $ff00,$0000,$fe00,$0000,$fc00,$0000,$f800,$0000
    dc.w $9e00,$0000,$ff80,$0000,$ffe0,$0000,$ffe0,$0000
    dc.w $ffe0,$0000,$ffe0,$0000,$ffc0,$0000,$ff00,$0000
    dc.w $fc00,$0000,$e000,$0000,$0000,$0000,$0000,$0000
    dc.w 0,0

frame6:

    dc.w $0000,$0000
    dc.w $0000,$0000,$0007,$0007,$003f,$003f,$007f,$007f
    dc.w $00fe,$01ff,$01ff,$01ff,$0400,$003f,$0807,$0c08
    dc.w $1c00,$1808,$1000,$1808,$3800,$3004,$3800,$3002
    dc.w $2000,$3007,$6000,$700f,$6000,$70ff,$7000,$63ff
    dc.w $7000,$6fff,$1000,$6ffe,$1000,$6ff8,$0e00,$31e0
    dc.w $0fc0,$3040,$0ff0,$31f0,$07f8,$07fc,$07fc,$07ff
    dc.w $03f0,$03ff,$0380,$03ff,$0000,$01ff,$0000,$00ff
    dc.w $0000,$007f,$0000,$0000,$0000,$0000,$0000,$0000
    dc.w 0,0


frame6a:
    dc.w $0000,$0080
    dc.w $0000,$0000,$0000,$0007,$0020,$001f,$0080,$00ff
    dc.w $0081,$017f,$0200,$03ff,$07c3,$07ff,$0077,$0ff0
    dc.w $0477,$1ff0,$0074,$1ff0,$0862,$3ff8,$0801,$3ffc
    dc.w $0800,$3ff8,$0000,$7ff0,$0000,$7f00,$1000,$7c00
    dc.w $1000,$7000,$6001,$7000,$6007,$7000,$061f,$0800
    dc.w $08bf,$0000,$09cf,$01c0,$1f87,$0780,$1803,$0000
    dc.w $0c0f,$0000,$047f,$0000,$01ff,$0000,$00ff,$0000
    dc.w $007f,$0000,$0000,$0000,$0000,$0000,$0000,$0000
    dc.w 0,0

frame6b:

    dc.w $0000,$0000
    dc.w $0000,$0000,$e000,$e000,$f800,$fc00,$f000,$ff00
    dc.w $a080,$ff00,$64c0,$ef40,$d9e0,$2b60,$fcf0,$f6f0
    dc.w $0670,$1ff8,$0030,$21f8,$0020,$00f8,$0000,$00f8
    dc.w $0000,$80f8,$0000,$e038,$0000,$e018,$0000,$8000
    dc.w $0000,$0000,$0000,$0000,$0000,$0000,$0000,$0004
    dc.w $0000,$0034,$0000,$007c,$0000,$0078,$0000,$01f8
    dc.w $0000,$83f0,$0000,$e7e0,$0000,$e7c0,$0000,$c780
    dc.w $0000,$0300,$0000,$0000,$0000,$0000,$0000,$0000
    dc.w 0,0

 
frame6c:
    dc.w $0000,$0080
    dc.w $0000,$0000,$0000,$e000,$0400,$fc00,$0f00,$ff00
    dc.w $5f00,$1f00,$cf40,$c740,$2360,$2160,$1240,$1040
    dc.w $f988,$0000,$d1c8,$0000,$38d8,$0000,$8cf8,$0000
    dc.w $60f8,$0000,$1838,$0000,$1c18,$0000,$7e00,$0000
    dc.w $ff00,$0000,$fe00,$0000,$fc00,$0000,$f804,$0000
    dc.w $f034,$0000,$c07c,$0000,$8078,$0000,$01f8,$0000
    dc.w $83f0,$0000,$e7e0,$0000,$e7c0,$0000,$c780,$0000
    dc.w $0300,$0000,$0000,$0000,$0000,$0000,$0000,$0000
    dc.w 0,0

frame7:

    dc.w $0000,$0000
    dc.w $0000,$0000,$0006,$0006,$003f,$003f,$00ff,$00ff
    dc.w $01ff,$01ff,$035f,$03ff,$06af,$077f,$09ab,$0ff7
    dc.w $0719,$1be7,$0060,$02df,$0030,$056f,$0030,$102f
    dc.w $0018,$0807,$000c,$0413,$0007,$0309,$0001,$038f
    dc.w $0000,$0fc4,$0000,$7ff0,$0000,$7ff0,$0000,$3fe3
    dc.w $2006,$1f87,$200f,$1e0f,$100f,$101f,$1c0c,$1c1f
    dc.w $0e00,$0e3f,$0600,$077f,$0000,$03ff,$0000,$011f
    dc.w $0000,$0007,$0000,$0001,$0000,$0000,$0000,$0000
    dc.w 0,0

frame7a:
    dc.w $0000,$0080
    dc.w $0000,$0000,$0001,$0007,$0000,$003f,$0000,$00ff
    dc.w $0000,$01ff,$00e0,$027f,$0150,$071f,$0674,$0fe7
    dc.w $04e6,$00e7,$19df,$045f,$10ef,$222f,$03cf,$200f
    dc.w $05f7,$3007,$03eb,$7803,$00f7,$7c01,$0070,$7c00
    dc.w $003b,$7000,$000f,$0000,$000e,$0000,$001f,$0000
    dc.w $2079,$0000,$01f0,$0000,$1ff0,$1000,$0bf3,$0800
    dc.w $01ff,$0000,$01ff,$0000,$03ff,$0000,$011f,$0000
    dc.w $0007,$0000,$0001,$0000,$0000,$0000,$0000,$0000
    dc.w 0,0

frame7b:

    dc.w $0000,$0000
    dc.w $0000,$0000,$0000,$0000,$c000,$8400,$e000,$ef00
    dc.w $f080,$ff00,$e7c0,$fc40,$c2e0,$fde0,$8670,$f9f0
    dc.w $0c10,$f318,$1800,$e608,$3800,$c604,$7000,$fc00
    dc.w $e000,$7000,$c000,$e000,$8000,$e000,$8000,$c000
    dc.w $0000,$c000,$0000,$c000,$0000,$7000,$0000,$7800
    dc.w $0000,$fc00,$0000,$fe00,$0000,$ff00,$0000,$fe00
    dc.w $0000,$fc30,$0000,$fe20,$0000,$ffc0,$0000,$ff80
    dc.w $0000,$ff00,$0000,$fc00,$0000,$6000,$0000,$0000
    dc.w 0,0


frame7c:
    dc.w $0000,$0080
    dc.w $0000,$0000,$0000,$e000,$4000,$f800,$1000,$f000
    dc.w $0880,$f800,$1b40,$fc40,$3ee0,$fce0,$7a00,$fc00
    dc.w $f4e8,$f800,$e1f8,$f800,$d9f4,$c000,$c3f0,$c000
    dc.w $5fe0,$4000,$a3e0,$8000,$60c0,$0000,$4000,$0000
    dc.w $c000,$0000,$c000,$0000,$7000,$0000,$7800,$0000
    dc.w $fc00,$0000,$fe00,$0000,$ff00,$0000,$fe00,$0000
    dc.w $fc30,$0000,$fe20,$0000,$ffc0,$0000,$ff80,$0000
    dc.w $ff00,$0000,$fc00,$0000,$6000,$0000,$0000,$0000
    dc.w 0,0

frame8:

    dc.w $0000,$0000
    dc.w $0000,$0000,$0000,$0000,$0000,$0000,$00e0,$00c0
    dc.w $01e1,$01e3,$03e7,$03ff,$07f3,$07e7,$0fe0,$0fc1
    dc.w $0f40,$0f80,$1e80,$0f00,$3d00,$3e01,$3a00,$1c03
    dc.w $1400,$3d07,$1400,$3c8f,$0800,$187f,$1800,$281f
    dc.w $0000,$6807,$0000,$6980,$0400,$7dc0,$3700,$1fc0
    dc.w $1f80,$2f80,$1fc0,$27c0,$1fe0,$1ff0,$1f80,$1ff0
    dc.w $0f80,$0fe2,$0780,$07f1,$0000,$03fc,$0000,$01ff
    dc.w $0000,$00ff,$0000,$003f,$0000,$0007,$0000,$0000
    dc.w 0,0


frame8a:
    dc.w $0000,$0080
    dc.w $0000,$0000,$0000,$0007,$0020,$003f,$0021,$00ff
    dc.w $0015,$01fe,$0000,$03ff,$0018,$07ff,$0032,$0fff
    dc.w $0079,$0fff,$00f0,$0fff,$0160,$1ffe,$0600,$1ffc
    dc.w $2e00,$3cf8,$6900,$3870,$7c80,$3800,$4720,$1000
    dc.w $1f98,$0000,$1e67,$0000,$1a31,$0000,$2a30,$0200
    dc.w $0370,$0300,$04b0,$0480,$1c10,$1c00,$0c70,$0c00
    dc.w $0062,$0000,$0071,$0000,$03fc,$0000,$01ff,$0000
    dc.w $00ff,$0000,$003f,$0000,$0007,$0000,$0000,$0000
    dc.w 0,0


frame8b:

    dc.w $0000,$0000
    dc.w $0000,$0000,$0000,$0000,$0000,$0400,$7000,$ff00
    dc.w $f000,$ff80,$e080,$ff00,$c0c0,$ff40,$81c0,$fe40
    dc.w $83e0,$7ce0,$67e0,$99e0,$0fe0,$f5f0,$03e0,$fff0
    dc.w $0000,$f870,$0000,$f00e,$0000,$e00e,$0000,$800e
    dc.w $0000,$000e,$0000,$0006,$0000,$000e,$0000,$000c
    dc.w $0000,$000c,$0000,$0008,$0000,$0000,$0000,$0010
    dc.w $0000,$0030,$0000,$f000,$0000,$f180,$0000,$e000
    dc.w $0000,$fe00,$0000,$fc00,$0000,$e000,$0000,$0000
    dc.w 0,0

frame8c:
    dc.w $0000,$0080
    dc.w $0000,$0000,$0000,$e000,$0000,$f800,$4e00,$be00
    dc.w $0f00,$ff00,$1f40,$ff00,$3f60,$ff40,$7e70,$fe40
    dc.w $7cd0,$fcc0,$5990,$3980,$0d90,$0580,$0010,$0000
    dc.w $07f0,$0000,$0fee,$0000,$1fce,$0000,$7f8e,$0000
    dc.w $ff0e,$0000,$fe06,$0000,$fc0e,$0000,$000c,$0000
    dc.w $000c,$0000,$0008,$0000,$0000,$0000,$0010,$0000
    dc.w $0030,$0000,$f000,$0000,$f180,$0000,$e000,$0000
    dc.w $fe00,$0000,$fc00,$0000,$e000,$0000,$0000,$0000
    dc.w 0,0

    
FONT:
    incdir  "dh1:amiga-playground/resources/fonts/"
    incbin  "16X16-F2_944_16_2.blt.raw"
    
*****************************************************************************

	SECTION Music,DATA_C
	
MT_DATA:
    incdir  "dh1:amiga-playground/resources/mod/"
    incbin  "mod.towards"



    SECTION Screen,BSS_C    

SCREEN:
    ds.b    40*256*bpls ; 

    end
