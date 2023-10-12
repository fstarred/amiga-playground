# Game trainers

## DOS disks

### How to create a trainer (DOS disk)

The typical steps for creating a trainer for a DOS game are:

1. Create a splash screen with available menu, then store user's selection somewhere on available RAM
2. Create a patch code
3. Call [LoadSeg()][2] function with game executable. This will load file and allocate it on available ram, returning the pointer on it.
4. Find the final JMP address that the packed file will jump to after depacking has finished.
5. Replace the JMP address with the patch code
6. After patch code is applied, let JMP to original address (point 5)
6. Jump to the pointer returned by LoadSeg()

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
