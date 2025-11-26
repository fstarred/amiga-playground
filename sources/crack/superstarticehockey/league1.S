***************************************
*
*	 Superstar Ice Hockey
*	    
*	Original IPF, Tosec 2012-04-10
*
***************************************

; Novella Protection

; just skip the part of the protection with 2 NOP

; That's it !


; DISABLE ReqLibrary BEFORE RUN !!!

	AUTO	RB	\df0:league1\$60000\$80000\
	AUTO	F.L	\$730DA\$730DE\$4E714E71\
	AUTO	WB	\df0:league1\y$60000\$60000+114612\

