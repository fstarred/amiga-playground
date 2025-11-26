******************************************************************************
;    680X0 & AGA STARTUP BY FABIO CIUCCI - Livello di complessita' 2
******************************************************************************

MAINCODE:
	movem.l	d0-d7/a0-a6,-(SP)	; Salva i registri nello stack
	move.l	4.w,a6			; ExecBase in a6
	LEA	DosName(PC),A1		; Dos.library
	JSR	-$198(A6)		; OldOpenlib
	MOVE.L	D0,DosBase
	BEQ.w	EXIT3			; Se zero, esci! Errore!
	LEA	GfxName(PC),A1		; Nome libreria da aprire
	JSR	-$198(A6)		; OldOpenLibrary - apri la lib
	MOVE.L	d0,GfxBase
	BEQ.w	EXIT2			; Se si, esci! Errore!
	LEA	IntuiName(PC),A1	; Intuition.library
	JSR	-$198(A6)		; OldOpenlib
	MOVE.L	D0,IntuiBase
	BEQ.w	EXIT1			; Se zero, esci! Errore!

	MOVE.L	d0,A0
	CMP.W	#39,$14(A0)	  ; Versione 39 o maggiore? (kick3.0+)
	BLT.s	VecchiaIntui
	BSR.w	ResettaSpritesV39 ; se kick3.0+ allora resetta sprites
VecchiaIntui:

	MOVE.L	GfxBase(PC),A6
	MOVE.L	$22(A6),WBVIEW	; Salva il WBView attuale di sistema
	SUB.L	A1,A1		; View nullo per azzerare il modo video
	JSR	-$DE(A6)	; LoadView nullo - modo video azzerato
	SUB.L	A1,A1		; View nullo
	JSR	-$DE(A6)	; LoadView (due volte per sicurezza...)
	JSR	-$10E(A6)	; WaitOf ( Queste due chiamate a WaitOf    )
	JSR	-$10E(A6)	; WaitOf ( servono a resettare l'interlace )
	JSR	-$10E(A6)	; Altre due, vah!
	JSR	-$10E(A6)

	LEA	$DFF006,A5	; VhPosr
	MOVE.w	#$dd,D0		; Linea da attendere
	MOVE.w	#WaitDisk,D1	; Quanto attendere... (Per essere sicuri che
WaitaLoop:			; disk drives o Hard Disk abbiano finito).
	CMP.B	(A5),D0
	BNE.S	WaitaLoop
Wait2:
	CMP.B	(A5),D0
	Beq.s	Wait2
	dbra	D1,WaitaLoop

	MOVE.L	4.w,A6
	SUB.L	A1,A1		; NULL task - trova questo task
	JSR	-$126(A6)	; findtask (Task(name) in a1, -> d0=task)
	MOVE.L	D0,A1		; Task in a1
	MOVE.L	$B8(A1),pr_Win	; A questo offset è presente l' address
				; della window dalla quale è stato
				; caricato il programma e che serve al
				; DOS per sapere dove aprire i Reqs.
	MOVE.L	#-1,$B8(A1)	; Settandolo a -1 il DOS non apre Reqs
				; Infatti se ci fossero errori nell'apertura
				; di files con la dos.lib, il sistema
				; proverebbe ad aprire un requester, ma con
				; il blitter disabilitato (OwnBlit), non lo
				; potrebbe disegnare, bloccando tutto!
	MOVEQ	#127,D0		; Priorita' in d0 (-128, +127) - MASSIMA!
	JSR	-$12C(A6)	; LVOSetTaskPri (d0=priorita', a1=task)

	MOVE.L	GfxBase(PC),A6
	jsr	-$1c8(a6)	; OwnBlitter, che ci da l'esclusiva sul blitter
				; impedendone l'uso al sistema operativo.
	jsr	-$E4(A6)	; WaitBlit - Attende la fine di ogni blittata
	JSR	-$E4(A6)	; WaitBlit

	move.l	4.w,a6		; ExecBase in A6
	JSR	-$84(a6)	; FORBID - Disabilita il Multitasking
	JSR	-$78(A6)	; DISABLE - Disabilita anche gli interrupt
				;	    del sistema operativo

	bsr.w	HEAVYINIT	; Ora puoi eseguire la parte che opera
				; sui registri hardware

	move.l	4.w,a6		; ExecBase in A6
	JSR	-$7E(A6)	; ENABLE - Abilita System Interrupts
	JSR	-$8A(A6)	; PERMIT - Abilita il multitasking

	SUB.L	A1,A1		   ; NULL task - trova questo task
	JSR	-$126(A6)	   ; findtask (Task(name) in a1, -> d0=task)
	MOVE.L	D0,A1		   ; Task in a1
	MOVE.L	pr_Win(PC),$B8(A1) ; ripristina l'address della window
	MOVEQ	#0,D0		   ; Priorita' in d0 (-128, +127) - NORMALE
	JSR	-$12C(A6)	   ; LVOSetTaskPri (d0=priorita', a1=task)

	MOVE.W	#$8040,$DFF096	; abilita blit
	BTST.b	#6,$dff002	; WaitBlit via hardware...
Wblittez:
	BTST.b	#6,$dff002
	BNE.S	Wblittez

	MOVE.L	GfxBase(PC),A6	; GfxBase in A6
	jsr	-$E4(A6)	; Aspetta la fine di eventuali blittate
	JSR	-$E4(A6)	; WaitBlit
	jsr	-$1ce(a6)	; DisOwnBlitter, il sistema operativo ora
				; puo' nuovamente usare il blitter

	MOVE.L	IntuiBase(PC),A0
	CMP.W	#39,$14(A0)	; V39+?
	BLT.s	Vecchissima
	BSR.w	RimettiSprites
Vecchissima:

	MOVE.L	GfxBase(PC),A6	; GfxBase in A6
	MOVE.L	$26(a6),$dff080	; COP1LC - Punta la vecchia copper1 di sistema
	MOVE.L	$32(a6),$dff084	; COP2LC - Punta la vecchia copper2 di sistema
	JSR	-$10E(A6)	; WaitOf ( Risistema l'eventuale interlace)
	JSR	-$10E(A6)	; WaitOf
	MOVE.L	WBVIEW(PC),A1	; Vecchio WBVIEW in A1
	JSR	-$DE(A6)	; loadview - rimetti il vecchio View
	JSR	-$10E(A6)	; WaitOf ( Risistema l'eventuale interlace)
	JSR	-$10E(A6)	; WaitOf
	MOVE.W	#$11,$DFF10C	; Questo non lo ripristina da solo..!
	MOVE.L	$26(a6),$dff080	; COP1LC - Punta la vecchia copper1 di sistema
	MOVE.L	$32(a6),$dff084	; COP2LC - Punta la vecchia copper2 di sistema
	moveq	#100,d7
RipuntLoop:
	MOVE.L	$26(a6),$dff080	; COP1LC - Punta la vecchia copper1 di sistema
	move.w	d0,$dff088
	dbra	d7,RipuntLoop	; Per sicurezza...

	MOVE.L	IntuiBase(PC),A6
	JSR	-$186(A6)	; _LVORethinkDisplay - Ridisegna tutto il
				; display, comprese ViewPorts e eventuali
				; modi interlace o multisync.
	MOVE.L	A6,A1		; IntuiBase in a1 per chiudere la libreria
	move.l	4.w,a6		; ExecBase in A6
	jsr	-$19E(a6)	; CloseLibrary - intuition.library CHIUSA
EXIT1:
	MOVE.L	GfxBase(PC),A1	; GfxBase in A1 per chiudere la libreria
	move.l	4.w,a6		; ExecBase in A6
	jsr	-$19E(a6)	; CloseLibrary - graphics.library CHIUSA
EXIT2:
	MOVE.L	DosBase(PC),A6	; DosBase in A1 per chiudere la libreria
	move.l	4.w,a6		; ExecBase in A6
	jsr	-$19E(a6)	; CloseLibrary - dos.library CHIUSA
EXIT3:
	movem.l	(SP)+,d0-d7/a0-a6 ; Riprendi i vecchi valori dei registri
	RTS			  ; Torna all'ASMONE o al Dos/WorkBench

pr_Win:
	dc.l	0

*******************************************************************************
;	Resetta la risoluzione degli sprite "legalmente"
*******************************************************************************

ResettaSpritesV39:
	LEA	Workbench(PC),A0 ; Nome schermo del Workbench in a0
	MOVE.L	IntuiBase(PC),A6
	JSR	-$1FE(A6)	; _LVOLockPubScreen - "blocchiamo" lo schermo
				; (il cui nome e' in a0).
	MOVE.L	D0,SchermoWBLocckato
	BEQ.s	ErroreSchermo
	MOVE.L	D0,A0		; Struttura Screen in a0
	MOVE.L	$30(A0),A0	; sc_ViewPort+vp_ColorMap: in a0 ora abbiamo
				; la struttura ColorMap dell schermo, che ci
				; serve (in a0) per eseguire un "video_control"
				; della graphics.library.
	LEA	GETVidCtrlTags(PC),A1	; In a1 la TagList per la routine
					; "Video_control" - la richiesta che
					; facciamo a questa routine e' di
					; VTAG_SPRITERESN_GET, ossia di sapere
					; la risoluzione attuale degli sprite.
	MOVE.L	GfxBase(PC),A6
	JSR	-$2C4(A6)	; Video_Control (in a0 la cm e in a1 i tags)
				; riporta nella taglist, nella long
				; "risoluzione", la risoluzione attuale degli
				; sprite in quello schermo.

; Ora chiediamo alla routine VideoControl di settare la risoluzione.
; SPRITERESN_140NS -> ossia lowres!

	MOVE.L	SchermoWBLocckato(PC),A0
	MOVE.L	$30(A0),A0	; struttura sc_ViewPort+vp_ColorMap in a0
	LEA	SETVidCtrlTags(PC),A1	; TagList che resetta gli sprite.
	MOVE.L	GfxBase(PC),A6
	JSR	-$2C4(A6)	; video_control... resetta gli sprite!

; Ora resettiamo anche l'eventuale schermo "in primo piano", ad esempio la
; schermata dell'assemblatore:

	MOVE.L	IntuiBase(PC),A6
	move.l	$3c(a6),a0	; Ib_FirstScreen (Schermo in "primo piano!")
	MOVE.L	$30(A0),A0	; struttura sc_ViewPort+vp_ColorMap in a0
	LEA	GETVidCtrlTags2(PC),A1	; In a1 la TagList GET
	MOVE.L	GfxBase(PC),A6
	JSR	-$2C4(A6)	; Video_Control (in a0 la cm e in a1 i tags)

	MOVEA.L	IntuiBase(PC),A6
	move.l	$3c(a6),a0	; Ib_FirstScreen - "pesca" lo schermo in
				; primo piano (ad es. ASMONE)
	MOVEA.L	$30(A0),A0	; struttura sc_ViewPort+vp_ColorMap in a0
	LEA	SETVidCtrlTags(PC),A1	; TagList che resetta gli sprite.
	MOVEA.L	GfxBase(PC),A6
	JSR	-$2C4(A6)	; video_control... resetta gli sprite!

	MOVEA.L	SchermoWBLocckato(PC),A0
	MOVEA.L	IntuiBase(PC),A6
	JSR	-$17A(A6)	; _LVOMakeScreen - occorre rifare lo schermo
	move.l	$3c(a6),a0	; Ib_FirstScreen - "pesca" lo schermo in
				; primo piano (ad es. ASMONE)
	JSR	-$17A(A6)	; _LVOMakeScreen - occorre rifare lo schermo
				; per essere sicuri del reset: ossia occorre
				; chiamare MakeScreen, seguito da...
	JSR	-$186(A6)	; _LVORethinkDisplay - che ridisegna tutto il
				; display, comprese ViewPorts e eventuali
ErroreSchermo:			; modi interlace o multisync.
	RTS

; Ora dobbiamo risettare gli sprites alla risoluzione di partenza.

RimettiSprites:
	MOVE.L	SchermoWBLocckato(PC),D0 ; Indirizzo strutt. Screen
	BEQ.S	NonAvevaFunzionato	 ; Se = 0, allora peccato...
	MOVE.L	D0,A0
	MOVE.L	OldRisoluzione(PC),OldRisoluzione2 ; Rimetti vecchia risoluz.
	LEA	SETOldVidCtrlTags(PC),A1
	MOVE.L	$30(A0),A0	; Struttura ColorMap dello screen
	MOVE.L	GfxBase(PC),A6
	JSR	-$2C4(A6)	; _LVOVideoControl - Risetta la risoluzione

; Ora dello schermo in primo piano (eventuale)...

	MOVE.L	IntuiBase(PC),A6
	move.l	$3c(a6),a0	; Ib_FirstScreen - "pesca" lo schermo in
				; primo piano (ad es. ASMONE)
	MOVE.L	OldRisoluzioneP(PC),OldRisoluzione2 ; Rimetti vecchia risoluz.
	LEA	SETOldVidCtrlTags(PC),A1
	MOVE.L	$30(A0),A0	; Struttura ColorMap dello screen
	MOVE.L	GfxBase(PC),A6
	JSR	-$2C4(A6)	; _LVOVideoControl - Risetta la risoluzione

	MOVEA.L	SchermoWBLocckato(PC),A0
	MOVEA.L	IntuiBase(PC),A6
	JSR	-$17A(A6)	; RethinkDisplay - "ripensiamo" il display
	move.l	$3c(a6),a0	; Ib_FirstScreen - schermo in primo piano
	JSR	-$17A(A6)	; RethinkDisplay - "ripensiamo" il display
	MOVE.L	SchermoWBLocckato(PC),A1
	SUB.L	A0,A0		; null
	MOVEA.L	IntuiBase(PC),A6
	JSR	-$204(A6)	; _LVOUnlockPubScreen - e "sblocchiamo" lo
NonAvevaFunzionato:		; screen del workbench.
	RTS

SchermoWBLocckato:
	dc.l	0

; Questa e' la struttura per usare Video_Control. La prima long serve per
; CAMBIARE (SET) la risoluzione degli sprite o per sapere (GET) quella vecchia.

GETVidCtrlTags:
	dc.l	$80000032	; GET
OldRisoluzione:
	dc.l	0	; Risoluzione sprite: 0=ECS, 1=lowres, 2=hires, 3=shres
	dc.l	0,0,0	; 3 zeri per TAG_DONE (terminare la TagList)

GETVidCtrlTags2:
	dc.l	$80000032	; GET
OldRisoluzioneP:
	dc.l	0	; Risoluzione sprite: 0=ECS, 1=lowres, 2=hires, 3=shres
	dc.l	0,0,0	; 3 zeri per TAG_DONE (terminare la TagList)

SETVidCtrlTags:
	dc.l	$80000031	; SET
	dc.l	1	; Risoluzione sprite: 0=ECS, 1=lowres, 2=hires, 3=shres
	dc.l	0,0,0	; 3 zeri per TAG_DONE (terminare la TagList)

SETOldVidCtrlTags:
	dc.l	$80000031	; SET
OldRisoluzione2:
	dc.l	0	; Risoluzione sprite: 0=ECS, 1=lowres, 2=hires, 3=shres
	dc.l	0,0,0	; 3 zeri per TAG_DONE (terminare la TagList)

; Nome schermo del WorkBench

Workbench:
	dc.b	'Workbench',0

******************************************************************************
;	Da qua in avanti si puo' operare sull'hardware in modo diretto
******************************************************************************

HEAVYINIT:
	LEA	$DFF000,A5		; Base dei registri CUSTOM per Offsets
	MOVE.W	$2(A5),OLDDMA		; Salva il vecchio status di DMACON
	MOVE.W	$1C(A5),OLDINTENA	; Salva il vecchio status di INTENA
	MOVE.W	$10(A5),OLDADKCON	; Salva il vecchio status di ADKCON
	MOVE.W	$1E(A5),OLDINTREQ	; Salva il vecchio status di INTREQ
	MOVE.L	#$80008000,d0		; Prepara la maschera dei bit alti
					; da settare nelle word dove sono
					; stati salvati i registri
	OR.L	d0,OLDDMA	; Setta il bit 15 di tutti i valori salvati
	OR.L	d0,OLDADKCON	; dei registri hardware, indispensabile per
				; rimettere tali valori nei registri.

	MOVE.L	#$7FFF7FFF,$9A(a5)	; DISABILITA GLI INTERRUPTS & INTREQS
	MOVE.L	#0,$144(A5)		; SPR0DAT - ammazza il puntatore!
	MOVE.W	#$7FFF,$96(a5)		; DISABILITA I DMA

	move.l	4.w,a6		; ExecBase in a6
	btst.b	#0,$129(a6)	; Testa se siamo su un 68010 o superiore
	beq.s	IntOK		; E' un 68000! Allora la base e' sempre zero.
	lea	SuperCode(PC),a5 ; Routine da eseguire in supervisor
	jsr	-$1e(a6)	; LvoSupervisor - esegui la routine
	bra.s	IntOK		; Abbiamo il valore del VBR, continuiamo...

;**********************CODICE IN SUPERVISORE per 68010+ **********************
SuperCode:
	dc.l  	$4e7a9801	; Movec Vbr,A1 (istruzione 68010+).
				; E' in esadecimale perche' non tutti gli
				; assemblatori assemblano il movec.
	move.l	a1,BaseVBR	; Label dove salvare il valore del VBR
	RTE			; Ritorna dalla eccezione
;*****************************************************************************

BaseVBR:		; Se non modificato, rimane zero! (per 68000).
	dc.l	0

IntOK:
	move.l	BaseVBR(PC),a0	 ; In a0 il valore del VBR
	move.l	$64(a0),OldInt64 ; Sys int liv 1 salvato (softint,dskblk)
	move.l	$68(a0),OldInt68 ; Sys int liv 2 salvato (I/O,ciaa,int2)
	move.l	$6c(a0),OldInt6c ; Sys int liv 3 salvato (coper,vblanc,blit)
	move.l	$70(a0),OldInt70 ; Sys int liv 4 salvato (audio)
	move.l	$74(a0),OldInt74 ; Sys int liv 5 salvato (rbf,dsksync)
	move.l	$78(a0),OldInt78 ; Sys int liv 6 salvato (exter,ciab,inten)

	bsr.w	ClearMyCache

	lea	$dff000,a5	; Custom register in a5
	bsr.w	START		; Esegui il programma.

	bsr.w	ClearMyCache

	LEA	$dff000,a5		; Custom base per offsets
	MOVE.W	#$7FFF,$96(A5)		; DISABILITA TUTTI I DMA
	MOVE.L	#$7FFF7FFF,$9A(A5)	; DISABILITA GLI INTERRUPTS & INTREQS
	MOVE.W	#$7fff,$9E(a5)		; Disabilita i bit di ADKCON

	move.l	BaseVBR(PC),a0	     ; In a0 il valore del VBR
	move.l	OldInt64(PC),$64(a0) ; Sys int liv1 salvato (softint,dskblk)
	move.l	OldInt68(PC),$68(a0) ; Sys int liv2 salvato (I/O,ciaa,int2)
	move.l	OldInt6c(PC),$6c(a0) ; Sys int liv3 salvato (coper,vblanc,blit)
	move.l	OldInt70(PC),$70(a0) ; Sys int liv4 salvato (audio)
	move.l	OldInt74(PC),$74(a0) ; Sys int liv5 salvato (rbf,dsksync)
	move.l	OldInt78(PC),$78(a0) ; Sys int liv6 salvato (exter,ciab,inten)

	MOVE.W	OLDADKCON(PC),$9E(A5)	; ADKCON 
	MOVE.W	OLDDMA(PC),$96(A5)	; Rimetti il vecchio status DMA
	MOVE.W	OLDINTENA(PC),$9A(A5)	; INTENA STATUS
	MOVE.W	OLDINTREQ(PC),$9C(A5)	; INTREQ
	RTS

;	Dati salvati dalla startup

WBVIEW:			; Indirizzo del View del WorkBench
	DC.L	0
GfxName:
	dc.b	'graphics.library',0,0
IntuiName:
	dc.b	'intuition.library',0
DosName:
	dc.b	"dos.library",0
GfxBase:		; Puntatore alla Base della Graphics Library
	dc.l	0
IntuiBase:		; Puntatore alla Base della Intuition Library
	dc.l	0
DosBase:		; Puntatore alla Base della Dos Library
	dc.l	0
OLDDMA:			; Vecchio status DMACON
	dc.w	0
OLDINTENA:		; Vecchio status INTENA
	dc.w	0
OLDADKCON:		; Vecchio status ADKCON
	DC.W	0
OLDINTREQ:		; Vecchio status INTREQ
	DC.W	0

; Vecchi interrupt di sistema

OldInt64:
	dc.l	0
OldInt68:
	dc.l	0
OldInt6c:
	dc.l	0
OldInt70:
	dc.l	0
OldInt74:
	dc.l	0
OldInt78:
	dc.l	0

; Routine da chiamare in caso di codice automodificante, modifica di tabelle
; in fast ram, caricamento da disco, ecc.

ClearMyCache:
	movem.l	d0-d7/a0-a6,-(SP)
	move.l	4.w,a6
	btst.b	#1,$129(a6)	; Testa per un 68020 o superiore
	beq.s	nocaches
	MOVE.W	$14(A6),D0	; lib version
	CMPI.W	#37,D0		; e' V37+? (kick 2.0+)
	blo.s	nocaches	; Se kick1.3, il problema e' che non puo'
				; nemmeno sapere se e' un 68040, per cui
				; e' rischioso.. e si spera che uno
				; stupido che ha un 68020+ su un kick1.3
				; abbia anche le caches disabilitate!
	jsr	-$27c(a6)	; cache cleaR U (per load, modifiche ecc.)
nocaches:
	movem.l	(sp)+,d0-d7/a0-a6
	rts

