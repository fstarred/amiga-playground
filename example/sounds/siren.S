*********************************
*				*
*	PERIOD MODULATION	*
*				*
*********************************

; http://amigadev.elowar.com/read/ADCD_2.1/Hardware_Manual_guide/node00E7.html

;** Modulated sound generation via hardware registers **
CTLW 	= $DFF096		; DMA control
ADKCON 	= $DFF09E         	; Audio/Disk control
C0THI 	= $DFF0A0       	; HI table address
C0TLO 	= C0THI+2		; LO table address
C0TL 	= C0THI+4		; table length
C0PER 	= C0THI+6		; read in rate
C0VOL 	= C0THI+8		; volume

; type 'j' for playing tone
; type 'j stop' for stop playing tone

RUN:
	MOVE.L  #TABLE,C0THI+16 ; table start for channel 1
	MOVE.W  #8,C0TL+16      ; table length
;	MOVE.W  #300,C0PER+16   ; read in rate (not used?)
	MOVE.W  #40,C0VOL+16	; volume


	MOVE.L  #TABLE2,C0THI   ; table start for channel 0
	MOVE.W  #8,C0TL		; table length
	MOVE.W  #60000,C0PER    ; read in rate
;	MOVE.W  #30,C0VOL	; volume	(not used?)


	MOVE.W  #$8010,ADKCON   ; modulation mode: period (bit 4)
	MOVE.W  #$8203,CTLW     ; start DMA
	RTS

STOP:            		; turn off tone
	MOVE.W  #$10,ADKCON	; no more modulations
	MOVE.W  #3,CTLW     	; turn off channels
	RTS

TABLE:                           ;data for basic tone
	DC.B 	-40,-70,-90,-100,-90,-70,-40,0
	DC.B	 40, 70, 90, 100, 90, 70, 40,0

TABLE2:                          ;data for modulation
	DC.W 	400,430,470,500,530,500,470,430
END

	PRINTT	"type 'j stop' to stop sound"

;          Table 5-4: Data Interpretation in Attach Mode
;
;
;           Independent        Modulating
;   Data       (not               Both              Modulating  Modulating
;   Words   Modulating)      Period and Volume      Period Only Volume Only
;   -----   -----------      -----------------      ----------- -----------
;   Word 1  |data|data|  |volume for other channel|  |period|    |volume|
;   Word 2  |data|data|  |period for other channel|  |period|    |volume|
;   Word 3  |data|data|  |volume for other channel|  |period|    |volume|
;   Word 4  |data|data|  |period for other channel|  |period|    |volume|


;	Table 5-5: Channel Attachment for Modulation
;
;
;  		ADKCON Register
;  		---------------
;  Bit    Name     Function
;  ---    ----     --------
;   7    ATPER3    disables audio output of channel 3
;   6    ATPER2    Use audio channel 2 to modulate period of channel 3
;   5    ATPER1    Use audio channel 1 to modulate period of channel 2
;   4    ATPER0    Use audio channel 0 to modulate period of channel 1
;   3    ATVOL3    disables audio output of channel 3
;   2    ATVOL2    Use audio channel 2 to modulate volume of channel 3
;   1    ATVOL1    Use audio channel 1 to modulate volume of channel 2
;   0    ATVOL0    Use audio channel 0 to modulate volume of channel 1
