
; eFORTH interpreter for SVEU16 consists of the inner interpreter and the outer interpreter. 
; The inner interpreter controls the actions of the computer hardware to execute compiled Forth 
; commands in the form of address lists. The inner interpreter in Forth is generally a very short 
; code fragment inside the executable portion of every command in the memory.
; The outer interpreter is the user interface in Forth. It accepts commands from the user in 
; the text form and executes these commands. Through the outer interpreter, the user can 
; interactively control the entire computer system to do what he wants to accomplish.
; Forth is a computer model which can be implemented on any real CPU with reasonable 
; resources. This model is often called a virtual Forth engine. The minimal components 
; of a virtual Forth engine are: 
; 1. A dictionary to hold all the execution procedures called words. 
; 2. A return stack to hold return addresses of procedures yet to be executed. 
; 3. A data stack to hold parameters passing between procedures. 
; 4. A user area in RAM memory hold all the system variables. 

NUFQD CON 0

CHAR1 CON 1      
CELL1 CON 1      ; Cell size in addressable units
NBITS CON 16     ; cell size in bits
NRP   CON 64     ; Return stack size in cells
NSP   CON 64     ; Data stack size in cells
NTIB  CON 80     ; Terminal buffer size
NPAD  CON 80
ECOMP CON $40    ; Word can be executed only when compiling other word definition
EIMED CON $80    ; Word is executed immediately during compilation
EIMCO CON $C0    ; Word is used immediately only when compile
JPNX1 CON $4F99     ; ORA R15,R9,R9 
NVOCS CON 8         ; Vocabulary strack depth
NDUMP CON 8
ECR   CON 13        ; Carriage return
ELF   CON 10        ; Line feed
EBS   CON 8         ; Backspace
EBL   CON 32        ; Blank
MEMB  CON $0000     ; Start of memory
MEME  CON $AF00     ; End of memory
ETIB  CON $AEB0     ;  MEME-NTIB-2 Terminal Input buffer
ESPP  CON $AEB0     ; ETIB  Start of data stack
ERP   CON $AE70     ;  ESPP-NSP*CELL1  Start of return stack
EUP   CON $AE30     ; ERP-NRP*CELL1 Start of user area

      ORG $0000  ; MEMB


RESET:
      LOD R5,R5,R15        ; JUMP TO COLD START
      WRD VCOLD
      ORA R15,R5,R5
VERSI WRD 13
      TXT "eForth SVEU16"
COPYR WRD $34
      TXT "Copyright 1989-1999 Bill Muench All rights reserved."
      
; In the dictionary, each procedure (more commonly called word in Forth terminology) 
; occupies an area called code field, which contains executable machine code and data 
; required by the code. There are two types of words used in eForth: code word whose 
; code field contains only machine instructions, and colon word whose code field contains 
; an colon word interpreter and a list of the execution addresses of the 
; word in the dictionary. 

; Words in dictionary are presented with their effect on data stack in a form ( before -- after)
; For example ( n m -- r) means that word expects two values on data stack and replaces them with one value.

; Header of each directory word consist of:
;  pointer to the previous word in dictionary
;  length of name
;  name in ASCII (SVEU16 uses 16 bits per char)
;  flags indicating that word is executed immediately when entered, in compile time or both
;  pointer to machine code or start of inner interpreter


  
; We will first define 31 code words, and they are CPU specific:
; In the code field of a code word there is a list of machine instructions of the native CPU. 
; The machine instructions are terminated most commonly by jump to routine NEXT1




;-------------------------------------

; **********************************************************************
; *            CPU SPECIFIC PART: MUST BE WRITTEN IN ASSEMBLY           *
; **********************************************************************
; R0=0
; R1=1

; R2 - DATA STACK POINTER
; R3 - RETURN STACK POINTER
; R4 - IP (INTERRETER POINTER)
; R5 - WORKING REGISTER

; R9 - POINTS TO NEXT1

;   EXIT	( -- )
;		Terminate a colon definition. Exits from word
; Normally used only inside defined words, implicitly at end of every word.
; Example
;    : TEST 1 EXIT 2 ; 
;    TEST
;    On the stack there will be only value 1

      WRD 0
L000  WRD $04
      TXT "EXIT"
      WRD 0
EXITT WRD EXIT1

EXIT1:
      LOD R4,R4,R3
      ADD R3,R3,R1  ; POP IP FROM RETURN STACK
NEXT1:
      LOD R5,R5,R4  ; LOAD R5 FROM ADDRESS POINTED BY IP, POINTS TO START
      ADD R4,R4,R1  ; INC IP
NEXT2:
      LOD R15,R15,R5  ; JUMP TO  ROUTINE

LIST1:              ; TYPICAL ENTRY TO COLON WORDS
      SUB R3,R3,R1  ; PUSH IP TO RETURN STACK
      STO R4,R4,R3
      ADD R4,R5,R1   ; R5 POINTED TO PREFIX WORD, NOW IP POINTS TO FIRST INSTRUCTION

      LOD R5,R5,R4  ; LOAD R5(IP), POINTS TO START
      ADD R4,R4,R1  ; INC IP
      LOD R15,R15,R5  ; JUMP TO  ROUTINE

;   EXECUTE	( ca -- )
;		Execute the word at ca.
; Example: Pointer to word in variable
;   VARIABLE M 
;  ' DUP M !
;  50
;  M @ EXECUTE
      WRD L000
L001  WRD $07
      TXT "EXECUTE"
      WRD 0
EXECU WRD EXEC1
EXEC1 LOD R5,R5,R2   ; POP WORKING REGISTER
      ADD R2,R2,R1
      LOD R15,R5,R5  ; JUMP TO POINTED WORKING REGISTER

  
;   _LIT       ( -- w )
;               Push an inline literal.
; Not to be entered by user. Implicitly generated by compiler

      WRD L001
L002  WRD $04
      TXT "_LIT"
      WRD ECOMP
ULIT  WRD ULIT1
ULIT1 LOD R5,R5,R4    ; GET LITERAL IN NEXT WORD
      ADD R4,R4,R1    ; ADVANCE IP
      SUB R2,R2,R1    ; PUSH LITERAL
      STO R5,R5,R2
      ORA R15,R9,R9  ; JUMP NEXT1

;   _ELSE	( -- )
;		Branch to an inline address.
; Not to be entered by user. Implicitly generated by compiler
      WRD L002
L003  WRD $05
      TXT "_ELSE"
      WRD ECOMP
UELSE WRD UELS1
UELS1 LOD R4,R4,R4    ; SET IP TO INLINE LITERAL
      ORA R15,R9,R9  ; JUMP NEXT1

;   _IF	( f -- )
;		Branch if flag is zero.
; Not to be entered by user. Implicitly generated by compiler
      WRD L003
L004  WRD $03
      TXT "_IF"
      WRD ECOMP
UIF   WRD UIF1
UIF1  LOD R5,R5,R2    ; POP TOP VALUE FROM DATA STACK
      ADD R2,R2,R1
      GTU R6,R5,R0    ; IF R5>0, i.e R5!=0 THEN R6=1     
      ADD R4,R4,R6    ; IF NOT ZERO ADVANCE AFTER LITERAL
      ADD R15,R15,R6  ; SKIP NEXT IF NOT ZERO 
      LOD R4,R4,R4    ; SET IP TO INLINE LITERAL
      ORA R15,R9,R9  ; JUMP NEXT1
;   C!		( c b -- )
;		Pop the data stack to byte memory.
; Example: HEX FF B000 C! pokes to video memory
      WRD L004
L005  WRD $02
      TXT "C!"
      WRD 0
CSTOR WRD CSTO1
CSTO1 LOD R5,R5,R2      ;  POP ADDRESS  SVEU16 HAS NO DIFFERENCE BETWEEN ! AND C!
      ADD R2,R2,R1
      LOD R6,R6,R2      ;  POP VALUE
      ADD R2,R2,R1
      STO R6,R6,R5      ; POKE VALUE
      ORA R15,R9,R9  ; JUMP NEXT1
	  
;   C@		( b -- c )
;		Push byte memory location to the data stack.
; Example: DECIMAL VARIABLE A 500 A ! A C@ .    Assign value to variable and show lower byte of it
      WRD L005
L006  WRD $02
      TXT "C@"
      WRD 0
CAT   WRD CAT1
CAT1  
      ; LOD R7,R7,R15   ; GET CONSTANT
      ;  WRD 255
      LOD R5,R5,R2    ; GET ADDRESS FROM PARAMETER STACK
      LOD R6,R6,R5    ; GET VALUE AT THE ADDRESS
;      AND R6,R6,R7    ; ZERO UPPER 8 BITS
      STO R6,R6,R2    ; STORE VALUE TO THE PARAMETER STACK TOP
      ORA R15,R9,R9  ; JUMP NEXT1
; !		( w a -- )
;		Pop the data stack to memory.
; Example: DECIMAL VARIABLE A 500 A ! A @ .    Assign value to variable and show it
      WRD L006
L007  WRD $01
      TXT "!"
      WRD 0
STORE WRD STOR1
STOR1 LOD R5,R5,R2      ; POP ADDRESS
      ADD R2,R2,R1
      LOD R6,R6,R2      ; POP VALUE
      ADD R2,R2,R1
      STO R6,R6,R5      ; POKE VALUE
      ORA R15,R9,R9    ; JUMP NEXT1
; @		( a -- w )
;		Push memory location value to the data stack.
; Example: DECIMAL VARIABLE A 500 A ! A @ .    Assign value to variable and show it

      WRD L007
L008  WRD $01
      TXT "@"
      WRD 0
ATT   WRD AT1
AT1   LOD R5,R5,R2    ; GET ADDRESS FROM PARAMETER STACK
      LOD R6,R6,R5    ; GET VALUE AT THE ADDRESS
      STO R6,R6,R2    ; STORE VALUE TO THE PARAMETER STACK TOP
      ORA R15,R9,R9  ; JUMP NEXT1
; RP@		( -- a )
;		Push the current RP to the data stack.
; Example: RP@ .  Show address of the data stack
      WRD L008
L009  WRD $03
      TXT "RP@"
      WRD 0
RPAT  WRD RPAT1
RPAT1 SUB R2,R2,R1    ; PUSH RETURN STACK POINTER TO PARAMETER STACK
      STO R3,R3,R2
      ORA R15,R9,R9  ; JUMP NEXT1
; RP!		( a -- )
;		Set the return stack pointer.
; Example: RP@ 1 - RP!  decrement return stack pointer
      WRD L009
L010  WRD $03
      TXT "RP!"
      WRD ECOMP
RPSTO WRD RPST1
RPST1 LOD R3,R3,R2   ; POP RETURN STACK POINTER FROM PARAMETER STACK
      ADD R2,R2,R1
      ORA R15,R9,R9  ; JUMP NEXT1
; >R		( w -- )
;		Push the data stack to the return stack.

      WRD L010
L011  WRD $02
      TXT ">R"
      WRD ECOMP
TOR   WRD TOR1
TOR1  LOD R5,R5,R2    ; POP PARAMETER STACK
      ADD R2,R2,R1
      SUB R3,R3,R1    ; PUSH TO RETURN STACK
      STO R5,R5,R3
      ORA R15,R9,R9  ; JUMP NEXT1
; R@		( -- w )
;		Copy top of return stack to the data stack.
      WRD L011
L012  WRD $02
      TXT "R@"
      WRD 0
RAT   WRD RAT1
RAT1  LOD R5,R5,R3    ; GET TOP OF RETURN STACK
      SUB R2,R2,R1    ; PUSH TO PARAMETER STACK
      STO R5,R5,R2
      ORA R15,R9,R9  ; JUMP NEXT1

; R>		( -- w )
;		Pop the return stack to the data stack.

      WRD L012
L013  WRD $02
      TXT "R>"
      WRD ECOMP
RFROM WRD RFRO1
RFRO1 LOD R5,R5,R3    ; POP RETURN STACK
      ADD R3,R3,R1
      SUB R2,R2,R1    ; PUSH TO PARAMETER STACK
      STO R5,R5,R2
      ORA R15,R9,R9  ; JUMP NEXT1
; SP@		( -- a )
;		Push the current data stack pointer.
      WRD L013
L014  WRD $03
      TXT "SP@"
      WRD 0
SPAT  WRD SPAT1
SPAT1 ORA R5,R2,R2    ; GET PARAMETER STACK POINTER
      SUB R2,R2,R1    ; PUSH TO PARAMETER STACK
      STO R5,R5,R2
      ORA R15,R9,R9  ; JUMP NEXT1


; SP!		( a -- )
;		Set the data stack pointer.
      WRD L014
L015  WRD $03
      TXT "SP!"
      WRD 0
SPSTO WRD SPST1
SPST1 LOD R2,R2,R2    ; GET STACK POINTER FROM PARAMETER STACK TOP
      ORA R15,R9,R9  ; JUMP NEXT1

; DROP	( w -- )
;		Discard top stack item.
; Example: 2 3 4 DROP .  shows 3
      WRD L015
L016  WRD $04
      TXT "DROP"
      WRD 0
DROP  WRD DROP1
DROP1 ADD R2,R2,R1    ; INCREMENT PARAMETER SP
      ORA R15,R9,R9  ; JUMP NEXT1
; SWAP	( w1 w2 -- w2 w1 )
;		Exchange top two stack items.
; Example 2 3 SWAP . .
      WRD L016
L017  WRD $04
      TXT "SWAP"
      WRD 0
SWAP  WRD SWAP1
SWAP1 ORA R6,R2,R2       ; GET PARAMETER SP
      ADD R6,R6,R1       ; INCREMENT IT
      LOD R5,R5,R2       ; GET TOPMOST
      LOD R7,R7,R6       ; GET SECOND
      STO R5,R5,R6       ; PUT FORMER TOPMOST
      STO R7,R7,R2       ; PUT FORMER SECOND
      ORA R15,R9,R9  ; JUMP NEXT1
; DUP		( w -- w w )
;		Duplicate the top stack item.
; Example 5 DUP *   calculates square
      WRD L017
L018  WRD $03
      TXT "DUP"
      WRD 0
DUP   WRD DUP1
DUP1  LOD R5,R5,R2    ; GET TOP OF STACK VALUE
      SUB R2,R2,R1
      STO R5,R5,R2    ; PUSH IT
      ORA R15,R9,R9  ; JUMP NEXT1
; OVER	( w1 w2 -- w1 w2 w1 )
;		Copy second stack item to top.
; Example 2 1 OVER . . . shows 2 1 2
      WRD L018
L019  WRD $04
      TXT "OVER"
      WRD 0
OVER  WRD OVER1
OVER1 ORA R6,R2,R2    ; GET PARAMETER STACK POINTER
      ADD R6,R6,R1    ; VALUE BELOW
      LOD R5,R5,R6    ; GET IT
      SUB R2,R2,R1    ; PUSH IT
      STO R5,R5,R2 
      ORA R15,R9,R9  ; JUMP NEXT1
; CHAR- ( a -- a )
;         Decrement address at top by 1 characer size
; Example: 10 CHAR- .  shows 9
      WRD L019
L020  WRD $05
      TXT "CHAR-"
      WRD 0
CHARM WRD CHRM1
CHRM1 LOD R5,R5,R2    ; DECREMENT VAUE ON PARAMETER STACK
      SUB R5,R5,R1
      STO R5,R5,R2
      ORA R15,R9,R9  ; JUMP NEXT1
; CHAR+ ( a -- a )
;         Increment address at top by 1 characer size
; Example: 10 CHAR+ .  shows 11
      WRD L020
L021  WRD $05
      TXT "CHAR+"
      WRD 0
CHARP WRD CHRP1
CHRP1 LOD R5,R5,R2    ; INCREMENT VALUE ON PARAMETER STACK
      ADD R5,R5,R1
      STO R5,R5,R2
      ORA R15,R9,R9  ; JUMP NEXT1
; CHARS ( a -- a )
;         Multiply address at top by 1 characer size

      WRD L021
L022  WRD $05
      TXT "CHARS"
      WRD EIMED
CHARS WRD CHRS1
CHRS1 ORA R15,R9,R9  ; JUMP NEXT1 DO NOTHING???
; CELL- ( a -- a )
;         Decrement address at top by 1 cell size

      WRD L022
L023  WRD $05
      TXT "CELL-"
      WRD 0
CELLM WRD CELM1
CELM1:
      LOD R5,R5,R2    ; DECREMENT VAUE ON PARAMETER STACK BY ONE CELL
      SUB R5,R5,R1    ; SHOULD BE REPEATED FOR MULTIBYTE CELLS
      STO R5,R5,R2
      ORA R15,R9,R9  ; JUMP NEXT1
; CELL+ ( a -- a )
;         Increment address at top by 1 cell size

      WRD L023
L024  WRD $05
      TXT "CELL+"
      WRD 0
CELLP WRD CELP1
CELP1:
      LOD R5,R5,R2    ; INCREMENT VAUE ON PARAMETER STACK BY ONE CELL
      ADD R5,R5,R1    ; SHOULD BE REPEATED FOR MULTIBYTE CELLS
      STO R5,R5,R2
      ORA R15,R9,R9  ; JUMP NEXT1
; CELLS ( a -- a )
;         Multiply address at top by 1 cell size

      WRD L024
L025  WRD $05
      TXT "CELLS"
      WRD 0
CELLS WRD CELS1
CELS1:
      ORA R15,R9,R9  ; JUMP NEXT1
; 0<		( n -- t )
;		Return true if n is negative.
; Example: 5 0< . returns 0  -5 0< . returns -1
      WRD L025
L026  WRD $02
      TXT "0<"
      WRD 0
ZLESS WRD ZLES1
ZLES1 LOD R5,R5,R2     ; GET PARAMETER STACK TOP
      LTS R5,R5,R0
      SUB R5,R0,R5
      STO R5,R5,R2
      ORA R15,R9,R9  ; JUMP NEXT1
; AND		( w w -- w )
;		Bitwise AND.
; Example HEX 3A F0 AND .  returns 30 
      WRD L026
L027  WRD $03
      TXT "AND"
      WRD 0
ANDD  WRD ANDD1
ANDD1 
      LOD R5,R5,R2    ; POP TOP VALUE FROM PARAMETER STACK
      ADD R2,R2,R1
      LOD R6,R6,R2    ; READ NEW TOP VALUE AT PARAMETER STACK
      AND R5,R5,R6    ; PERFORM LOGICAL OPERATION
      STO R5,R5,R2    ; STORE OPERATION RESULT
      ORA R15,R9,R9  ; JUMP NEXT1
; OR		( w w -- w )
;		Bitwise inclusive OR.
; Example HEX 3A F0 OR .
      WRD L027
L028  WRD $02
      TXT "OR"
      WRD 0
ORR   WRD ORR1
ORR1  LOD R5,R5,R2    ; POP TOP VALUE FROM PARAMETER STACK
      ADD R2,R2,R1
      LOD R6,R6,R2    ; READ NEW TOP VALUE AT PARAMETER STACK
      ORA R5,R5,R6    ; PERFORM LOGICAL OPERATION
      STO R5,R5,R2    ; STORE OPERATION RESULT
      ORA R15,R9,R9  ; JUMP NEXT1
; XOR		( w w -- w )
;		Bitwise exclusive OR.
; Example HEX 3A F0 XOR .
      WRD L028
L029  WRD $03
      TXT "XOR"
      WRD 0
XORR  WRD XORR1
XORR1 LOD R5,R5,R2    ; POP TOP VALUE FROM PARAMETER STACK
      ADD R2,R2,R1
      LOD R6,R6,R2    ; READ NEW TOP VALUE AT PARAMETER STACK
      XOR R5,R5,R6    ; PERFORM LOGICAL OPERATION
      STO R5,R5,R2    ; STORE OPERATION RESULT
      ORA R15,R9,R9  ; JUMP NEXT1
; UM+		( w w -- w cy )
;		Add two numbers, return the sum and carry flag.
; Example: 10 10 UM+ . .  returns 0 and 20
      WRD L029
L030  WRD $03
      TXT "UM+"
      WRD 0
UMPLU WRD UMPL1
UMPL1     
      ADD R7,R2,R1    ; GET ADDRESS OF THE SECOND OPERAND
      LOD R5,R5,R2    ; GET FIRST OPERAND
      LOD R6,R6,R7    ; GET SECOND OPERAND
      ADD R6,R5,R6    ; R6 CONTAINS SUM
      LTU R5,R6,R5    ; IF SUM IS SMALLER THAN OPERAND, R5=CARRY
      STO R5,R5,R2    ; CARRY TO STACK TOP
      STO R6,R6,R7    ; SUM TO BELOW TOP
      ORA R15,R9,R9  ; JUMP NEXT1


; *********************************************************************************
; *        I/O PLATFORM SPECIFIC PART, INIT I/O                                   *
; *********************************************************************************


; !IO		( -- )
;		Initialize the serial I/O devices. Here does nothing
      WRD L030
L031  WRD $03
      TXT "!IO"
      WRD 0
STOIO WRD STIO1
STIO1                  ; ADD CODE TO INITIALIZE I/O
      ORA R15,R9,R9  ; JUMP NEXT1



; *********************************************************************************
; *        I/O PLATFORM SPECIFIC PART, CHARACTER READ                             *
; *********************************************************************************
; ?RX		( -- c T | F )
;		Return input character and true, or a false if no input.
      WRD L031
L032  WRD $03
      TXT "?RX"
      WRD 0
QRX   WRD QRX1
QRX1                 ; ADD CODE TO CHECK KEYBOARD OR SERIAL PORT

      LOD R6,R6,R15  ; GET ADDRESS OF KEYBOARD DEVICE
      WRD $FFF1
      LOD R5,R5,R6   ; GET CHAR
      LOD R7,R7,R15  ; JUMP ADDRESS
      WRD YESCHAR
      EQU R6,R5,R0   ; SET SKIP VALUE
      ADD R15,R15,R6
      ORA R15,R7,R7
NOCHAR:
      SUB R2,R2,R1   ; PUSH FALSE
      STO R0,R0,R2      
      ORA R15,R9,R9  ; JUMP NEXT1
YESCHAR:
      SUB R2,R2,R1   ; PUSH KEY ASCII CODE
      STO R5,R5,R2      
      SUB R5,R0,R1   ; PUSH TRUE
      SUB R2,R2,R1 
      STO R5,R5,R2      
      ORA R15,R9,R9  ; JUMP NEXT1
; *********************************************************************************
; *        PLATFORM SPECIFIC PART, CHARACTER WRITE                                *
; *********************************************************************************

; TX!		( c -- )
;		Send character c to the output device.
; Example: 65 TX!
      WRD L032
L033  WRD $03
      TXT "TX!"
      WRD 0
TXSTO WRD TXST1
TXST1 LOD R5,R5,R2    ; POP CHARACTER TO DISPLAY
      ADD R2,R2,R1   

  ; ADD CODE TO DISPLAY THE CHARACTER

      LOD R12,R12,R15     ; ASCII CHARACTER
      WRD DRAWCHAR
      MAJ R11,R15,R12

      LOD R6,R6,R15  ; GET ADDRESS
      WRD $FFF2
      STO R5,R5,R6      
      ORA R15,R9,R9  ; JUMP NEXT1
; *******************************************************************************
; * PLATFORM SPECIFIC ROUTINE TO PUT CHARACTER IN R5 TO GRAPHICAL VIDEO MEMORY  *
; * RESOLUTION 640x480 MONOCHROME, BIT PER PIXEL AT &B000                       *
; *******************************************************************************

DRAWCHAR:
  SUB R3,R3,R1    ; PUSH R4
  STO R4,R4,R3
  SUB R3,R3,R1    ; PUSH R2
  STO R2,R2,R3
  SUB R3,R3,R1    ; PUSH R9
  STO R9,R9,R3
  SUB R3,R3,R1    ; PUSH R11
  STO R11,R11,R3
  SUB R3,R3,R1     ; PUSH R12
  STO R12,R12,R3
  SUB R0,R0,R0    ; SET R0 TO 0
  LOD R4,R4,R15   ; Get ASCII code of backspace
  WRD EBS
  LOD R11,R11,R15 ; Get address of backspace handling
  WRD DOBS
  EQU R7,R4,R5    ; Are we printing backspace
  MIF R15,R7,R11  ; Jump to backspace handling if yes
  LOD R4,R4,R15  ; Get ASCII code of line feed
  WRD ELF
  LOD R11,R11,R15 ; Get address of line feed handling
  WRD LINEFEED
  EQU R7,R4,R5    ; Are we printing cline feed
  MIF R15,R7,R11  ; Jump to linefeed handling if yes
  LOD R4,R4,R15 ; Get ASCII code of carriage return
  WRD ECR
  LOD R11,R11,R15 ; Get address of carriage return handling 
  WRD DOCR
  EQU R7,R4,R5    ; Are we printing carriage return
  MIF R15,R7,R11 ; Jump to carriage return handling if yes
PRINTABLECH:        ; Printable character
  LOD R8,R8,R15     ; Get address of X coordinate
  WRD XVAL
  LOD R7,R7,R8      ; Get value of X coordinate (Column)
  LOD R8,R8,R15     ; Get address of Y coordinate
  WRD YVAL
  LOD R8,R8,R8      ; Get value of Y coordinate (Row)
  LOD R2,R2,R15     ; 16 pixels are in one word, one row of 640 pixels takes 640/16=40 words, 8 rows take 8x40=320 words
  WRD 320
  MUL R8,R8,R2      ; After row is multiplied by 320 we have relative position of the row start in video memory
  AND R11,R7,R1     ; Lowest bit of Y coordinate (odd=1/even=0) is stored in R11
  SHR R7,R7,R1      ; Divide Y coordinate by 2
  ADD R8,R8,R7      ; Now we point to 16 bit word in video memory where or character is located
  ADD R5,R5,R5      ; Multiply ASCII code by 2
  ADD R5,R5,R5      ; now by 4, because each character in the font definition takes 4 words
  LOD R6,R6,R15     ; Put font definition address to R6
  WRD FONT
  ADD R5,R5,R6      ; Now R5 points to character definition
  LOD R6,R6,R15     ; Address of video memory $B000 to R6
  WRD $B000
  ADD R6,R6,R8      ; Add relative position of the character on the screen. Now R6 points to video memory, R5 to char definition
  LOD R8,R8,R15   ; Mask for upper byte
  WRD $00FF
  LOD R9,R9,R15   ; Mask for lower byte
  WRD $FF00
  LOD R7,R7,R15   ; Distance in video memory to next line
  WRD 40
  LOD R12,R12,R15 ; Rotate 8 times constant
  WRD $38
  LOD R0,R0,R15     ; R0 is loop counter, loop is executed 4 times, from 5 to 1
  WRD 5                  
  LOD R2,R2,R15     ; Address of routine that shows character in right position of 16 bit word in video
  WRD RIGHTCHR
  MIF R15,R11,R2    ; Jump to it if odd column
LEFTCHR:
  ORA R11,R15,R15   ; Remember LEFTLOOP
LEFTLOOP:
  LOD R2,R2,R5    ; Get 2 bytes of font definition
  LOD R4,R4,R6    ; Get 2 bytes from video memory to R4, line 0
  AND R4,R4,R8    ; Left version: keep lower byte (right pixels) from video memory word
  AND R10,R2,R9   ; Upper 8 bits from font to R10
  ORA R4,R4,R10   ; Mix pixels from font and video
  STO R4,R4,R6    ; Store to video memory
  SHR R2,R2,R12   ; Rotate font definition, bring lower pixels to upper
  ADD R6,R6,R7    ; Next row in video memory
  LOD R4,R4,R6    ; Get 2 bytes from video memory to R4 , line 1
  AND R4,R4,R8    ; Left version: keep lower byte
  AND R10,R2,R9   ; Upper 8 bits from font to R10
  ORA R4,R4,R10   ; Mix pixels from font and video
  STO R4,R4,R6    ; Store to video memory
  ADD R6,R6,R7    ; Next row in video memory
  ADD R5,R5,R1    ; Next row in font definiton
  SUB R0,R0,R1    ; Decrement loop counter
  GTU R2,R0,R1    ; If not counter=1
  MIF R15,R2,R11  ; then jump to LEFTLOOP
  LOD R15,R15,R15 ; Absolute jump to NEXTCOL
  WRD NEXTCOL

RIGHTCHR:
  ORA R11,R15,R15   ; Remember RIGHTLOOP
RIGHTLOOP:
  LOD R2,R2,R5    ; Get 2 bytes of font definition
  LOD R4,R4,R6    ; Get 2 bytes from video memory , line 0
  AND R4,R4,R9    ; Right version: keep left pixels from video memory word
  AND R10,R2,R9   ; Upper 8 bits from font to R10
  SHR R10,R10,R12  ; Bring upper pixels of font to lower
  ORA R4,R4,R10   ; Mix pixels from font and video
  STO R4,R4,R6    ; Store to video memory
  ADD R6,R6,R7    ; Next row in video memory
  LOD R4,R4,R6    ; Get 2 bytes from video memory , line 1
  AND R4,R4,R9    ; Right version: keep upper byte from video memory
  AND R10,R2,R8   ; Lower 8 bits from font to R10
  ORA R4,R4,R10   ; Mix pixels from font and video
  STO R4,R4,R6    ; Store to video memory
  ADD R6,R6,R7    ; Next row in video memory
  ADD R5,R5,R1    ; Next row in font definiton
  SUB R0,R0,R1    ; Decrement loop counter
  GTU R2,R0,R1    ; If not counter=1
  MIF R15,R2,R11  ; then jump to RIGHTLOOP

NEXTCOL:           ; Now adjust XCOL variable
  LOD R12,R12,R15  ; Take XVAL address to R12
  WRD XVAL
  LOD R5,R5,R12    ; Get values of XVAL
  ADD R5,R5,R1     ; Increment it
  LOD R4,R4,R15    ; r4=79
  WRD 79
  LOD R11,R11,R15  ; r11 points to NEXTROW
  WRD NEXTROW
  GTU R6,R5,R4     ; If greater than 79
  MIF R15,R6,R11   ; then jump to NEXTROW
  STO R5,R5,R12    ; Store new X position
EXITCHAR:
  SUB R0,R0,R0    ; Store 0 back to R0
  LOD R12,R12,R3 ; POP R12
  ADD R3,R3,R1
  LOD R11,R11,R3  ; POP R11
  ADD R3,R3,R1
  LOD R9,R9,R3  ; POP R9
  ADD R3,R3,R1
  LOD R2,R2,R3  ; POP R2
  ADD R3,R3,R1
  LOD R4,R4,R3  ; POP R4
  ADD R3,R3,R1
  ORA R15,R11,R11 ; jump to saved address and return from MAJ
;---astbit
NEXTROW:           ; We need to go to next row
  SUB R0,R0,R0     ; Put zero to R0
  STO R0,R0,R12    ; Store zero to XVAL
LINEFEED:
  LOD R12,R12,R15  ; Get address of Y coordinate to R12
  WRD YVAL
  LOD R5,R5,R12    ; Get Y coordinate to R5   
  ADD R5,R5,R1     ; Increment
  STO R5,R5,R12    ; Store
  LOD R4,R4,R15    ; R4=60
  WRD 60
  LOD R11,R11,R15  ; Point R11 to EXITCHAR
  WRD EXITCHAR
  LTU R7,R5,R4     ; If new value of char is below 60
  MIF R15,R7,R11   ; Jump to EXIT char
  SUB R4,R4,R1
  STO R4,R4,R12  ; PUT TO LAST ROW CURSOR
SCROLL:          ; We need to scroll
  LOD R4,R4,R15  ; Point R4 to top of video memory
  WRD $B000
  LOD R6,R6,R15  ; Point R6 to 8-th pixel row
  WRD $B140
  LOD R8,R8,R15  ; Length of video memory to be copied
  WRD 18880
  MAJ R11,R15,R15  ; MARK POINT
SCROLLLOOP:
  LOD R5,R5,R6     ; Get word from higher address in video memory (lower on screen)
  STO R5,R5,R4     ; Store it to lower  address in video memory (upper on screen)
  ADD R4,R4,R1     ; Increase pointers in video memory
  ADD R6,R6,R1
  SUB R8,R8,R1     ; Decrease counters
  GTU R7,R8,R0     ; We are at zero?
  MIF R15,R7,R11   ; Jump to scroll loop if not
EMPTYLAST:         ; Last character roww need to be cleared
  LOD R8,R8,R15    ; 320 words is length of this part
  WRD 320
  MAJ R11,R15,R15  ; MARK POINT
EMPTYLASTLP:
  STO R0,R0,R4     ; Clear video word
  ADD R4,R4,R1     ; next position
  SUB R8,R8,R1     ; Decrement counter
  GTU R7,R8,R0     ; We are at zero?
  MIF R15,R7,R11   ; Jump to empty last loop if not 
  LOD R15,R11,R15  ; Jump to EXITCHAR
  WRD EXITCHAR
DOBS:
  LOD R12,R12,R15  ; GET ADDRESS OF X Cursor coordinate to R12
  WRD XVAL
  LOD R8,R8,R15   ; GET ADDRESS OF Y Cursor coordinate to R8
  WRD YVAL
  LOD R6,R6,R12   ; NOW TAKE VALUES OF COORDINATE X
  LOD R9,R9,R8    ; NOW TAKE VALUE OF COORDINATE Y
  GTU R7,R6,R0    ; IS X GREATER THAN 0
  LOD R4,R4,R15   ; TAKE BS1 LABEL TO R4  
  WRD BS1
  MIF R15,R7,R4   ; SKIP UPDATING Y COORDINATE IF NOT X>0
  LOD R6,R6,R15   ; X=80 
  WRD 80
  EQU R10,R9,R0   ; If Y=0 
  ADD R15,R15,R10 : Skip decrementing
  SUB R9,R9,R1    ; DECREMENT Y
BS1:
  SUB R6,R6,R1    ; DECREMENT X
  STO R9,R9,R8    ; PUT NEW X COORDINATE VALUE
  STO R6,R6,R12   ; PUT NEW Y COORDINATE VALUE
  LOD R11,R11,R15
  WRD EXITCHAR
  ORA R15,R11,R11 
DOCR:
  LOD R12,R12,R15 ; READ ADDRESS OF LOCATION THAT KEEPS X COORDINATE OF THE CURRENT CHARACTER (0-79)
  WRD XVAL
  STO R0,R0,R12   ; PUT 0 TO ADDRESS POINTED BY R12
  LOD R11,R11,R15 ; PUT ADDRESS OF EXITCHAR ROUTINE TO R11
  WRD EXITCHAR
  ORA R15,R11,R11 ; JUMP TO EXITCHAR
  
FONT                        ; THIS IS FONT 8x8 PIXELS SEE ASCII 65 TO UNDERSTAND FORMAT
 ; ASCII 0 
  WRD $0000
  WRD $0000
  WRD $0000
  WRD $0000
 ; ASCII 1 
  WRD $7E81
  WRD $A581
  WRD $9DB9
  WRD $817E
 ; ASCII 2 
  WRD $7EFF
  WRD $DBFF
  WRD $E3C7
  WRD $FF7E
 ; ASCII 3 
  WRD $6CFE
  WRD $FEFE
  WRD $7C38
  WRD $1000
 ; ASCII 4 
  WRD $1038
  WRD $7CFE
  WRD $7C38
  WRD $1000
 ; ASCII 5 
  WRD $387C
  WRD $38FE
  WRD $FE10
  WRD $107C
 ; ASCII 6 
  WRD $0018
  WRD $3C7E
  WRD $FF7E
  WRD $187E
 ; ASCII 7 
  WRD $0000
  WRD $183C
  WRD $3C18
  WRD $0000
 ; ASCII 8 
  WRD $FFFF
  WRD $E7C3
  WRD $C3E7
  WRD $FFFF
 ; ASCII 9 
  WRD $003C
  WRD $6642
  WRD $4266
  WRD $3C00
 ; ASCII 10 
  WRD $FFC3
  WRD $99BD
  WRD $BD99
  WRD $C3FF
 ; ASCII 11 
  WRD $0F07
  WRD $0F7D
  WRD $CCCC
  WRD $CC78
 ; ASCII 12 
  WRD $3C66
  WRD $6666
  WRD $3C18
  WRD $7E18
 ; ASCII 13 
  WRD $3F33
  WRD $3F30
  WRD $3070
  WRD $F0E0
 ; ASCII 14 
  WRD $7F63
  WRD $7F63
  WRD $6367
  WRD $E6C0
 ; ASCII 15 
  WRD $995A
  WRD $3CE7
  WRD $E73C
  WRD $5A99
 ; ASCII 16 
  WRD $80E0
  WRD $F8FE
  WRD $F8E0
  WRD $8000
 ; ASCII 17 
  WRD $020E
  WRD $3EFE
  WRD $3E0E
  WRD $0200
 ; ASCII 18 
  WRD $183C
  WRD $7E18
  WRD $187E
  WRD $3C18
 ; ASCII 19 
  WRD $6666
  WRD $6666
  WRD $6600
  WRD $6600
 ; ASCII 20 
  WRD $7FDB
  WRD $DB7B
  WRD $1B1B
  WRD $1B00
 ; ASCII 21 
  WRD $3F60
  WRD $7C66
  WRD $663E
  WRD $06FC
 ; ASCII 22 
  WRD $0000
  WRD $0000
  WRD $7E7E
  WRD $7E00
 ; ASCII 23 
  WRD $183C
  WRD $7E18
  WRD $7E3C
  WRD $18FF
 ; ASCII 24 
  WRD $183C
  WRD $7E18
  WRD $1818
  WRD $1800
 ; ASCII 25 
  WRD $1818
  WRD $1818
  WRD $7E3C
  WRD $1800
 ; ASCII 26 
  WRD $0018
  WRD $0CFE
  WRD $0C18
  WRD $0000
 ; ASCII 27 
  WRD $0030
  WRD $60FE
  WRD $6030
  WRD $0000
 ; ASCII 28 
  WRD $0000
  WRD $C0C0
  WRD $C0FE
  WRD $0000
 ; ASCII 29 
  WRD $0024
  WRD $66FF
  WRD $6624
  WRD $0000
 ; ASCII 30 
  WRD $0018
  WRD $3C7E
  WRD $FFFF
  WRD $0000
 ; ASCII 31 
  WRD $00FF
  WRD $FF7E
  WRD $3C18
  WRD $0000
 ; ASCII 32 
  WRD $0000
  WRD $0000
  WRD $0000
  WRD $0000
 ; ASCII 33 
  WRD $1818
  WRD $1818
  WRD $1800
  WRD $1800
 ; ASCII 34 
  WRD $6C6C
  WRD $6C00
  WRD $0000
  WRD $0000
 ; ASCII 35 
  WRD $6C6C
  WRD $FE6C
  WRD $FE6C
  WRD $6C00
 ; ASCII 36 
  WRD $187E
  WRD $C07C
  WRD $06FC
  WRD $1800
 ; ASCII 37 
  WRD $00C6
  WRD $CC18
  WRD $3066
  WRD $C600
 ; ASCII 38 
  WRD $386C
  WRD $3876
  WRD $DCCC
  WRD $7600
 ; ASCII 39 
  WRD $3030
  WRD $6000
  WRD $0000
  WRD $0000
 ; ASCII 40 
  WRD $0C18
  WRD $3030
  WRD $3018
  WRD $0C00
 ; ASCII 41 
  WRD $3018
  WRD $0C0C
  WRD $0C18
  WRD $3000
 ; ASCII 42 
  WRD $0066
  WRD $3CFF
  WRD $3C66
  WRD $0000
 ; ASCII 43 
  WRD $0018
  WRD $187E
  WRD $1818
  WRD $0000
 ; ASCII 44 
  WRD $0000
  WRD $0000
  WRD $0018
  WRD $1830
 ; ASCII 45 
  WRD $0000
  WRD $007E
  WRD $0000
  WRD $0000
 ; ASCII 46 
  WRD $0000
  WRD $0000
  WRD $0018
  WRD $1800
 ; ASCII 47 
  WRD $060C
  WRD $1830
  WRD $60C0
  WRD $8000
 ; ASCII 48 
  WRD $7CCE
  WRD $DEF6
  WRD $E6C6
  WRD $7C00
 ; ASCII 49 
  WRD $1838
  WRD $1818
  WRD $1818
  WRD $7E00
 ; ASCII 50 
  WRD $7CC6
  WRD $067C
  WRD $C0C0
  WRD $FE00
 ; ASCII 51 
  WRD $FC06
  WRD $063C
  WRD $0606
  WRD $FC00
 ; ASCII 52 
  WRD $0CCC
  WRD $CCCC
  WRD $FE0C
  WRD $0C00
 ; ASCII 53 
  WRD $FEC0
  WRD $FC06
  WRD $06C6
  WRD $7C00
 ; ASCII 54 
  WRD $7CC0
  WRD $C0FC
  WRD $C6C6
  WRD $7C00
 ; ASCII 55 
  WRD $FE06
  WRD $060C
  WRD $1830
  WRD $3000
 ; ASCII 56 
  WRD $7CC6
  WRD $C67C
  WRD $C6C6
  WRD $7C00
 ; ASCII 57 
  WRD $7CC6
  WRD $C67E
  WRD $0606
  WRD $7C00
 ; ASCII 58 
  WRD $0018
  WRD $1800
  WRD $0018
  WRD $1800
 ; ASCII 59 
  WRD $0018
  WRD $1800
  WRD $0018
  WRD $1830
 ; ASCII 60 
  WRD $0C18
  WRD $3060
  WRD $3018
  WRD $0C00
 ; ASCII 61 
  WRD $0000
  WRD $7E00
  WRD $7E00
  WRD $0000
 ; ASCII 62 
  WRD $3018
  WRD $0C06
  WRD $0C18
  WRD $3000
 ; ASCII 63 
  WRD $3C66
  WRD $0C18
  WRD $1800
  WRD $1800
 ; ASCII 64 
  WRD $7CC6
  WRD $DEDE
  WRD $DEC0
  WRD $7E00
 ; ASCII 65 
  WRD $386C
  WRD $C6C6
  WRD $FEC6
  WRD $C600
             ; 38     00111000  ..###...
             ; 6C     01101100  .##.##..
             ; C6     11000110  ##...##.
             ; C6     11000110  ##...##.
             ; FE     11111110  #######.
             ; C6     11000110  ##...##.
             ; C6     11000110  ##...##.
             ; 00     00000000  ........

 ; ASCII 66 
  WRD $FCC6
  WRD $C6FC
  WRD $C6C6
  WRD $FC00
 ; ASCII 67 
  WRD $7CC6
  WRD $C0C0
  WRD $C0C6
  WRD $7C00
 ; ASCII 68 
  WRD $F8CC
  WRD $C6C6
  WRD $C6CC
  WRD $F800
 ; ASCII 69 
  WRD $FEC0
  WRD $C0F8
  WRD $C0C0
  WRD $FE00
 ; ASCII 70 
  WRD $FEC0
  WRD $C0F8
  WRD $C0C0
  WRD $C000
 ; ASCII 71 
  WRD $7CC6
  WRD $C0C0
  WRD $CEC6
  WRD $7C00
 ; ASCII 72 
  WRD $C6C6
  WRD $C6FE
  WRD $C6C6
  WRD $C600
 ; ASCII 73 
  WRD $7E18
  WRD $1818
  WRD $1818
  WRD $7E00
 ; ASCII 74 
  WRD $0606
  WRD $0606
  WRD $06C6
  WRD $7C00
 ; ASCII 75 
  WRD $C6CC
  WRD $D8F0
  WRD $D8CC
  WRD $C600
 ; ASCII 76 
  WRD $C0C0
  WRD $C0C0
  WRD $C0C0
  WRD $FE00
 ; ASCII 77 
  WRD $C6EE
  WRD $FEFE
  WRD $D6C6
  WRD $C600
 ; ASCII 78 
  WRD $C6E6
  WRD $F6DE
  WRD $CEC6
  WRD $C600
 ; ASCII 79 
  WRD $7CC6
  WRD $C6C6
  WRD $C6C6
  WRD $7C00
 ; ASCII 80 
  WRD $FCC6
  WRD $C6FC
  WRD $C0C0
  WRD $C000
 ; ASCII 81 
  WRD $7CC6
  WRD $C6C6
  WRD $D6DE
  WRD $7C06
 ; ASCII 82 
  WRD $FCC6
  WRD $C6FC
  WRD $D8CC
  WRD $C600
 ; ASCII 83 
  WRD $7CC6
  WRD $C07C
  WRD $06C6
  WRD $7C00
 ; ASCII 84 
  WRD $FF18
  WRD $1818
  WRD $1818
  WRD $1800
 ; ASCII 85 
  WRD $C6C6
  WRD $C6C6
  WRD $C6C6
  WRD $FE00
 ; ASCII 86 
  WRD $C6C6
  WRD $C6C6
  WRD $C67C
  WRD $3800
 ; ASCII 87 
  WRD $C6C6
  WRD $C6C6
  WRD $D6FE
  WRD $6C00
 ; ASCII 88 
  WRD $C6C6
  WRD $6C38
  WRD $6CC6
  WRD $C600
 ; ASCII 89 
  WRD $C6C6
  WRD $C67C
  WRD $1830
  WRD $E000
 ; ASCII 90 
  WRD $FE06
  WRD $0C18
  WRD $3060
  WRD $FE00
 ; ASCII 91 
  WRD $3C30
  WRD $3030
  WRD $3030
  WRD $3C00
 ; ASCII 92 
  WRD $C060
  WRD $3018
  WRD $0C06
  WRD $0200
 ; ASCII 93 
  WRD $3C0C
  WRD $0C0C
  WRD $0C0C
  WRD $3C00
 ; ASCII 94 
  WRD $1038
  WRD $6CC6
  WRD $0000
  WRD $0000
 ; ASCII 95 
  WRD $0000
  WRD $0000
  WRD $0000
  WRD $00FF
 ; ASCII 96 
  WRD $1818
  WRD $0C00
  WRD $0000
  WRD $0000
 ; ASCII 97 
  WRD $0000
  WRD $7C06
  WRD $7EC6
  WRD $7E00
 ; ASCII 98 
  WRD $C0C0
  WRD $C0FC
  WRD $C6C6
  WRD $FC00
 ; ASCII 99 
  WRD $0000
  WRD $7CC6
  WRD $C0C6
  WRD $7C00
 ; ASCII 100 
  WRD $0606
  WRD $067E
  WRD $C6C6
  WRD $7E00
 ; ASCII 101 
  WRD $0000
  WRD $7CC6
  WRD $FEC0
  WRD $7C00
 ; ASCII 102 
  WRD $1C36
  WRD $3078
  WRD $3030
  WRD $7800
 ; ASCII 103 
  WRD $0000
  WRD $7EC6
  WRD $C67E
  WRD $06FC
 ; ASCII 104 
  WRD $C0C0
  WRD $FCC6
  WRD $C6C6
  WRD $C600
 ; ASCII 105 
  WRD $1800
  WRD $3818
  WRD $1818
  WRD $3C00
 ; ASCII 106 
  WRD $0600
  WRD $0606
  WRD $0606
  WRD $C67C
 ; ASCII 107 
  WRD $C0C0
  WRD $CCD8
  WRD $F8CC
  WRD $C600
 ; ASCII 108 
  WRD $3818
  WRD $1818
  WRD $1818
  WRD $3C00
 ; ASCII 109 
  WRD $0000
  WRD $CCFE
  WRD $FED6
  WRD $D600
 ; ASCII 110 
  WRD $0000
  WRD $FCC6
  WRD $C6C6
  WRD $C600
 ; ASCII 111 
  WRD $0000
  WRD $7CC6
  WRD $C6C6
  WRD $7C00
 ; ASCII 112 
  WRD $0000
  WRD $FCC6
  WRD $C6FC
  WRD $C0C0
 ; ASCII 113 
  WRD $0000
  WRD $7EC6
  WRD $C67E
  WRD $0606
 ; ASCII 114 
  WRD $0000
  WRD $FCC6
  WRD $C0C0
  WRD $C000
 ; ASCII 115 
  WRD $0000
  WRD $7EC0
  WRD $7C06
  WRD $FC00
 ; ASCII 116 
  WRD $1818
  WRD $7E18
  WRD $1818
  WRD $0E00
 ; ASCII 117 
  WRD $0000
  WRD $C6C6
  WRD $C6C6
  WRD $7E00
 ; ASCII 118 
  WRD $0000
  WRD $C6C6
  WRD $C67C
  WRD $3800
 ; ASCII 119 
  WRD $0000
  WRD $C6C6
  WRD $D6FE
  WRD $6C00
 ; ASCII 120 
  WRD $0000
  WRD $C66C
  WRD $386C
  WRD $C600
 ; ASCII 121 
  WRD $0000
  WRD $C6C6
  WRD $C67E
  WRD $06FC
 ; ASCII 122 
  WRD $0000
  WRD $FE0C
  WRD $3860
  WRD $FE00
 ; ASCII 123 
  WRD $0E18
  WRD $1870
  WRD $1818
  WRD $0E00
 ; ASCII 124 
  WRD $1818
  WRD $1800
  WRD $1818
  WRD $1800
 ; ASCII 125 
  WRD $7018
  WRD $180E
  WRD $1818
  WRD $7000
 ; ASCII 126 
  WRD $76DC
  WRD $0000
  WRD $0000
  WRD $0000
 ; ASCII 127 
  WRD $0010
  WRD $386C
  WRD $C6C6
  WRD $FE00
 ; ASCII 128 
  WRD $7CC6
  WRD $C0C0
  WRD $C0D6
  WRD $7C30
 ; ASCII 129 
  WRD $C600
  WRD $C6C6
  WRD $C6C6
  WRD $7E00
 ; ASCII 130 
  WRD $0E00
  WRD $7CC6
  WRD $FEC0
  WRD $7C00
 ; ASCII 131 
  WRD $7E81
  WRD $3C06
  WRD $7EC6
  WRD $7E00
 ; ASCII 132 
  WRD $6600
  WRD $7C06
  WRD $7EC6
  WRD $7E00
 ; ASCII 133 
  WRD $E000
  WRD $7C06
  WRD $7EC6
  WRD $7E00
 ; ASCII 134 
  WRD $1818
  WRD $7C06
  WRD $7EC6
  WRD $7E00
 ; ASCII 135 
  WRD $0000
  WRD $7CC6
  WRD $C0D6
  WRD $7C30
 ; ASCII 136 
  WRD $7E81
  WRD $7CC6
  WRD $FEC0
  WRD $7C00
 ; ASCII 137 
  WRD $6600
  WRD $7CC6
  WRD $FEC0
  WRD $7C00
 ; ASCII 138 
  WRD $E000
  WRD $7CC6
  WRD $FEC0
  WRD $7C00
 ; ASCII 139 
  WRD $6600
  WRD $3818
  WRD $1818
  WRD $3C00
 ; ASCII 140 
  WRD $7C82
  WRD $3818
  WRD $1818
  WRD $3C00
 ; ASCII 141 
  WRD $7000
  WRD $3818
  WRD $1818
  WRD $3C00
 ; ASCII 142 
  WRD $C610
  WRD $7CC6
  WRD $FEC6
  WRD $C600
 ; ASCII 143 
  WRD $3838
  WRD $007C
  WRD $C6FE
  WRD $C600
 ; ASCII 144 
  WRD $0E00
  WRD $FEC0
  WRD $F8C0
  WRD $FE00
 ; ASCII 145 
  WRD $0000
  WRD $7F0C
  WRD $7FCC
  WRD $7F00
 ; ASCII 146 
  WRD $3F6C
  WRD $CCFF
  WRD $CCCC
  WRD $CF00
 ; ASCII 147 
  WRD $7C82
  WRD $7CC6
  WRD $C6C6
  WRD $7C00
 ; ASCII 148 
  WRD $6600
  WRD $7CC6
  WRD $C6C6
  WRD $7C00
 ; ASCII 149 
  WRD $E000
  WRD $7CC6
  WRD $C6C6
  WRD $7C00
 ; ASCII 150 
  WRD $7C82
  WRD $00C6
  WRD $C6C6
  WRD $7E00
 ; ASCII 151 
  WRD $E000
  WRD $C6C6
  WRD $C6C6
  WRD $7E00
 ; ASCII 152 
  WRD $6600
  WRD $6666
  WRD $663E
  WRD $067C
 ; ASCII 153 
  WRD $C67C
  WRD $C6C6
  WRD $C6C6
  WRD $7C00
 ; ASCII 154 
  WRD $C600
  WRD $C6C6
  WRD $C6C6
  WRD $FE00
 ; ASCII 155 
  WRD $1818
  WRD $7ED8
  WRD $D8D8
  WRD $7E18
 ; ASCII 156 
  WRD $386C
  WRD $60F0
  WRD $6066
  WRD $FC00
 ; ASCII 157 
  WRD $6666
  WRD $3C18
  WRD $7E18
  WRD $7E18
 ; ASCII 158 
  WRD $F8CC
  WRD $CCFA
  WRD $C6CF
  WRD $C6C3
 ; ASCII 159 
  WRD $0E1B
  WRD $183C
  WRD $1818
  WRD $D870
 ; ASCII 160 
  WRD $0E00
  WRD $7C06
  WRD $7EC6
  WRD $7E00
 ; ASCII 161 
  WRD $1C00
  WRD $3818
  WRD $1818
  WRD $3C00
 ; ASCII 162 
  WRD $0E00
  WRD $7CC6
  WRD $C6C6
  WRD $7C00
 ; ASCII 163 
  WRD $0E00
  WRD $C6C6
  WRD $C6C6
  WRD $7E00
 ; ASCII 164 
  WRD $00FE
  WRD $00FC
  WRD $C6C6
  WRD $C600
 ; ASCII 165 
  WRD $FE00
  WRD $C6E6
  WRD $F6DE
  WRD $CE00
 ; ASCII 166 
  WRD $3C6C
  WRD $6C3E
  WRD $007E
  WRD $0000
 ; ASCII 167 
  WRD $3C66
  WRD $663C
  WRD $007E
  WRD $0000
 ; ASCII 168 
  WRD $1800
  WRD $1818
  WRD $3066
  WRD $3C00
 ; ASCII 169 
  WRD $0000
  WRD $00FC
  WRD $C0C0
  WRD $0000
 ; ASCII 170 
  WRD $0000
  WRD $00FC
  WRD $0C0C
  WRD $0000
 ; ASCII 171 
  WRD $C6CC
  WRD $D83F
  WRD $63CF
  WRD $8C0F
 ; ASCII 172 
  WRD $C3C6
  WRD $CCDB
  WRD $376D
  WRD $CF03
 ; ASCII 173 
  WRD $1800
  WRD $1818
  WRD $1818
  WRD $1800
 ; ASCII 174 
  WRD $0033
  WRD $66CC
  WRD $6633
  WRD $0000
 ; ASCII 175 
  WRD $00CC
  WRD $6633
  WRD $66CC
  WRD $0000
 ; ASCII 176 
  WRD $2288
  WRD $2288
  WRD $2288
  WRD $2288
 ; ASCII 177 
  WRD $55AA
  WRD $55AA
  WRD $55AA
  WRD $55AA
 ; ASCII 178 
  WRD $DD77
  WRD $DD77
  WRD $DD77
  WRD $DD77
 ; ASCII 179 
  WRD $1818
  WRD $1818
  WRD $1818
  WRD $1818
 ; ASCII 180 
  WRD $1818
  WRD $1818
  WRD $F818
  WRD $1818
 ; ASCII 181 
  WRD $1818
  WRD $F818
  WRD $F818
  WRD $1818
 ; ASCII 182 
  WRD $3636
  WRD $3636
  WRD $F636
  WRD $3636
 ; ASCII 183 
  WRD $0000
  WRD $0000
  WRD $FE36
  WRD $3636
 ; ASCII 184 
  WRD $0000
  WRD $F818
  WRD $F818
  WRD $1818
 ; ASCII 185 
  WRD $3636
  WRD $F606
  WRD $F636
  WRD $3636
 ; ASCII 186 
  WRD $3636
  WRD $3636
  WRD $3636
  WRD $3636
 ; ASCII 187 
  WRD $0000
  WRD $FE06
  WRD $F636
  WRD $3636
 ; ASCII 188 
  WRD $3636
  WRD $F606
  WRD $FE00
  WRD $0000
 ; ASCII 189 
  WRD $3636
  WRD $3636
  WRD $FE00
  WRD $0000
 ; ASCII 190 
  WRD $1818
  WRD $F818
  WRD $F800
  WRD $0000
 ; ASCII 191 
  WRD $0000
  WRD $0000
  WRD $F818
  WRD $1818
 ; ASCII 192 
  WRD $1818
  WRD $1818
  WRD $1F00
  WRD $0000
 ; ASCII 193 
  WRD $1818
  WRD $1818
  WRD $FF00
  WRD $0000
 ; ASCII 194 
  WRD $0000
  WRD $0000
  WRD $FF18
  WRD $1818
 ; ASCII 195 
  WRD $1818
  WRD $1818
  WRD $1F18
  WRD $1818
 ; ASCII 196 
  WRD $0000
  WRD $0000
  WRD $FF00
  WRD $0000
 ; ASCII 197 
  WRD $1818
  WRD $1818
  WRD $FF18
  WRD $1818
 ; ASCII 198 
  WRD $1818
  WRD $1F18
  WRD $1F18
  WRD $1818
 ; ASCII 199 
  WRD $3636
  WRD $3636
  WRD $3736
  WRD $3636
 ; ASCII 200 
  WRD $3636
  WRD $3730
  WRD $3F00
  WRD $0000
 ; ASCII 201 
  WRD $0000
  WRD $3F30
  WRD $3736
  WRD $3636
 ; ASCII 202 
  WRD $3636
  WRD $F700
  WRD $FF00
  WRD $0000
 ; ASCII 203 
  WRD $0000
  WRD $FF00
  WRD $F736
  WRD $3636
 ; ASCII 204 
  WRD $3636
  WRD $3730
  WRD $3736
  WRD $3636
 ; ASCII 205 
  WRD $0000
  WRD $FF00
  WRD $FF00
  WRD $0000
 ; ASCII 206 
  WRD $3636
  WRD $F700
  WRD $F736
  WRD $3636
 ; ASCII 207 
  WRD $1818
  WRD $FF00
  WRD $FF00
  WRD $0000
 ; ASCII 208 
  WRD $3636
  WRD $3636
  WRD $FF00
  WRD $0000
 ; ASCII 209 
  WRD $0000
  WRD $FF00
  WRD $FF18
  WRD $1818
 ; ASCII 210 
  WRD $0000
  WRD $0000
  WRD $FF36
  WRD $3636
 ; ASCII 211 
  WRD $3636
  WRD $3636
  WRD $3F00
  WRD $0000
 ; ASCII 212 
  WRD $1818
  WRD $1F18
  WRD $1F00
  WRD $0000
 ; ASCII 213 
  WRD $0000
  WRD $1F18
  WRD $1F18
  WRD $1818
 ; ASCII 214 
  WRD $0000
  WRD $0000
  WRD $3F36
  WRD $3636
 ; ASCII 215 
  WRD $3636
  WRD $3636
  WRD $FF36
  WRD $3636
 ; ASCII 216 
  WRD $1818
  WRD $FF18
  WRD $FF18
  WRD $1818
 ; ASCII 217 
  WRD $1818
  WRD $1818
  WRD $F800
  WRD $0000
 ; ASCII 218 
  WRD $0000
  WRD $0000
  WRD $1F18
  WRD $1818
 ; ASCII 219 
  WRD $FFFF
  WRD $FFFF
  WRD $FFFF
  WRD $FFFF
 ; ASCII 220 
  WRD $0000
  WRD $0000
  WRD $FFFF
  WRD $FFFF
 ; ASCII 221 
  WRD $F0F0
  WRD $F0F0
  WRD $F0F0
  WRD $F0F0
 ; ASCII 222 
  WRD $0F0F
  WRD $0F0F
  WRD $0F0F
  WRD $0F0F
 ; ASCII 223 
  WRD $FFFF
  WRD $FFFF
  WRD $0000
  WRD $0000
 ; ASCII 224 
  WRD $0000
  WRD $76DC
  WRD $C8DC
  WRD $7600
 ; ASCII 225 
  WRD $386C
  WRD $6C78
  WRD $6C66
  WRD $6C60
 ; ASCII 226 
  WRD $00FE
  WRD $C6C0
  WRD $C0C0
  WRD $C000
 ; ASCII 227 
  WRD $0000
  WRD $FE6C
  WRD $6C6C
  WRD $6C00
 ; ASCII 228 
  WRD $FE60
  WRD $3018
  WRD $3060
  WRD $FE00
 ; ASCII 229 
  WRD $0000
  WRD $7ED8
  WRD $D8D8
  WRD $7000
 ; ASCII 230 
  WRD $0066
  WRD $6666
  WRD $667C
  WRD $60C0
 ; ASCII 231 
  WRD $0076
  WRD $DC18
  WRD $1818
  WRD $1800
 ; ASCII 232 
  WRD $7E18
  WRD $3C66
  WRD $663C
  WRD $187E
 ; ASCII 233 
  WRD $3C66
  WRD $C3FF
  WRD $C366
  WRD $3C00
 ; ASCII 234 
  WRD $3C66
  WRD $C3C3
  WRD $6666
  WRD $E700
 ; ASCII 235 
  WRD $0E18
  WRD $0C7E
  WRD $C6C6
  WRD $7C00
 ; ASCII 236 
  WRD $0000
  WRD $7EDB
  WRD $DB7E
  WRD $0000
 ; ASCII 237 
  WRD $060C
  WRD $7EDB
  WRD $DB7E
  WRD $60C0
 ; ASCII 238 
  WRD $3860
  WRD $C0F8
  WRD $C060
  WRD $3800
 ; ASCII 239 
  WRD $78CC
  WRD $CCCC
  WRD $CCCC
  WRD $CC00
 ; ASCII 240 
  WRD $007E
  WRD $007E
  WRD $007E
  WRD $0000
 ; ASCII 241 
  WRD $1818
  WRD $7E18
  WRD $1800
  WRD $7E00
 ; ASCII 242 
  WRD $6030
  WRD $1830
  WRD $6000
  WRD $FC00
 ; ASCII 243 
  WRD $1830
  WRD $6030
  WRD $1800
  WRD $FC00
 ; ASCII 244 
  WRD $0E1B
  WRD $1B18
  WRD $1818
  WRD $1818
 ; ASCII 245 
  WRD $1818
  WRD $1818
  WRD $18D8
  WRD $D870
 ; ASCII 246 
  WRD $1818
  WRD $007E
  WRD $0018
  WRD $1800
 ; ASCII 247 
  WRD $0076
  WRD $DC00
  WRD $76DC
  WRD $0000
 ; ASCII 248 
  WRD $386C
  WRD $6C38
  WRD $0000
  WRD $0000
 ; ASCII 249 
  WRD $0000
  WRD $0018
  WRD $1800
  WRD $0000
 ; ASCII 250 
  WRD $0000
  WRD $0000
  WRD $1800
  WRD $0000
 ; ASCII 251 
  WRD $0F0C
  WRD $0C0C
  WRD $EC6C
  WRD $3C1C
 ; ASCII 252 
  WRD $786C
  WRD $6C6C
  WRD $6C00
  WRD $0000
 ; ASCII 253 
  WRD $7C0C
  WRD $7C60
  WRD $7C00
  WRD $0000
 ; ASCII 254 
  WRD $0000
  WRD $3C3C
  WRD $3C3C
  WRD $0000
 ; ASCII 255 
  WRD $0010
  WRD $0000
  WRD $0000
  WRD $0000
  
; XPOS	( -- a )
;		Storage for cursor X position.
; Example XPOS @ .  Show X coordinate of cursor
      WRD L033
L033A WRD $04
      TXT "XPOS"
      WRD 0
XPOS  WRD LIST1  ; Process colon list
      WRD UVAR    ; _VAR  (put to data stack address of next word and exit)
XVAL  WRD 0
; YPOS	( -- a )
;		Storage for cursor Y position.
      WRD L033A
L033B WRD $04
      TXT "YPOS"
      WRD 0
YPOS  WRD LIST1  ; Process colon list
      WRD UVAR    ; _VAR  (put to data stack address of next word and exit)
YVAL  WRD 0
	 
; L!, L@ REMOVED
; *********************************************************************************
; *        WORDS WRITTEN IN FORTH                                                 *
; *********************************************************************************
; About 20 words are commented and recoded in assembly to speed up. When porting eForth 
; to other platform, you can initially revert them to Forth versions, and recode them
; to new assembly later

; NOOP does nothing
; : noop ( -- ) ( 0x7b ) ;
; 


      WRD L033B
L036  WRD $04
      TXT "NOOP"
      WRD 0
NOOP  WRD LIST1  ; Process colon list
      WRD EXITT   ; EXIT  (return from word execution)
; ( system variables )
; 
; : _var ( -- a ) ( 0xb9 ) r> ; compile-only
; _VAR  ( -- a) Returns address in program code just after itself, compile mode only
; Example: Alternative variable definition  : MYVAR _VAR NOOP ;
      WRD L036
L037  WRD $04
      TXT "_VAR"
      WRD ECOMP
UVAR  WRD LIST1  ; Process colon list
      WRD RFROM   ; R> (pop return stack to  data stack)
      WRD EXITT   ; EXIT  (return from word execution)
; : _con ( -- n ) ( 0xba ) r> @ ; compile-only
; _CON  ( -- n) Returns value in program code just after itself, compile mode only

      WRD L037
L038  WRD $04
      TXT "_CON"
      WRD ECOMP
UCON  WRD LIST1  ; Process colon list
      WRD RFROM   ; R> (pop return stack to  data stack)
      WRD ATT     ; @  (put to stack value at address on the stack top)
      WRD EXITT   ; EXIT  (return from word execution)
; 
; create '?key ( input device vector )
;   ' ?rx ,
; '?KEY	( -- a )
;		Execution vector of ?KEY.
      WRD L038
L039  WRD $05
      TXT "'?KEY"
      WRD 0
TQKEY WRD LIST1  ; Process colon list
      WRD UVAR    ; _VAR  (put to data stack address of next word and exit)
      WRD QRX     ; ?RX  (Return input char and true or false if nothing pressed or new)

; create 'emit ( output device vector )
;   ' tx! ,
; 'EMIT	( -- a )
;		Execution vector of EMIT.
      WRD L039
L040  WRD $05
      TXT "'EMIT"
      WRD 0
TEMIT WRD LIST1  ; Process colon list
      WRD UVAR    ; _VAR  (put to data stack address of next word and exit)
      WRD TXSTO   ; TX!  (send character on stack to output device)

; 
; variable base ( numeric radix ) ( 6.1.0750 )( 0xa0 )
; BASE	( -- a )
;		Storage of the radix base for numeric I/O.
      WRD L040
L041  WRD $04
      TXT "BASE"
      WRD 0
BASE  WRD LIST1  ; Process colon list
      WRD UVAR    ; _VAR  (put to data stack address of next word and exit)
      WRD 0

; variable dpl  ( numeric input decimal place )
; DPL	( -- a )
;		numeric input decimal place.
      WRD L041
L042  WRD $03
      TXT "DPL"
      WRD 0
DPL   WRD LIST1  ; Process colon list
      WRD UVAR    ; _VAR  (put to data stack address of next word and exit)
      WRD 0

; variable hld  ( numeric output string pointer )
; HLD		( -- a )
;		Hold a pointer in building a numeric output string.
      WRD L042
L043  WRD $03
      TXT "HLD"
      WRD 0
HLD   WRD LIST1  ; Process colon list
      WRD UVAR    ; _VAR  (put to data stack address of next word and exit)
      WRD 0
; 
; variable >in ( input buffer offset ) ( 6.1.0560 )
; >IN		( -- a )
;		Hold the character pointer while parsing input stream.

      WRD L043
L044  WRD $03
      TXT ">IN"
      WRD 0
TOIN  WRD LIST1  ; Process colon list
      WRD UVAR    ; _VAR  (put to data stack address of next word and exit)
      WRD 0
; create #in   ( input buffer count )
;   2 cells allot ( input buffer address )
; #IN		( -- a )
;		Hold the input buffer count while parsing input stream.

      WRD L044
L045  WRD $03
      TXT "#IN"
      WRD 0
NIN   WRD LIST1  ; Process colon list
      WRD UVAR    ; _VAR  (put to data stack address of next word and exit)
      WRD 0
      WRD 0
; 
; variable csp ( save stack pointer )
; CSP		( -- a )
;		Hold the stack pointer for error checking.
      WRD L045
L046  WRD $03
      TXT "CSP"
      WRD 0
CSP   WRD LIST1  ; Process colon list
      WRD UVAR    ; _VAR  (put to data stack address of next word and exit)
      WRD 0

; 
; create state ( interpret/compile flag ) ( 6.1.2250 )( 0xdc )
;   2 cells allot ( interpret/compile vector )
; STATE	( -- a )
;		Hold the interpret/compile flag.
      WRD L046
L047  WRD $05
      TXT "STATE"
      WRD 0
STATE WRD LIST1  ; Process colon list
      WRD UVAR    ; _VAR  (put to data stack address of next word and exit)
      WRD 0
      WRD 0

; 
; create dp ( dictionary pointer )
;   2 cells allot
; DP		( -- a )
;		Hold the dictionary pointer.
      WRD L047
L048  WRD $02
      TXT "DP"
      WRD 0
DP    WRD LIST1  ; Process colon list
      WRD UVAR    ; _VAR  (put to data stack address of next word and exit)
      WRD HERE0
      WRD 0
; 
; create sup ( -- tid )
;   =rp , ( return stack )
;   =sp , ( data stack )
; SUP		( -- a )
;		Initial stack pointers.

      WRD L048
L049  WRD $03
      TXT "SUP"
      WRD 0
SUP   WRD LIST1  ; Process colon list
      WRD UVAR    ; _VAR  (put to data stack address of next word and exit)
SUP1  WRD EUP
SUPRP WRD ERP
SUPSP WRD ESPP


;   =bl constant bl ( -- c ) ( 6.1.0770 )( 0xa9 )
; BL		( -- 32 )
;		Return 32, the blank character.
      WRD L049
L050  WRD $02
      TXT "BL"
      WRD 0
BLL   WRD LIST1  ; Process colon list
      WRD UCON    ; _CON (get immediate constant after IP and exit)
      WRD EBL     ; value 32

; 
; ( common functions )
; 
; : hex ( -- ) ( 6.2.1660 ) 16 base ! ;
; HEX		( -- )
;		Use radix 16 as base for numeric conversions.
      WRD L050
L051  WRD $03
      TXT "HEX"
      WRD 0
HEXX  WRD LIST1  ; Process colon list
      WRD ULIT    ; push next inline literal
        WRD $10   ; 16
      WRD BASE    ; BASE (return address of variable pointing number base system)
      WRD STORE   ; !  (write value at second stack item to address at stack top)
      WRD EXITT   ; EXIT  (return from word execution)

; : decimal ( -- ) ( 6.1.1170 ) 10 base ! ;
; DECIMAL	( -- )
;		Use radix 10 as base for numeric conversions.
      WRD L051
L052  WRD $07
      TXT "DECIMAL"
      WRD 0
DECIM WRD LIST1  ; Process colon list
      WRD ULIT    ; push next inline literal
        WRD $0A   ; 10
      WRD BASE    ; BASE (return address of variable pointing number base system)
      WRD STORE   ; !  (write value at second stack item to address at stack top)
      WRD EXITT   ; EXIT  (return from word execution)


; : rot ( n1 n2 n3 -- n2 n3 n1 ) ( 6.1.2160 )( 0x4a ) >r swap r> swap ;
; ROT		( w1 w2 w3 -- w2 w3 w1 )
;		Rot 3rd item to top.
;      WRD L052
;L053  WRD $03
;      TXT "ROT"
;      WRD 0
;ROT   WRD LIST1  ; Process colon list
;      WRD TOR     ; >R  (push data stack to return stack)
;      WRD SWAP    ; SWAP  (swap two values at stack top)
;      WRD RFROM   ; R> (pop return stack to  data stack)
;      WRD SWAP    ; SWAP  (swap two values at stack top)
;      WRD EXITT   ; EXIT  (return from word execution)


      WRD L052
L053  WRD $03
      TXT "ROT"
      WRD 0
ROT   WRD ROT1  
ROT1  ADD R5,R2,R1   ; POINTS TO N2
      ADD R6,R5,R1   ; POINTS TO N1
      LOD R7,R7,R2   ; N3 FROM TOP
      LOD R8,R8,R5   ; N2
      LOD R10,R10,R6 ; N1
      STO R10,R10,R2 ; N1 GOES TO TOP
      STO R7,R7,R5   ; n3 TO MIDDLE
      STO R8,R8,R6   ; N2 TO THIRD
      ORA R15,R9,R9   ; JUMP NEXT1
; : nip ( n1 n2 -- n2 ) ( 6.2.1930 )( 0x4d ) swap drop ;
; NIP ( n1 n2 -- n2 )
;  Remove 2nd item from stack
;      WRD L053
;L054  WRD $03
;      TXT "NIP"
;      WRD 0
;NIP   WRD LIST1  ; Process colon list
;      WRD SWAP    ; SWAP  (swap two values at stack top)
;      WRD DROP    ; DROP  (remove value at stack)
;      WRD EXITT   ; EXIT  (return from word execution)

      WRD L053
L054  WRD $03
      TXT "NIP"
      WRD 0
NIP   WRD NIP1 
NIP1  LOD R5,R5,R2    ; POP top
      ADD R2,R2,R1
      STO R5,R5,R2    ; replace
      ORA R15,R9,R9   ; JUMP NEXT1

; : 2drop ( n n -- ) ( 6.1.0370 )( 0x52 ) drop drop ;
; 2DROP	( w w -- )
;		Discard two items on stack.
;      WRD L054
;L055  WRD $05
;      TXT "2DROP"
;      WRD 0
;TDROP WRD LIST1  ; Process colon list
;      WRD DROP    ; DROP  (remove value at stack)
;      WRD DROP    ; DROP  (remove value at stack)
;      WRD EXITT   ; EXIT  (return from word execution)

      WRD L054
L055  WRD $05
      TXT "2DROP"
      WRD 0
TDROP WRD TDRO1  
TDRO1 ADD R2,R2,R1
      ADD R2,R2,R1
      ORA R15,R9,R9   ; JUMP NEXT1

; : 2dup ( n1 n2 -- n1 n2 n1 n2 ) ( 6.1.0380 )( 0x53 ) over over ;
; 2DUP	( w1 w2 -- w1 w2 w1 w2 )
;		Duplicate top two items.
;      WRD L055
;L056  WRD $04
;      TXT "2DUP"
;      WRD 0
;TDUP  WRD LIST1  ; Process colon list
;      WRD OVER    ; OVER  (copy second value at stack to stack top)
;      WRD OVER    ; OVER  (copy second value at stack to stack top)
;      WRD EXITT   ; EXIT  (return from word execution)

      WRD L055
L056  WRD $04
      TXT "2DUP"
      WRD 0
TDUP  WRD TDUP1 
TDUP1 ADD R5,R2,R1   ; POINTS TO N1
      LOD R6,R6,R2   ; N2
      LOD R7,R7,R5   ; N1
      SUB R2,R2,R1   ; push N1
      STO R7,R7,R2
      SUB R2,R2,R1   ; push N2
      STO R6,R6,R2
      ORA R15,R9,R9   ; JUMP NEXT1

; : ?dup ( n -- n n | 0 ) ( 6.1.0630 )( 0x50 ) dup if dup then ;
; ?DUP	( w -- w w | 0 )
;		Dup tos if its is not zero.
;      WRD L056
;L057  WRD $04
;      TXT "?DUP"
;      WRD 0
;QDUP  WRD LIST1  ; Process colon list
;      WRD DUP     ; DUP  (duplicate value at stack top)
;      WRD UIF     ; jump to next inline literal if top of stack is nonzero
;        WRD QDUP1
;      WRD DUP     ; DUP  (duplicate value at stack top)
;QDUP1 WRD EXITT   ; EXIT  (return from word execution)

      WRD L056
L057  WRD $04
      TXT "?DUP"
      WRD 0
QDUP  WRD QDUP1  
QDUP1 LOD R5,R5,R2
      EQU R6,R5,R0
      ADD R15,R15,R6
      SUB R2,R2,R1
      STO R5,R5,R2
      ORA R15,R9,R9   ; JUMP NEXT1


; 
; : + ( n n -- n ) ( 6.1.0120 )( 0x1e ) um+ drop ;
; +		( w w -- sum )
;		Add top two items.
;      WRD L057
;L058  WRD $01
;      TXT "+"
;      WRD 0
;PLUS  WRD LIST1  ; Process colon list
;      WRD UMPLU   ; UM+  (add two numbers on stack, put sum and carry)
;      WRD DROP    ; DROP  (remove value at stack: carry)
;      WRD EXITT   ; EXIT  (return from word execution)
      
      WRD L057
L058  WRD $01
      TXT "+"
      WRD 0
PLUS  WRD PLUS0
PLUS0 LOD R5,R5,R2    ; POP TOP VALUE FROM PARAMETER STACK
      ADD R2,R2,R1
      LOD R6,R6,R2    ; READ NEW TOP VALUE AT PARAMETER STACK
      ADD R5,R5,R6    ; PERFORM ADDITION
      STO R5,R5,R2    ; STORE OPERATION RESULT
      ORA R15,R9,R9   ; JUMP NEXT1





; : d+ ( d d -- d ) ( 8.6.1.1040 )( 0xd8 ) >r  swap >r  um+  r> +  r> + ;
; D+		( d d -- d )
;		Double addition
;      WRD L058
;L059  WRD $02
;      TXT "D+"
;      WRD 0
;DPLUS WRD LIST1  ; Process colon list  initial data stack n1lo n1hi n2lo n2hi
;      WRD TOR     ; >R  (push data stack to return stack, ds: n1lo n1hi n2lo)
;      WRD SWAP    ; SWAP  (swap two values at stack top, ds: n1lo n2lo n1hi)
;      WRD TOR     ; >R  (push data stack to return stack, ds; n1lo n2lo )
;      WRD UMPLU   ; UM+  (add two numbers on stack, put sum and carry, data stack n1lo+n2lo carry )
;      WRD RFROM   ; R> (pop return stack to  data stack, ds: n1lo+n2lo carry n1hi )
;      WRD PLUS    ; + (add two numbers on stack ds: n1lo+n2lo carry+n1hi)
;      WRD RFROM   ; R> (pop return stack to data stack ds: n1lo+n2lo carry+n1hi n2hi)
;      WRD PLUS    ; + (add two numbers on stack  ds: n1lo+n2lo carry+n1hi+n2hi)
;      WRD EXITT   ; EXIT  (return from word execution)

      WRD L058
L059  WRD $02
      TXT "D+"
      WRD 0
DPLUS WRD DPLU1
DPLU1 LOD R5,R5,R2   ; POP HI FIRST NUMBER
      ADD R2,R2,R1
      LOD R6,R6,R2   ; POP LO FIRST NUMBER
      ADD R2,R2,R1
      LOD R7,R7,R2   ; GET HI SECOND NUMBER
      ADD R10,R2,R1
      LOD R8,R8,R10  ; GET LO SECOND NUMBER, DO NOT CHANGE SP
      ADD R6,R8,R6   ; ADD LO
      LTU R8,R6,R8   ; MAKE CARRY
      ADD R5,R5,R7   ; ADD HI
      ADD R5,R5,R8   ; ADD CARRY TO HI
      STO R5,R5,R2   ; STORE HI
      STO R6,R6,R10  ; STORE LO
      ORA R15,R9,R9   ; JUMP NEXT1


; : invert ( n -- n ) ( 6.1.1720 )( 0x26 ) -1 xor ;
; INVERT ( n -- n )
; One complement of the stack top
;      WRD L059
;L060  WRD $06
;      TXT "INVERT"
;      WRD 0
;INVER WRD LIST1  ; Process colon list
;      WRD ULIT    ; push next inline literal
;        WRD $FFFF
;      WRD XORR    ; XOR  (bitwise XOR between two numbers on stack)
;      WRD EXITT   ; EXIT  (return from word execution)

      WRD L059
L060  WRD $06
      TXT "INVERT"
      WRD 0
INVER WRD INVE1
INVE1 LOD R5,R5,R2    ; GET TOP VALUE FROM PARAMETER STACK
      SUB R6,R0,R1    ; FFFF
      XOR R5,R6,R5
      STO R5,R5,R2
      ORA R15,R9,R9   ; JUMP NEXT1

; 
; : negate ( n -- n ) ( 6.1.1910 )( 0x2c ) invert 1 + ;
; NEGATE	( n -- -n )
;		Two's complement of tos.

;      WRD L060
;L061  WRD $06
;      TXT "NEGATE"
;      WRD 0
;NEGAT WRD LIST1  ; Process colon list
;      WRD INVER   ; INVERT  (one complement of stack top)
;      WRD ULIT    ; push next inline literal
;        WRD $01
;      WRD PLUS    ; + (add two numbers on stack)
;      WRD EXITT   ; EXIT  (return from word execution)

      WRD L060
L061  WRD $06
      TXT "NEGATE"
      WRD 0
NEGAT WRD NEG1
NEG1: LOD R5,R5,R2    ; GET TOP VALUE FROM PARAMETER STACK
      SUB R5,R0,R5
      STO R5,R5,R2
      ORA R15,R9,R9   ; JUMP NEXT1

; : dnegate ( d -- d ) ( 8.6.1.1230 ) invert >r invert 1 um+ r> + ;
; DNEGATE	( d -- -d )
;		Two's complement of top double.
      WRD L061
L062  WRD $07
      TXT "DNEGATE"
      WRD 0
DNEGA WRD LIST1  ; Process colon list
      WRD INVER   ; INVERT  (one complement of stack top, invert upper word)
      WRD TOR     ; >R  (push data stack to return stack, save upper word and pop)
      WRD INVER   ; INVERT  (one complement of stack top, invert lower word)
      WRD ULIT    ; push next inline literal
        WRD $01
      WRD UMPLU   ; UM+  (add two numbers on stack, put sum and carry, lower word incremented 2KK)
      WRD RFROM   ; R> (pop return stack to  data stack, brings upper word)
      WRD PLUS    ; + (add two numbers on stack, i.e. upper word with carry)
      WRD EXITT   ; EXIT  (return from word execution)


; 
; : s>d ( n -- d ) ( 6.1.2170 ) dup 0< ;
; S>D ( n -- d )
; Convert single to double number by sign extension
      WRD L062
L063  WRD $03
      TXT "S>D"
      WRD 0
STOD  WRD LIST1  ; Process colon list
      WRD DUP     ; DUP  (duplicate value at stack top)
      WRD ZLESS   ; 0<  (true if negative number on stack, All ones or all zeros, sign extend)
      WRD EXITT   ; EXIT  (return from word execution)


; : abs ( n -- u ) ( 6.1.0690 )( 0x2d ) dup 0< if negate then ;
; ABS		( n -- n )
;		Return the absolute value of n.
;      WRD L063
;L064  WRD $03
;      TXT "ABS"
;      WRD 0
;ABSS  WRD LIST1  ; Process colon list
;      WRD DUP     ; DUP  (duplicate value at stack top)
;      WRD ZLESS   ; 0<  (true if negative number on stack)
;      WRD UIF     ; jump to next inline literal if top of stack is nonzero
;        WRD ABS1
;      WRD NEGAT   ; NEGATE  (change sign of number at stack top, skipped for positive numbers)
;ABS1  WRD EXITT   ; EXIT  (return from word execution)

      WRD L063
L064  WRD $03
      TXT "ABS"
      WRD 0
ABSS  WRD ABS1
ABS1  LOD R5,R5,R2    ; GET VALUE
      GTS R8,R5,R0    ; IS POSITIVE
      ADD R15,R15,R8  ; SKIP NEGATION IF YES
      SUB R5,R0,R5    ; NEGATE
      STO R5,R5,R2    ; STORE
      ORA R15,R9,R9   ; JUMP NEXT1



; : dabs ( d -- ud ) ( 8.6.1.1160 ) dup 0< if dnegate then ;
; DABS ( d -- ud )
;     Return absolute value of double number
      WRD L064
L065  WRD $04
      TXT "DABS"
      WRD 0
DABS  WRD LIST1  ; Process colon list
      WRD DUP     ; DUP  (duplicate value at stack top)
      WRD ZLESS   ; 0<  (true if negative number on stack)
      WRD UIF     ; jump to next inline literal if top of stack is nonzero
        WRD DABS1
      WRD DNEGA   ; DNEGATE (complement double numer)
DABS1 WRD EXITT   ; EXIT  (return from word execution)



; 
; : - ( n n -- n ) ( 6.1.0160 )( 0x1f ) negate + ;
; -		( n1 n2 -- n1-n2 )
;		Subtraction.
;      WRD L065
;L066  WRD $01
;      TXT "-"
;      WRD 0
;MINUS WRD LIST1  ; Process colon list
;      WRD NEGAT   ; NEGATE  (change sign of number at stack top)
;      WRD PLUS    ; + (add two numbers on stack)
;      WRD EXITT   ; EXIT  (return from word execution)


      WRD L065
L066  WRD $01
      TXT "-"
      WRD 0
MINUS WRD MINU1
MINU1 
      LOD R5,R5,R2    ; POP TOP VALUE FROM PARAMETER STACK
      ADD R2,R2,R1
      LOD R6,R6,R2    ; READ NEW TOP VALUE AT PARAMETER STACK
      SUB R5,R6,R5    ; PERFORM SUBTRACTION OPERATION
      STO R5,R5,R2    ; STORE OPERATION RESULT
      ORA R15,R9,R9   ; JUMP NEXT1


; 
; : pick ( n -- n ) ( 6.2.2030 )( 0x50 )
;   ?dup if swap >r 1 - recurse r> swap exit then dup ;
; PICK  ( xu...x1 x0 u -- xu...x1 x0 xu )
;   Remove u. Copy the xu to the top of the stack.
;      WRD L066
;L067  WRD $04
;      TXT "PICK"
;      WRD 0
;PICK  WRD LIST1  ; Process colon list
;      WRD QDUP    ; ?DUP (duplicate number on stack top if it is not zero)
;      WRD UIF     ; jump to next inline literal if top of stack is nonzero, itemindex
;        WRD PICK1
;      WRD SWAP    ; SWAP  (swap two values at stack top, item index goes down)
;      WRD TOR     ; >R  (push data stack to return stack, topmost item saved, item index at stack tom)
;      WRD ULIT    ; push next inline literal
;        WRD $01
;      WRD MINUS   ; -  (subtract numbers at stack top, item index at top)
;      WRD PICK    ; PICK (recursive call)
;      WRD RFROM   ; R> (pop return stack to  data stack, brings item back to data stack)
;      WRD SWAP    ; SWAP  (swap two values at stack top, item bubbles up)
;      WRD EXITT   ; EXIT  (return from word execution)
;PICK1 WRD DUP     ; DUP  (duplicate value at stack top, xu found and make a copy)
;      WRD EXITT   ; EXIT  (return from word execution)

      WRD L066
L067  WRD $04
      TXT "PICK"
      WRD 0
PICK  WRD PICK1
PICK1 LOD R5,R5,R2    ; GET TOP VALUE FROM PARAMETER STACK
      ADD R5,R5,R2    ; ADD STACK POINTER TO IT
      ADD R5,R5,R1    ; +1
      LOD R5,R5,R5    ; GET VALUE AT THIS ADDRESS
      STO R5,R5,R2    ; PUT ON STACK
      ORA R15,R9,R9   ; JUMP NEXT1

; 
; ( comparison )
; 
; : 0= ( n -- f ) ( 6.1.0270 )( 0x34 ) if 0 exit then -1 ;
; 0=          ( n -- f ) 
; Test if number equal to zero
;      WRD L067
;L068  WRD $02
;      TXT "0="
;      WRD 0
;ZEQ   WRD LIST1  ; Process colon list
;      WRD UIF     ; jump to next inline literal if top of stack is nonzero
;        WRD ZEQ1
;      WRD ULIT    ; push next inline literal 0
;        WRD 0
;      WRD EXITT   ; EXIT  (return from word execution)
;ZEQ1  WRD ULIT    ; push next inline literal -1
;        WRD $FFFF
;      WRD EXITT   ; EXIT  (return from word execution)

      WRD L067
L068  WRD $02
      TXT "0="
      WRD 0
ZEQ   WRD ZEQ1
ZEQ1  LOD R5,R5,R2    ; GET TOP VALUE FROM PARAMETER STACK
      EQU R5,R5,R0
      SUB R5,R0,R5
      STO R5,R5,R2
      ORA R15,R9,R9   ; JUMP NEXT1

; : = ( n n -- f ) ( 6.1.0530 )( 0x3c ) xor 0= ;
; =		( w w -- t )
;		Return true if top two are equal.
;      WRD L068
;L069  WRD $01
;      TXT "="
;      WRD 0
;EQUAL WRD LIST1  ; Process colon list
;      WRD XORR    ; XOR  (bitwise XOR between two numbers on stack)
;      WRD ZEQ     ; 0= (is number equal zero)
;      WRD EXITT   ; EXIT  (return from word execution)

      WRD L068
L069  WRD $01
      TXT "="
      WRD 0
EQUAL WRD EQUA1
EQUA1 
      LOD R5,R5,R2    ; POP TOP VALUE FROM PARAMETER STACK
      ADD R2,R2,R1
      LOD R6,R6,R2    ; READ NEW TOP VALUE AT PARAMETER STACK
      EQU R5,R6,R5    ; PERFORM EQUALITY OPERATION
      SUB R5,R0,R5    ; CONVERT 1 TO -1, 0 TO 0
      STO R5,R5,R2    ; STORE OPERATION RESULT
      ORA R15,R9,R9   ; JUMP NEXT1
; 
; : u< ( u u -- f ) ( 6.1.2340 )( 0x40 ) 2dup xor 0< if  nip 0< exit then - 0< ;
; U<		( u u -- t )
;		Unsigned compare of top two items.
;      WRD L069
;L070  WRD $02
;      TXT "U<"
;      WRD 0
;ULESS WRD LIST1  ; Process colon list
;      WRD TDUP    ; 2DUP (duplicate top two numbers)
;      WRD XORR    ; XOR  (bitwise XOR between two numbers on stack)
;      WRD ZLESS   ; 0<  (true if negative number on stack, means numbers have different highest bits)
;      WRD UIF     ; jump to next inline literal if top of stack is nonzero
;        WRD ULES1
;      WRD NIP     ; NIP (remove 2nd item from stack)
;      WRD ZLESS   ; 0<  (true if negative number on stack, here negative means bigger)
;      WRD EXITT   ; EXIT  (return from word execution)
;ULES1 WRD MINUS   ; -  (subtract numbers at stack top)
;      WRD ZLESS   ; 0<  (true if negative number on stack)
;      WRD EXITT   ; EXIT  (return from word execution)

      WRD L069
L070  WRD $02
      TXT "U<"
      WRD 0
ULESS WRD ULES1
ULES1 
      LOD R5,R5,R2    ; POP TOP VALUE FROM PARAMETER STACK
      ADD R2,R2,R1
      LOD R6,R6,R2    ; READ NEW TOP VALUE AT PARAMETER STACK
      LTU R5,R6,R5    ; PERFORM LESS THAN UNSIGNED OPERATION
      SUB R5,R0,R5    ; CONVERT 1 TO -1, 0 TO 0
      STO R5,R5,R2    ; STORE OPERATION RESULT
      ORA R15,R9,R9   ; JUMP NEXT1

; :  < ( n n -- f ) ( 6.1.0480 )( 0x3a ) 2dup xor 0< if drop 0< exit then - 0< ;
; <		( n1 n2 -- t )
;		Signed compare of top two items. Is second number on stack less than top number?
;      WRD L070
;L071  WRD $01
;      TXT "<"
;      WRD 0
;LESS  WRD LIST1  ; Process colon list
;      WRD TDUP    ; 2DUP (duplicate top two numbers)
;      WRD XORR    ; XOR  (bitwise XOR between two numbers on stack)
;      WRD ZLESS   ; 0<  (true if negative number on stack)
;      WRD UIF     ; jump to next inline literal if top of stack is nonzero
;        WRD LESS1
;      WRD DROP    ; DROP  (remove value at stack)
;      WRD ZLESS   ; 0<  (true if negative number on stack)
;      WRD EXITT   ; EXIT  (return from word execution)
;LESS1 WRD MINUS   ; -  (subtract numbers at stack top)
;      WRD ZLESS   ; 0<  (true if negative number on stack)
;      WRD EXITT   ; EXIT  (return from word execution)
; Replaced fith faster and shorter assembly version and added 2 new words > and U>

      WRD L070
L070A WRD $01
      TXT ">"
      WRD 0
GRTR  WRD GRTR1
GRTR1 
      LOD R5,R5,R2    ; POP TOP VALUE FROM PARAMETER STACK
      ADD R2,R2,R1
      LOD R6,R6,R2    ; READ NEW TOP VALUE AT PARAMETER STACK
      GTS R5,R6,R5    ; PERFORM GREATER THAN SIGNED OPERATION
      SUB R5,R0,R5    ; CONVERT 1 TO -1, 0 TO 0
      STO R5,R5,R2    ; STORE OPERATION RESULT
      ORA R15,R9,R9   ; JUMP NEXT1

      WRD L070A
L070B WRD $02
      TXT "U>"
      WRD 0
UGRTR WRD UGRTR1
UGRTR1 
      LOD R5,R5,R2    ; POP TOP VALUE FROM PARAMETER STACK
      ADD R2,R2,R1
      LOD R6,R6,R2    ; READ NEW TOP VALUE AT PARAMETER STACK
      GTU R5,R6,R5    ; PERFORM GREATER THAN UNSIGNED OPERATION
      SUB R5,R0,R5    ; CONVERT 1 TO -1, 0 TO 0
      STO R5,R5,R2    ; STORE OPERATION RESULT
      ORA R15,R9,R9   ; JUMP NEXT1

      WRD L070B
L071  WRD $01
      TXT "<"
      WRD 0
LESS  WRD LESS1
LESS1 
      LOD R5,R5,R2    ; POP TOP VALUE FROM PARAMETER STACK
      ADD R2,R2,R1
      LOD R6,R6,R2    ; READ NEW TOP VALUE AT PARAMETER STACK
      LTS R5,R6,R5    ; PERFORM LESS THAN SIGNED OPERATION
      SUB R5,R0,R5    ; CONVERT 1 TO -1, 0 TO 0
      STO R5,R5,R2    ; STORE OPERATION RESULT
      ORA R15,R9,R9   ; JUMP NEXT1

; 
; : max ( n n -- n ) ( 6.1.1870 )( 0x2f ) 2dup      < if swap then drop ;
; MAX		( n n -- n )
;		Return the greater of two top stack items.
;      WRD L071
;L072  WRD $03
;      TXT "MAX"
;      WRD 0
;MAX   WRD LIST1  ; Process colon list
;      WRD TDUP    ; 2DUP (duplicate top two numbers  ds: a b a b )
;      WRD LESS    ; <  (is second on stack less than top on stack ds: a b a<b )
;      WRD UIF     ; jump to next inline literal if top of stack is nonzero ds: a b
;        WRD MAX1
;      WRD SWAP    ; SWAP  (swap two values at stack top ds: b a)
;MAX1  WRD DROP    ; DROP  (remove value at stack ds: a or ds:b)
;      WRD EXITT   ; EXIT  (return from word execution)

      WRD L071
L072  WRD $03
      TXT "MAX"
      WRD 0
MAX   WRD MAX1
MAX1  LOD R5,R5,R2    ; GET TOP VALUE FROM PARAMETER STACK
      ADD R2,R2,R1
      LOD R6,R6,R2
      GTS R7,R6,R5
      MIF R5,R7,R6
      STO R5,R5,R2
      ORA R15,R9,R9   ; JUMP NEXT1

; : min ( n n -- n ) ( 6.1.1880 )( 0x2e ) 2dup swap < if swap then drop ;
; MIN		( n n -- n )
;		Return the smaller of top two stack items.
;      WRD L072
;L073  WRD $03
;      TXT "MIN"
;      WRD 0
;MIN   WRD LIST1  ; Process colon list
;      WRD TDUP    ; 2DUP (duplicate top two numbers ds: a b a b )
;      WRD SWAP    ; SWAP  (swap two values at stack top ds: a b b a )
;      WRD LESS    ; <  (is second on stack less than top on stack ds: a b b<a )
;      WRD UIF     ; jump to next inline literal if top of stack is nonzero ds: a b 
;        WRD MIN1
;      WRD SWAP    ; SWAP  (swap two values at stack top ds: b a )
;MIN1  WRD DROP    ; DROP  (remove value at stack ds: a or ds:b)
;      WRD EXITT   ; EXIT  (return from word execution)

      WRD L072
L073  WRD $03
      TXT "MIN"
      WRD 0
MIN   WRD MIN1
MIN1  LOD R5,R5,R2    ; GET TOP VALUE FROM PARAMETER STACK
      ADD R2,R2,R1
      LOD R6,R6,R2
      LTS R7,R6,R5
      MIF R5,R7,R6
      STO R5,R5,R2
      ORA R15,R9,R9   ; JUMP NEXT1
; 
; : within ( u ul uh -- f ) ( 6.2.2440 )( 0x45 ) over - >r - r> u< ;
; WITHIN	( u ul uh -- t )
;		Return true if u is within the range of ul and uh.
;      WRD L073
;L074  WRD $06
;      TXT "WITHIN"
;      WRD 0
;WITHI WRD LIST1  ; Process colon list
;      WRD OVER    ; OVER  (copy second value at stack to stack top ds: u ul uh ul)
;      WRD MINUS   ; -  (subtract numbers at stack top ds: u ul uh-ul)
;      WRD TOR     ; >R  (push data stack to return stack ds: u ul )
;      WRD MINUS   ; -  (subtract numbers at stack top ds: u-ul )
;      WRD RFROM   ; R> (pop return stack to  data stack ds: u-ul uh-ul )
;      WRD ULESS   ; U<  (is second on stack unsigned less than top on stack)
;      WRD EXITT   ; EXIT  (return from word execution)

      WRD L073
L074  WRD $06
      TXT "WITHIN"
      WRD 0
WITHI WRD WITH1
WITH1 
      LOD R5,R5,R2    ; POP HI VALUE FROM PARAMETER STACK
      ADD R2,R2,R1
      LOD R6,R6,R2    ; READ LO VALUE AT PARAMETER STACK
      ADD R2,R2,R1
      LOD R7,R7,R2    ; READ TESTED VALUE AT PARAMETER STACK
      LTS R8,R7,R6    ; IF TESTED<LOW
      ADD R15,R15,R8  ; SKIP HITEST
      GTS R8,R7,R5    ; IF TESTED >HI
      XOR R8,R8,R1    ; INVERT TEST
      SUB R8,R0,R8    ; CONVERT 1 TO -1, 0 TO 0
      STO R8,R8,R2    ; STORE OPERATION RESULT
      ORA R15,R9,R9   ; JUMP NEXT1

; 
; ( multiply )
; 
; : lshift ( u n -- u ) ( 6.1.1805 )( 0x27 )
;   begin dup
;   while >r  dup +  r> 1 -
;   repeat drop ;
; LSHIFT ( x1 u -- x2 )
; Perform a logical left shift of u bit-places on x1, giving x2. 

;      WRD L074
;L075  WRD $06
;      TXT "LSHIFT"
;      WRD 0
;LSHIF WRD LIST1  ; Process colon list
;LSHI1 WRD DUP     ; DUP  (duplicate value at stack top)
;      WRD UIF     ; jump to next inline literal if top of stack is nonzero
;        WRD LSHI2
;      WRD TOR     ; >R  (push data stack to return stack (remember shift count))
;      WRD DUP     ; DUP  (duplicate value at stack top , value to shift)
;      WRD PLUS    ; + (add two numbers on stack, shifted number )
;      WRD RFROM   ; R> (pop return stack to  data stack, restore shift count)
;      WRD ULIT    ; push next inline literal, pushes 1
;        WRD $01
;      WRD MINUS   ; -  (subtract numbers at stack top, decrement count)
;      WRD UELSE   ; jump to next inline literal
;        WRD LSHI1
;LSHI2 WRD DROP    ; DROP  (remove value at stack)
;      WRD EXITT   ; EXIT  (return from word execution)

      WRD L074
L075  WRD $06
      TXT "LSHIFT"
      WRD 0
LSHIF WRD LSHI1  
LSHI1 LOD R6,R6,R2    ; POP TOP VALUE FROM PARAMETER STACK, SHIFT AMOUNT
      ADD R2,R2,R1
      LOD R5,R5,R2    ; READ NEW TOP VALUE AT PARAMETER STACK, VALUE TO BE SHIFTED
      LOD R7,R7,R15
      WRD $000F
      GTU R8,R6,R7    ; IF SHIFTED MORE THAN 15 TIMES, RESULT IS 0
      MIF R5,R8,R0
      AND R6,R7,R6    ; MASK AMOUNT
      LOD R7,R7,R15
      WRD $0020
      ORA R6,R7,R6    ; SHIFT KIND
      SHR R5,R5,R6    ; PERFORM LOGIC SHIFT RIGHT
      STO R5,R5,R2    ; STORE OPERATION RESULT
      ORA R15,R9,R9   ; JUMP NEXT1
; 
; : um* ( u u -- ud ) ( 6.1.2360 )( 0xd4 )
;   0 swap  [ #bits ] literal
;   begin dup
;   while >r  dup um+ >r >r  dup um+ r> + r>
;     if >r over um+ r> + then  r> 1 -
;   repeat drop >r  nip r> ;
; UM*		( u u -- ud )
;		Unsigned multiply. Return double product.
;      WRD L075
;L076  WRD $03
;      TXT "UM*"
;      WRD 0
;UMSTA WRD LIST1  ; Process colon list
;      WRD ULIT    ; push next inline literal
;        WRD 0
;      WRD SWAP    ; SWAP  (swap two values at stack top)
;      WRD ULIT    ; push next inline literal (ex. 16, 16 bits)
;        WRD NBITS
;UMST1 WRD DUP     ; DUP  (duplicate value at stack top)
;      WRD UIF     ; jump to next inline literal if top of stack is nonzero
;        WRD UMST3
;      WRD TOR     ; >R  (push data stack to return stack)
;      WRD DUP     ; DUP  (duplicate value at stack top)
;      WRD UMPLU   ; UM+  (add two numbers on stack, put ;;;;sum and carry)
;      WRD TOR     ; >R  (push data stack to return stack;)
;      WRD TOR     ; >R  (push data stack to return stack)
;      WRD DUP     ; DUP  (duplicate value at stack top)
;      WRD UMPLU   ; UM+  (add two numbers on stack, put sum and carry)
;      WRD RFROM   ; R> (pop return stack to  data stack)
;      WRD PLUS    ; + (add two numbers on stack)
;      WRD RFROM   ; R> (pop return stack to  data stack)
;      WRD UIF     ; jump to next inline literal if top of stack is nonzero - i.e carry=1
;        WRD UMST2
;      WRD TOR     ; >R  (push data stack to return stack)
;      WRD OVER    ; OVER  (copy second value at stack to stack top)
;      WRD UMPLU   ; UM+  (add two numbers on stack, put sum and carry)
;      WRD RFROM   ; R> (pop return stack to  data stack)
;      WRD PLUS    ; + (add two numbers on stack)
;UMST2 WRD RFROM   ; R> (pop return stack to  data stack)
;      WRD ULIT    ; push next inline literal
;        WRD $01
;      WRD MINUS   ; -  (subtract numbers at stack top)
;      WRD UELSE   ; jump to next inline literal
;        WRD UMST1
;UMST3 WRD DROP    ; DROP  (remove value at stack)
;      WRD TOR     ; >R  (push data stack to return stack)
;      WRD NIP     ; NIP (remove 2nd item from stack)
;      WRD RFROM   ; R> (pop return stack to  data stack)
;      WRD EXITT   ; EXIT  (return from word execution)

      WRD L075
L076  WRD $03
      TXT "UM*"
      WRD 0
UMSTA WRD UMST1
UMST1 LOD R5,R5,R2         ; POP A (256xAH+AL)
      ADD R2,R2,R1
      LOD R6,R6,R2         ; GET B (256xBH+BL)
      LOD R11,R15,R15      ; R11 contains byte mask 
      WRD $FF
      LOD R12,R15,R15      ; Read shift kind
      WRD $18              ; Right shift 8 times
      AND R7,R5,R11        ; R7=AL
      AND R8,R6,R11        ; R8=BL
      SHR R5,R5,R12        ; R5=AH
      SHR R6,R6,R12        ; R6=BH
      MUL R10,R5,R6        ; R10=AHxBH
      MUL R5,R5,R8         ; R5 =AHxBL
      MUL R6,R7,R6         ; R6=BHxAL
      MUL R7,R7,R8         ; R7=BLxAL
      SHR R8,R5,R12        ; R8=AHxBL  >> 8
      ADD R10,R10,R8       ; R10=AHxBH + AHxBL>> 8
      SHR R8,R6,R12        ; R8=BHxAL >> 8
      ADD R10,R10,R8       ; R10=AHxBH + AHxBL>> 8 + BHxAL >> 8
      LOD R12,R15,R15      ; Read shift kind
      WRD $28              ; left shift 8 times
      SHR R6,R6,R12        ; R6=BHxAL <<8
      SHR R5,R5,R12        ; R5=AHxBL <<8
      ADD R7,R7,R6         ; R7=BLxAL + BHxAL <<8
      LTU R8,R7,R6         ; CARRY?
      ADD R10,R10,R8       ; Add carry
      ADD R7,R7,R5         ; R7=BLxAL + BHxAL <<8  + AHxBL <<8
      LTU R8,R7,R5         ; Carry
      ADD R10,R10,R8       ; Add carry to high word
      STO R7,R7,R2         ; Save low word
      SUB R2,R2,R1         ; Push high word
      STO R10,R10,R2
      ORA R15,R9,R9        ; JUMP NEXT1

      

; 
; : * ( n n -- n ) ( 6.1.0090 )( 0x20 ) um* drop ;
; *		( n n -- n )
;		Signed multiply. Return single product.
;      WRD L076
;L077  WRD $01
;      TXT "*"
;      WRD 0
;STAR  WRD LIST1  ; Process colon list
;      WRD UMSTA   ; UM * unsigned multiply double product
;      WRD DROP    ; DROP  (remove value at stack)
;      WRD EXITT   ; EXIT  (return from word execution)
; Replaced by faster version
; 

      WRD L076
L077  WRD $01
      TXT "*"
      WRD 0
STAR  WRD STAR1
STAR1 LOD R5,R5,R2    ; POP TOP VALUE FROM PARAMETER STACK
      ADD R2,R2,R1
      LOD R6,R6,R2    ; READ NEW TOP VALUE AT PARAMETER STACK
      MUL R5,R5,R6    ; PERFORM MULTIPLICATION
      STO R5,R5,R2    ; STORE OPERATION RESULT
      ORA R15,R9,R9   ; JUMP NEXT1

; ( divide )
; 
; : rshift ( u n -- u ) ( 6.1.2162 )( 0x28 )
;   0 swap  [ #bits ] literal swap -
;   begin dup
;   while >r  2dup d+  r> 1 -
;   repeat drop  nip ;
; RSHIFT  ( x1 u -- x2 )
; Perform a logical right shift of u bit-places on x1, giving x2. 

;      WRD L077
;L078  WRD $06
;      TXT "RSHIFT"
;      WRD 0
;RSHIF WRD LIST1  ; Process colon list
;      WRD ULIT    ; push next inline literal
;        WRD 0
;      WRD SWAP    ; SWAP  (swap two values at stack top)
;      WRD ULIT    ; push next inline literal
;        WRD NBITS
;      WRD SWAP    ; SWAP  (swap two values at stack top)
;      WRD MINUS   ; -  (subtract numbers at stack top)
;RSHI1 WRD DUP     ; DUP  (duplicate value at stack top)
;      WRD UIF     ; jump to next inline literal if top of stack is nonzero
;        WRD RSHI2
;      WRD TOR     ; >R  (push data stack to return stack)
;      WRD TDUP    ; 2DUP (duplicate top two numbers)
;      WRD DPLUS   ; D+ (Doulbe addition)
;      WRD RFROM   ; R> (pop return stack to  data stack)
;      WRD ULIT    ; push next inline literal
;        WRD $01
;      WRD MINUS   ; -  (subtract numbers at stack top)
;      WRD UELSE   ; jump to next inline literal
;        WRD RSHI1
;RSHI2 WRD DROP    ; DROP  (remove value at stack)
;      WRD NIP     ; NIP (remove 2nd item from stack)
;      WRD EXITT   ; EXIT  (return from word execution)

      WRD L077
L078  WRD $06
      TXT "RSHIFT"
      WRD 0
RSHIF WRD RSHI1  
RSHI1 LOD R6,R6,R2    ; POP TOP VALUE FROM PARAMETER STACK, SHIFT AMOUNT
      ADD R2,R2,R1
      LOD R5,R5,R2    ; READ NEW TOP VALUE AT PARAMETER STACK, VALUE TO BE SHIFTED
      LOD R7,R7,R15
      WRD $000F
      GTU R8,R6,R7    ; IF SHIFTED MORE THAN 15 TIMES, RESULT IS 0
      MIF R5,R8,R0
      AND R6,R7,R6    ; MASK AMOUNT
      LOD R7,R7,R15
      WRD $0010
      ORA R6,R7,R6    ; SHIFT KIND
      SHR R5,R5,R6    ; PERFORM LOGIC SHIFT RIGHT
      STO R5,R5,R2    ; STORE OPERATION RESULT
      ORA R15,R9,R9   ; JUMP NEXT1

; 
; : um/mod ( ud u -- ur uq ) ( 6.1.2370 )( 0xd5 )
;   2dup u<
;   if negate  [ #bits ] literal
;     begin dup
;     while >r  >r  dup um+ >r >r  dup um+ r> +
;       dup r> r@ swap >r um+  r> or
;       if >r drop 1 + r> else drop then r>  r> 1 -
;     repeat 2drop swap exit
;   then drop 2drop  -1 dup ;
; UM/MOD	( udl udh u -- ur uq )
;		Unsigned divide of a double by a single. Return mod and quotient.

;      WRD L078
;L079  WRD $06
;      TXT "UM/MOD"
;      WRD 0
;UMMOD WRD LIST1  ; Process colon list
;      WRD TDUP    ; 2DUP (duplicate top two numbers)
;      WRD ULESS   ; U<  (is second on stack unsigned less than top on stack)
;      WRD UIF     ; jump to next inline literal if top of stack is nonzero
;        WRD UMMO5
;      WRD NEGAT   ; NEGATE  (change sign of number at stack top)
;      WRD ULIT    ; push next inline literal
;        WRD NBITS
;UMMO1 WRD DUP     ; DUP  (duplicate value at stack top)
;      WRD UIF     ; jump to next inline literal if top of stack is nonzero
;        WRD UMMO4
;      WRD TOR     ; >R  (push data stack to return stack)
;      WRD TOR     ; >R  (push data stack to return stack)
;      WRD DUP     ; DUP  (duplicate value at stack top)
;      WRD UMPLU   ; UM+  (add two numbers on stack, put sum and carry)
;      WRD TOR     ; >R  (push data stack to return stack)
;      WRD TOR     ; >R  (push data stack to return stack)
;      WRD DUP     ; DUP  (duplicate value at stack top)
;      WRD UMPLU   ; UM+  (add two numbers on stack, put sum and carry)
;      WRD RFROM   ; R> (pop return stack to  data stack)
;      WRD PLUS    ; + (add two numbers on stack)
;      WRD DUP     ; DUP  (duplicate value at stack top)
;      WRD RFROM   ; R> (pop return stack to  data stack)
;      WRD RAT     ; R@ (copy top of return stack to  data stack)
;      WRD SWAP    ; SWAP  (swap two values at stack top)
;      WRD TOR     ; >R  (push data stack to return stack)
;      WRD UMPLU   ; UM+  (add two numbers on stack, put sum and carry)
;      WRD RFROM   ; R> (pop return stack to  data stack)
;      WRD ORR     ; OR  (bitwise OR between two numbers on stack)
;      WRD UIF     ; jump to next inline literal if top of stack is nonzero
;        WRD UMMO2
;      WRD TOR     ; >R  (push data stack to return stack)
;      WRD DROP    ; DROP  (remove value at stack)
;      WRD ULIT    ; push next inline literal
;        WRD $01
;      WRD PLUS    ; + (add two numbers on stack)
;      WRD RFROM   ; R> (pop return stack to  data stack)
;      WRD UELSE   ; jump to next inline literal
;        WRD UMMO3
;UMMO2 WRD DROP    ; DROP  (remove value at stack)
;UMMO3 WRD RFROM   ; R> (pop return stack to  data stack)
;      WRD RFROM   ; R> (pop return stack to  data stack)
;      WRD ULIT    ; push next inline literal
;        WRD $01
;      WRD MINUS   ; -  (subtract numbers at stack top)
;      WRD UELSE   ; jump to next inline literal
;        WRD UMMO1
;UMMO4 WRD TDROP   ; 2DROP remove 2 items from stack
;      WRD SWAP    ; SWAP  (swap two values at stack top)
;      WRD EXITT   ; EXIT  (return from word execution)
;UMMO5 WRD DROP    ; DROP  (remove value at stack)
;      WRD TDROP   ; 2DROP remove 2 items from stack
;      WRD ULIT    ; push next inline literal
;        WRD $FFFF
;      WRD DUP     ; DUP  (duplicate value at stack top)
;      WRD EXITT   ; EXIT  (return from word execution)

; Recoded to faster verson in assembly:

      WRD L078
L079  WRD $06
      TXT "UM/MOD"
      WRD 0
UMMOD WRD UMMO1
UMMO1
      LOD R7,R7,R2    ; DIVISOR FROM PARAMETER STACK
      ADD R2,R2,R1
      LOD R5,R5,R2    ; HIGH WORD OF DIVIDEND PARAMETER STACK
      ADD R2,R2,R1
      LOD R6,R6,R2    ; LOW  WORD OF DIVIDEND PARAMETER STACK
      LOD R11,R11,R15 ; LOOP COUNTER
      WRD 16
      ORA R10,R15,R15 ; REMEMBER LOOP POSITION
      LTS R8,R6,R0    ; SHIFT DIVIDEND (LATER REMAINDER/QUOTIENT) LEFT
      ADD R5,R5,R5    
      ADD R5,R5,R8
      ADD R6,R6,R6
      LTU R8,R5,R7    ; IF CURRENT REMAINDER SMALLER THAN DIVISOR
      ADD R15,R15,R8  ; THEN SKIP SUBTRACTION
      SUB R5,R5,R7    ; SUBTRACT DIVISOR FROM REMAINDER
      XOR R8,R8,R1    ; INVERT BIT
      ADD R6,R6,R8    ; SET QOUTIENT LAST BIT 1 IF REMAINDER >= DIVISOR
      SUB R11,R11,R1  ; DEC LOOP COUNTER
      GTU R8,R11,R0   ; LOOP IF NOT 0
      MIF R15,R8,R10  ; JUMP TO MARKED
      STO R5,R5,R2    ; STORE REMAINDER
      SUB R2,R2,R1
      STO R6,R6,R2    ; STORE QUOTIENT
      ORA R15,R9,R9  ; JUMP NEXT1

; 
; : sm/rem ( d n -- r q ) ( 6.1.2214 ) ( symmetric )
;   over >r >r  dabs r@ abs um/mod
;   r> r@ xor 0< if negate then  r> 0< if >r negate r> then ;
; SM/REM ( d1 n1 -- n2 n3 )
; Divide signed DOUBLE d1 by n1, giving the symmetric quotient n3 and the remainder n2. 
; Symmetric division: d1 = n3*n1+n2, sign(n2)=sign(d1) or 0.
      WRD L079
L080  WRD $06
      TXT "SM/REM"
      WRD 0
SMREM WRD LIST1  ; Process colon list
      WRD OVER    ; OVER  (copy second value at stack to stack top)
      WRD TOR     ; >R  (push data stack to return stack)
      WRD TOR     ; >R  (push data stack to return stack)
      WRD DABS    ; DABS absolute value od fouble number
      WRD RAT     ; R@ (copy top of return stack to  data stack)
      WRD ABSS    ; ABS (absolute value )
      WRD UMMOD   ; UM/MOD (Unsigned divide of a double by a single. Return mod and quotient. )
      WRD RFROM   ; R> (pop return stack to  data stack)
      WRD RAT     ; R@ (copy top of return stack to  data stack)
      WRD XORR    ; XOR  (bitwise XOR between two numbers on stack)
      WRD ZLESS   ; 0<  (true if negative number on stack)
      WRD UIF     ; jump to next inline literal if top of stack is nonzero
        WRD SMRE1
      WRD NEGAT   ; NEGATE  (change sign of number at stack top)
SMRE1 WRD RFROM   ; R> (pop return stack to  data stack)
      WRD ZLESS   ; 0<  (true if negative number on stack)
      WRD UIF     ; jump to next inline literal if top of stack is nonzero
        WRD SMRE2
      WRD TOR     ; >R  (push data stack to return stack)
      WRD NEGAT   ; NEGATE  (change sign of number at stack top)
      WRD RFROM   ; R> (pop return stack to  data stack)
SMRE2 WRD EXITT   ; EXIT  (return from word execution)

; 
; : fm/mod ( d n -- r q ) ( 6.1.1561 ) ( floored )
;   dup 0<  dup >r if negate >r dnegate r> then
;   >r dup 0< if r@ + then r> um/mod r> if >r negate r> then ;
; FM/MOD  d1 n1 -- n2 n3 )
; Divide d1 by n1, giving the floored quotient n3 and the remainder n2. 
; Floored division: d1 = n3*n1+n2, n1>n2>=0 or 0>=n2>n1.
      WRD L080
L081  WRD $06
      TXT "FM/MOD"
      WRD 0
FMMOD WRD LIST1  ; Process colon list
      WRD DUP     ; DUP  (duplicate value at stack top)
      WRD ZLESS   ; 0<  (true if negative number on stack)
      WRD DUP     ; DUP  (duplicate value at stack top)
      WRD TOR     ; >R  (push data stack to return stack)
      WRD UIF     ; jump to next inline literal if top of stack is nonzero
        WRD FMMO1
      WRD NEGAT   ; NEGATE  (change sign of number at stack top)
      WRD TOR     ; >R  (push data stack to return stack)
      WRD DNEGA   ; DNEGATE (2 complement of top double. )
      WRD RFROM   ; R> (pop return stack to  data stack)
FMMO1 WRD TOR     ; >R  (push data stack to return stack)
      WRD DUP     ; DUP  (duplicate value at stack top)
      WRD ZLESS   ; 0<  (true if negative number on stack)
      WRD UIF     ; jump to next inline literal if top of stack is nonzero
        WRD FMMO2
      WRD RAT     ; R@ (copy top of return stack to  data stack)
      WRD PLUS    ; + (add two numbers on stack)
FMMO2 WRD RFROM   ; R> (pop return stack to  data stack)
      WRD UMMOD   ; UM/MOD (Unsigned divide of a double by a single. Return mod and quotient. )
      WRD RFROM   ; R> (pop return stack to  data stack)
      WRD UIF     ; jump to next inline literal if top of stack is nonzero
        WRD FMMO3
      WRD TOR     ; >R  (push data stack to return stack)
      WRD NEGAT   ; NEGATE  (change sign of number at stack top)
      WRD RFROM   ; R> (pop return stack to  data stack)
FMMO3 WRD EXITT   ; EXIT  (return from word execution)

; 
; : /mod ( n n -- r q ) ( 6.1.0240 )( 0x2a ) over 0< swap  fm/mod ; ( or sm/rem )
; /MOD	( n n -- r q )
;		Signed divide. Return mod and quotient.

      WRD L081
L082  WRD $04
      TXT "/MOD"
      WRD 0
SMOD  WRD LIST1  ; Process colon list
      WRD OVER    ; OVER  (copy second value at stack to stack top)
      WRD ZLESS   ; 0<  (true if negative number on stack)
      WRD SWAP    ; SWAP  (swap two values at stack top)
      WRD FMMOD   ; FM/MOD (Divide d1 by n1, giving the floored quotient n3 and the remainder n2. )
      WRD EXITT   ; EXIT  (return from word execution)


; 
; : mod ( n n -- r ) ( 6.1.1890 )( 0x22 ) /mod drop ;
; MOD		( n n -- r )
;		Signed divide. Return mod only.
      WRD L082
L083  WRD $03
      TXT "MOD"
      WRD 0
MODD  WRD LIST1  ; Process colon list
      WRD SMOD    ; /MOD (Signed divide. Return mod and quotient.)
      WRD DROP    ; DROP  (remove value at stack)
      WRD EXITT   ; EXIT  (return from word execution)

; : / ( n n -- q ) ( 6.1.0230 )( 0x21 ) /mod nip ;
; /		( n n -- q )
;		Signed divide. Return quotient only.
      WRD L083
L084  WRD $01
      TXT "/"
      WRD 0
SLASH WRD LIST1  ; Process colon list
      WRD SMOD    ; /MOD (Signed divide. Return mod and quotient.)
      WRD NIP     ; NIP (remove 2nd item from stack)
      WRD EXITT   ; EXIT  (return from word execution)

; ( memory access )
; 
; : +! ( n a -- ) ( 6.1.0130 )( 0x6c ) dup >r @ + r> ! ;
; +!		( n a -- )
;		Add n to the contents at address a.
;      WRD L084
;L085  WRD $02
;      TXT "+!"
;      WRD 0
;PLUST WRD LIST1  ; Process colon list
;      WRD DUP     ; DUP  (duplicate value at stack top)
;      WRD TOR     ; >R  (push data stack to return stack)
;      WRD ATT     ; @  (put to stack value at address on the stack top)
;      WRD PLUS    ; + (add two numbers on stack)
;      WRD RFROM   ; R> (pop return stack to  data stack)
;      WRD STORE   ; !  (write value at second stack item to address at stack top)
;      WRD EXITT   ; EXIT  (return from word execution)

      WRD L084
L085  WRD $02
      TXT "+!"
      WRD 0
PLUST WRD PLST1
PLST1 LOD R5,R5,R2      ; POP ADDRESS
      ADD R2,R2,R1
      LOD R6,R6,R2      ; POP VALUE
      ADD R2,R2,R1
      LOD R7,R7,R5      ; GET VALUE AT ADDRESS
      ADD R6,R6,R7      ; ADD TWO VALUES
      STO R6,R6,R5      ; POKE RESULT
      ORA R15,R9,R9    ; JUMP NEXT1


; : count ( a -- a c ) ( 6.1.0980 )( 0x84 ) dup char+ swap c@ ;
; COUNT	( b -- b +n )
;		Return count byte of a string and add 1 to byte address.
      WRD L085
L086  WRD $05
      TXT "COUNT"
      WRD 0
COUNT WRD LIST1  ; Process colon list
      WRD DUP     ; DUP  (duplicate value at stack top)
      WRD CHARP   ; CHAR+ (Increment address at top by 1 characer size)
      WRD SWAP    ; SWAP  (swap two values at stack top)
      WRD CAT     ; C@ (read byte from address at stack top ))
      WRD EXITT   ; EXIT  (return from word execution)

; : bounds ( a n -- a+n a ) ( 0xac ) over + swap ;
; BOUNDS ( a n -- a+n a )
; Given a memory block represented by starting address addr and length, produce the end address addr+u and the start address
      WRD L086
L087  WRD $06
      TXT "BOUNDS"
      WRD 0
BNDS  WRD LIST1  ; Process colon list
      WRD OVER    ; OVER  (copy second value at stack to stack top)
      WRD PLUS    ; + (add two numbers on stack)
      WRD SWAP    ; SWAP  (swap two values at stack top)
      WRD EXITT   ; EXIT  (return from word execution)

; : /string ( a u n -- a+n u-n ) ( 17.6.1.0245 ) dup >r - swap r> chars + swap ;
; /STRING ( c-addr1 u1 n -- c-addr2 u2 )
; Adjust the character string at c-addr1 by n characters. The resulting string, c-addr2 u2, begins at c-addr1 plus n characters and is u1 minus n characters long.
      WRD L087
L088  WRD $07
      TXT "/STRING"
      WRD 0
SSTRI WRD LIST1  ; Process colon list
      WRD DUP     ; DUP  (duplicate value at stack top)
      WRD TOR     ; >R  (push data stack to return stack)
      WRD MINUS   ; -  (subtract numbers at stack top)
      WRD SWAP    ; SWAP  (swap two values at stack top)
      WRD RFROM   ; R> (pop return stack to  data stack)
      WRD PLUS    ; + (add two numbers on stack)
      WRD SWAP    ; SWAP  (swap two values at stack top)
      WRD EXITT   ; EXIT  (return from word execution)

; : aligned ( a -- a ) ( 6.1.0706 )( 0xae ) ( depends on 2's comp and 2^n cell size )
;   [ 1 cells 1 - dup ] literal + [ invert ] literal and ;
; ALIGNED	( b -- a )
;		Align address to the cell boundary. Here: does nothing!
      WRD L088
L089  WRD $07
      TXT "ALIGNED"
      WRD EIMED
ALGND WRD LIST1  ; Process colon list
      WRD EXITT   ; EXIT  (return from word execution)


; 
; : 2! ( u u a -- ) ( 6.1.0310 )( 0x77 ) swap over ! cell+ ! ;
; 2!		( d a -- )
;		Store the double integer to address a.
      WRD L089
L090  WRD $02
      TXT "2!"
      WRD 0
TSTOR WRD LIST1  ; Process colon list
      WRD SWAP    ; SWAP  (swap two values at stack top)
      WRD OVER    ; OVER  (copy second value at stack to stack top)
      WRD STORE   ; !  (write value at second stack item to address at stack top)
      WRD CELLP   ; CELL+ (Increment address at top by 1 cell size)
      WRD STORE   ; !  (write value at second stack item to address at stack top)
      WRD EXITT   ; EXIT  (return from word execution)

; : 2@ ( a -- u u ) ( 6.1.0350 )( 0x76 ) dup cell+ @ swap @ ;
; 2@		( a -- d )
;		Fetch double integer from address a.
      WRD L090
L091  WRD $02
      TXT "2@"
      WRD 0
TAT   WRD LIST1  ; Process colon list
      WRD DUP     ; DUP  (duplicate value at stack top)
      WRD CELLP   ; CELL+ (Increment address at top by 1 cell size)
      WRD ATT     ; @  (put to stack value at address on the stack top)
      WRD SWAP    ; SWAP  (swap two values at stack top)
      WRD ATT     ; @  (put to stack value at address on the stack top)
      WRD EXITT   ; EXIT  (return from word execution)

; 
; : move ( a a u -- ) ( 6.1.1900 )( 0x78 )
;   >r  2dup u<
;   if
;     begin r> dup
;     while char- >r  over r@ + c@  over r@ + c!
;     repeat drop  2drop exit
;   then r> over + >r
;   begin dup r@ xor
;   while >r  dup c@ r@ c!  char+ r> char+
;   repeat r> drop  2drop ;
; 
; MOVE ( addr1 addr2 u -- )
; If u >0 copy the contents of u consecutive address units at addr1 to the u consecutive address units at addr2. 
;      WRD L091
;L092  WRD $04
;     TXT "MOVE"
;      WRD 0
;MOVE  WRD LIST1  ; Process colon list
;      WRD TOR     ; >R  (push data stack to return stack)
;      WRD TDUP    ; 2DUP (duplicate top two numbers)
;      WRD ULESS   ; U<  (is second on stack unsigned less than top on stack)
;      WRD UIF     ; jump to next inline literal if top of stack is nonzero
;        WRD MOVE3
;MOVE1 WRD RFROM   ; R> (pop return stack to  data stack)
;      WRD DUP     ; DUP  (duplicate value at stack top)
;      WRD UIF     ; jump to next inline literal if top of stack is nonzero
;        WRD MOVE2
;      WRD CHARM   ; CHAR- (Decrement address at top by 1 characer size)
;      WRD TOR     ; >R  (push data stack to return stack)
;      WRD OVER    ; OVER  (copy second value at stack to stack top)
;      WRD RAT     ; R@ (copy top of return stack to  data stack)
;      WRD PLUS    ; + (add two numbers on stack)
;      WRD CAT     ; C@ (read byte from address at stack top ))
;      WRD OVER    ; OVER  (copy second value at stack to stack top)
;      WRD RAT     ; R@ (copy top of return stack to  data stack)
;      WRD PLUS    ; + (add two numbers on stack)
;      WRD CSTOR   ; C!  (write byte at second stack item to address at stack top)
;      WRD UELSE   ; jump to next inline literal
;        WRD MOVE1
;MOVE2 WRD DROP    ; DROP  (remove value at stack)
;      WRD TDROP   ; 2DROP remove 2 items from stack
;      WRD EXITT   ; EXIT  (return from word execution)
;MOVE3 WRD RFROM   ; R> (pop return stack to  data stack)
;      WRD OVER    ; OVER  (copy second value at stack to stack top)
;      WRD PLUS    ; + (add two numbers on stack)
;      WRD TOR     ; >R  (push data stack to return stack)
;MOVE4 WRD DUP     ; DUP  (duplicate value at stack top)
;      WRD RAT     ; R@ (copy top of return stack to  data stack)
;      WRD XORR    ; XOR  (bitwise XOR between two numbers on stack)
;      WRD UIF     ; jump to next inline literal if top of stack is nonzero
;        WRD MOVE5
;      WRD TOR     ; >R  (push data stack to return stack)
;      WRD DUP     ; DUP  (duplicate value at stack top)
;      WRD CAT     ; C@ (read byte from address at stack top ))
;      WRD RAT     ; R@ (copy top of return stack to  data stack)
;      WRD CSTOR   ; C!  (write byte at second stack item to address at stack top)
;      WRD CHARP   ; CHAR+ (Increment address at top by 1 characer size)
;      WRD RFROM   ; R> (pop return stack to  data stack)
;      WRD CHARP   ; CHAR+ (Increment address at top by 1 characer size)
;      WRD UELSE   ; jump to next inline literal
;        WRD MOVE4
;MOVE5 WRD RFROM   ; R> (pop return stack to  data stack)
;      WRD DROP    ; DROP  (remove value at stack)
;      WRD TDROP   ; 2DROP remove 2 items from stack
;      WRD EXITT   ; EXIT  (return from word execution)

      WRD L091
L092  WRD $04
      TXT "MOVE"
      WRD 0
MOVE WRD MOVE1
MOVE1 LOD R5,R5,R2   ; pop length
      ADD R2,R2,R1
      LOD R6,R6,R2   ; POP DESTINATION
      ADD R2,R2,R1
      LOD R7,R7,R2   ; POP SOURCE ADDRESS
      ADD R2,R2,R1   
      LTU R8,R6,R7   ; IF DEST < SOURCE , COPY BY INCREMENT
      SUB R11,R5,R1  ; FOR COPY BY DECREMENT LEN-1
      MIF R11,R8,R0  ; FOR COPY BY INCREMENT 0
      ADD R6,R6,R11  ; adjust start address
      ADD R7,R7,R11
      SUB R11,R0,R1  ; FOR COPY BY DECREMENT incrementer R11= -1
      MIF R11,R8,R1  ; FOR COPY BY INCREMENT R11=1
      ORA R12,R15,R15  ; START OF LOOP
MOVE2 GTU R8,R5,R0    ; IF LENGTH<>0
      ADD R15,R15,R8  ; THEN SKIP JUMP TO NEXT1
      ORA R15,R9,R9   ; JUMP NEXT1 IF LENGTH=0
      LOD R8,R8,R7    ; GET WORD FROM SOURCE 
      STO R8,R8,R6    ; PUT IT DO DESTINATION
      ADD R6,R6,R11   ; INCREMENT OR DECREMENT SOURCE POINTER
      ADD R7,R7,R11   ; INCREMENT OR DECREMENT DEST POINTER
      SUB R5,R5,R1    ; DECREMENT LENGTH
      ORA R15,R12,R12  ; JUMP TO LOOP MOVE1

; : fill ( a u c -- ) ( 6.1.1540 )( 0x79 )
;   >r  chars bounds
;   begin 2dup xor
;   while r@ over c!  char+
;   repeat r> drop 2drop ;
; FILL	( b u c -- )
;		Fill u bytes of character c to area beginning at b.

;      WRD L092
;L093  WRD $04
;      TXT "FILL"
;      WRD 0
;FILLL WRD LIST1  ; Process colon list
;      WRD TOR     ; >R  (push data stack to return stack)
;      WRD BNDS    ; BOUNDS (From addr and length, produce  addr+u and the start address)
;FILL1 WRD TDUP    ; 2DUP (duplicate top two numbers)
;      WRD XORR    ; XOR  (bitwise XOR between two numbers on stack)
;      WRD UIF     ; jump to next inline literal if top of stack is nonzero
;        WRD FILL2
;      WRD RAT     ; R@ (copy top of return stack to  data stack)
;      WRD OVER    ; OVER  (copy second value at stack to stack top)
;      WRD CSTOR   ; C!  (write byte at second stack item to address at stack top)
;      WRD CHARP   ; CHAR+ (Increment address at top by 1 characer size)
;      WRD UELSE   ; jump to next inline literal
;        WRD FILL1
;FILL2 WRD RFROM   ; R> (pop return stack to  data stack)
;      WRD DROP    ; DROP  (remove value at stack)
;      WRD TDROP   ; 2DROP remove 2 items from stack
;      WRD EXITT   ; EXIT  (return from word execution)

      WRD L092
L093  WRD $04
      TXT "FILL"
      WRD 0
FILL  WRD FILL1
FILL1 LOD R5,R5,R2   ; POP VALUE
      ADD R2,R2,R1
      LOD R6,R6,R2   ; POP COUNT
      ADD R2,R2,R1
      LOD R7,R7,R2   ; POP SOURCE ADDRESS
      ADD R2,R2,R1   
      ORA R12,R15,R15  ; START OF LOOP
FILL2 GTU R8,R6,R0    ; IF LENGTH<>0
      ADD R15,R15,R8  ; THEN SKIP JUMP TO NEXT1
      ORA R15,R9,R9   ; JUMP NEXT1 IF LENGTH=0
      STO R5,R5,R7    ; PUT VALUE DO DESTINATION
      ADD R7,R7,R1
      SUB R6,R6,R1    ; DECREMENT LENGTH
      ORA R15,R12,R12  ; JUMP TO LOOP MOVE1

; 
; : -trailing ( a u -- a u ) ( 17.6.1.0170 )
;   begin dup
;   while 1 -  2dup chars + c@  bl swap u<
;   until 1 + then ;
; -TRAILING	( b u -- b u )
;		Adjust the count to eliminate trailing white space.

      WRD L093
L094  WRD $09
      TXT "-TRAILING"
      WRD 0
DTRAI WRD LIST1  ; Process colon list
DTRA1 WRD DUP     ; DUP  (duplicate value at stack top)
      WRD UIF     ; jump to next inline literal if top of stack is nonzero
        WRD DTRA2
      WRD ULIT    ; push next inline literal
        WRD $01
      WRD MINUS   ; -  (subtract numbers at stack top)
      WRD TDUP    ; 2DUP (duplicate top two numbers)
      WRD PLUS    ; + (add two numbers on stack)
      WRD CAT     ; C@ (read byte from address at stack top ))
      WRD BLL
      WRD SWAP    ; SWAP  (swap two values at stack top)
      WRD ULESS   ; U<  (is second on stack unsigned less than top on stack)
      WRD UIF     ; jump to next inline literal if top of stack is nonzero
        WRD DTRA1
      WRD ULIT    ; push next inline literal
        WRD $01
      WRD PLUS    ; + (add two numbers on stack)
DTRA2 WRD EXITT   ; EXIT  (return from word execution)

; 
; : >adr ( xt -- a ) ; \ itc
; >ADR ( xt -- a )
; Convert number to address
      WRD L094
L095  WRD $04
      TXT ">ADR"
      WRD 0
TADR  WRD LIST1  ; Process colon list
      WRD EXITT   ; EXIT  (return from word execution)


; : >body ( xt -- a ) ( 6.1.0550 )( 0x86 ) >adr cell+ cell+ ; \ itc
; >BODY ( xt -- a-addr )
;   a-addr is the data-field address corresponding to xt. 
      WRD L095
L096  WRD $05
      TXT ">BODY"
      WRD 0
TBODY WRD LIST1  ; Process colon list
      WRD CELLP   ; CELL+ (Increment address at top by 1 cell size)
      WRD CELLP   ; CELL+ (Increment address at top by 1 cell size)
      WRD EXITT   ; EXIT  (return from word execution)

; ( multitask )
; 
; variable up ( current task pointer )
; UP		( -- a )
;		Pointer to the user area.

      WRD L096
L097  WRD $02
      TXT "UP"
      WRD 0
UP    WRD LIST1  ; Process colon list
      WRD UVAR    ; _VAR  (put to data stack address of next word and exit)
      WRD 0

; : _usr ( -- a ) up @ r> @ + ; compile-only
; 
; _USR	( -- a )
;		Run time routine for user variables.

      WRD L097
L098  WRD $04
      TXT "_USR"
      WRD ECOMP
UUSR  WRD LIST1  ; Process colon list
      WRD UP
      WRD ATT     ; @  (put to stack value at address on the stack top)
      WRD RFROM   ; R> (pop return stack to  data stack)
      WRD ATT     ; @  (put to stack value at address on the stack top)
      WRD PLUS    ; + (add two numbers on stack)
      WRD EXITT   ; EXIT  (return from word execution)
; ( u1\tf\tid\tos\status\follower\r>--<s  order is important )
; 1 cells ( init offset )
;   cell- dup user follower ( address of next task's status )
; FOLLOWER	( -- a )
; ( address of next task's STATUS )
      WRD L098
L099  WRD $08
      TXT "FOLLOWER"
      WRD 0
FOLLO WRD LIST1  ; Process colon list
      WRD UUSR
      WRD 0
;   cell- dup user status   ( pass or wake )
; STATUS 	( -- a )
; ( PASS or WAKE )

      WRD L099
L100  WRD $06
      TXT "STATUS"
      WRD 0
STATU WRD LIST1  ; Process colon list
      WRD UUSR
      WRD -1   ; 0-CELL1
;   cell- dup user tos      ( top of stack )
; TOS    	( -- a )
; ( top of stack )

      WRD L100
L101  WRD $03
      TXT "TOS"
      WRD 0
TOS   WRD LIST1  ; Process colon list
      WRD UUSR
      WRD -2  ; 0-2*CELL1
;   cell- dup user tid      ( back link tid )
; TID    	( -- a )
; ( back link tid )

      WRD L101
L102  WRD $03
      TXT "TID"
      WRD 0
TID   WRD LIST1  ; Process colon list
      WRD UUSR
      WRD -3  ; 0-3*CELL1
;   cell- dup user tf       ( throw frame )

; TF     	( -- a )
; ( throw frame )

      WRD L102
L103  WRD $02
      TXT "TF"
      WRD 0
TF    WRD LIST1  ; Process colon list
      WRD UUSR
      WRD -4   ; 0-4*CELL1
;   cell- dup user u1       ( free )
; drop ( cleanup )
;
; U1    	( -- a )
; ( free )
      WRD L103
L104  WRD $02
      TXT "U1"
      WRD 0
U1    WRD LIST1  ; Process colon list
      WRD UUSR
      WRD -5  ; 0-5*CELL1

; : 's ( tid a -- a ) ( index another task's local variable )
;   follower  cell+ - swap @ + ;
; 'S ( tid a -- a ) 
; ( index another task's local variable )

      WRD L104
L105  WRD $02
      TXT "'S"
      WRD 0
TICKS WRD LIST1  ; Process colon list
      WRD FOLLO   ; FOLLOWER ( address of next task's STATUS )
      WRD CELLP   ; CELL+ (Increment address at top by 1 cell size)
      WRD MINUS   ; -  (subtract numbers at stack top)
      WRD SWAP    ; SWAP  (swap two values at stack top)
      WRD ATT     ; @  (put to stack value at address on the stack top)
      WRD PLUS    ; + (add two numbers on stack)
      WRD EXITT   ; EXIT  (return from word execution)
; 
; : _pass ( -- ) ( hilevel absolute branch )
;   r> @ >r ; compile-only

      WRD L105
L106  WRD $05
      TXT "_PASS"
      WRD ECOMP
UPASS WRD LIST1  ; Process colon list
      WRD RFROM   ; R> (pop return stack to  data stack)
      WRD ATT     ; @  (put to stack value at address on the stack top)
      WRD TOR     ; >R  (push data stack to return stack)
      WRD EXITT   ; EXIT  (return from word execution)

; ' _pass constant pass
; PASS ( -- N)
; ( constant )

      WRD L106
L107  WRD $04
      TXT "PASS"
      WRD 0
PASS  WRD LIST1  ; Process colon list
      WRD UCON    ; _CON (get immediate constant after IP and exit)
      WRD UPASS

; 
; : _wake ( -- ) ( restore follower )
;   r> up !  tos @ sp! rp! ; compile-only
; _WAKE ( -- )
; ( restore follower )
      WRD L107
L108  WRD $05
      TXT "_WAKE"
      WRD ECOMP
UWAKE WRD LIST1  ; Process colon list
      WRD RFROM   ; R> (pop return stack to  data stack)
      WRD UP
      WRD STORE   ; !  (write value at second stack item to address at stack top)
      WRD TOS
      WRD ATT     ; @  (put to stack value at address on the stack top)
      WRD SPSTO   ; SP!  (Set data stack pointer)
      WRD RPSTO   ; RP! Set return stack pointer
      WRD EXITT   ; EXIT  (return from word execution)

; ' _wake constant wake
; WAKE ( -- N)
; ( constant )
      WRD L108
L109  WRD $04
      TXT "WAKE"
      WRD 0
WAKE  WRD LIST1  ; Process colon list
      WRD UCON    ; _CON (get immediate constant after IP and exit)
      WRD UWAKE

; 
; : pause ( -- ) ( allow another task to execute )
;   rp@  sp@ tos !  follower @ >r ;
; PAUSE ( -- ) 
;  ( allow another task to execute )
      WRD L109
L110  WRD $05
      TXT "PAUSE"
      WRD 0
PAUS  WRD LIST1  ; Process colon list
      WRD RPAT    ; RP@   Push return stack pointer to data stack
      WRD SPAT
      WRD TOS
      WRD STORE   ; !  (write value at second stack item to address at stack top)
      WRD FOLLO   ; FOLLOWER ( address of next task's STATUS )
      WRD ATT     ; @  (put to stack value at address on the stack top)
      WRD TOR     ; >R  (push data stack to return stack)
      WRD EXITT   ; EXIT  (return from word execution)
      WRD L110

; 
; : stop ( -- ) ( sleep current task )
;   pass status ! pause ; compile-only
; STOP ( -- )
; ( sleep current task )
L111  WRD $04
      TXT "STOP"
      WRD ECOMP
STOP  WRD LIST1  ; Process colon list
      WRD PASS
      WRD STATU
      WRD STORE   ; !  (write value at second stack item to address at stack top)
      WRD PAUS
      WRD EXITT   ; EXIT  (return from word execution)

; 
; : get ( semaphore -- )
;   pause ( remember your manners )
;   dup @ status xor ( owner ? )
;   if begin dup @ while pause repeat ( no, wait for release )
;     status swap ! ( lock ) exit
;   then drop ;
; 
; GET      ( semaphore -- )
; Wait on semaphore
      WRD L111
L112  WRD $03
      TXT "GET"
      WRD 0
GET   WRD LIST1  ; Process colon list
      WRD PAUS
      WRD DUP     ; DUP  (duplicate value at stack top)
      WRD ATT     ; @  (put to stack value at address on the stack top)
      WRD STATU
      WRD XORR    ; XOR  (bitwise XOR between two numbers on stack)
      WRD UIF     ; jump to next inline literal if top of stack is nonzero
        WRD GET3
GET1  WRD DUP     ; DUP  (duplicate value at stack top)
      WRD ATT     ; @  (put to stack value at address on the stack top)
      WRD UIF     ; jump to next inline literal if top of stack is nonzero
        WRD GET2
      WRD PAUS
      WRD UELSE   ; jump to next inline literal
        WRD GET1
GET2  WRD STATU
      WRD SWAP    ; SWAP  (swap two values at stack top)
      WRD STORE   ; !  (write value at second stack item to address at stack top)
      WRD EXITT   ; EXIT  (return from word execution)
GET3  WRD DROP    ; DROP  (remove value at stack)
      WRD EXITT   ; EXIT  (return from word execution)

; : release ( semaphore -- )
;   dup @ status xor if drop exit then  0 swap ! ( unlock ) ;
; RELEASE       ( semaphore -- )
; release semaphore
      WRD L112
L113  WRD $07
      TXT "RELEASE"
      WRD 0
RELEA WRD LIST1  ; Process colon list
      WRD DUP     ; DUP  (duplicate value at stack top)
      WRD ATT     ; @  (put to stack value at address on the stack top)
      WRD STATU
      WRD XORR    ; XOR  (bitwise XOR between two numbers on stack)
      WRD UIF     ; jump to next inline literal if top of stack is nonzero
        WRD RELE1
      WRD DROP    ; DROP  (remove value at stack)
      WRD EXITT   ; EXIT  (return from word execution)
RELE1 WRD ULIT    ; push next inline literal
        WRD 0
      WRD SWAP    ; SWAP  (swap two values at stack top)
      WRD STORE   ; !  (write value at second stack item to address at stack top)
      WRD EXITT   ; EXIT  (return from word execution)

; 
; : sleep ( tid -- ) ( sleep another task )
;   pass swap status 's ! ;
; SLEEP ( tid -- )
; ( sleep another task )
      WRD L113
L114  WRD $05
      TXT "SLEEP"
      WRD 0
SLEEP WRD LIST1  ; Process colon list
      WRD PASS
      WRD SWAP    ; SWAP  (swap two values at stack top)
      WRD STATU
      WRD TICKS   ; 'S ( index another task's local variable )
      WRD STORE   ; !  (write value at second stack item to address at stack top)
      WRD EXITT   ; EXIT  (return from word execution)

; 
; : awake ( tid -- ) ( wake another task )
;   wake swap status 's ! ;
; AWAKE ( tid -- ) 
; ( wake another task )
      WRD L114
L115  WRD $05
      TXT "AWAKE"
      WRD 0
AWAKE WRD LIST1  ; Process colon list
      WRD WAKE
      WRD SWAP    ; SWAP  (swap two values at stack top)
      WRD STATU
      WRD TICKS   ; 'S ( index another task's local variable )
      WRD STORE   ; !  (write value at second stack item to address at stack top)
      WRD EXITT   ; EXIT  (return from word execution)

; 
; : activate ( tid -- )
;   dup 2@        ( tid sp rp )
;   r> over !     ( save entry at rp )
;   over !        ( save rp at sp )
;   over tos 's ! ( save sp in tos )
;   awake ; compile-only
; ACTIVATE ( tid -- )
      WRD L115
L116  WRD $08
      TXT "ACTIVATE"
      WRD ECOMP
ACTIV WRD LIST1  ; Process colon list
      WRD DUP     ; DUP  (duplicate value at stack top)
      WRD TAT
      WRD RFROM   ; R> (pop return stack to  data stack)
      WRD OVER    ; OVER  (copy second value at stack to stack top)
      WRD STORE   ; !  (write value at second stack item to address at stack top)
      WRD OVER    ; OVER  (copy second value at stack to stack top)
      WRD STORE   ; !  (write value at second stack item to address at stack top)
      WRD OVER    ; OVER  (copy second value at stack to stack top)
      WRD TOS
      WRD TICKS   ; 'S ( index another task's local variable )
      WRD STORE   ; !  (write value at second stack item to address at stack top)
      WRD AWAKE
      WRD EXITT   ; EXIT  (return from word execution)

; 
; : build ( tid -- )
;   dup sleep                     ( sleep new task )
;   follower @ over follower 's ! ( link new task )
;   dup status 's follower !      ( link old task )
;   dup tid 's ! ;                ( link to tid )
; 
; BUILD ( tid -- )
      WRD L116
L117  WRD $05
      TXT "BUILD"
      WRD 0
BUILD WRD LIST1  ; Process colon list
      WRD DUP     ; DUP  (duplicate value at stack top)
      WRD SLEEP
      WRD FOLLO   ; FOLLOWER ( address of next task's STATUS )
      WRD ATT     ; @  (put to stack value at address on the stack top)
      WRD OVER    ; OVER  (copy second value at stack to stack top)
      WRD FOLLO   ; FOLLOWER ( address of next task's STATUS )
      WRD TICKS   ; 'S ( index another task's local variable )
      WRD STORE   ; !  (write value at second stack item to address at stack top)
      WRD DUP     ; DUP  (duplicate value at stack top)
      WRD STATU
      WRD TICKS   ; 'S ( index another task's local variable )
      WRD FOLLO   ; FOLLOWER ( address of next task's STATUS )
      WRD STORE   ; !  (write value at second stack item to address at stack top)
      WRD DUP     ; DUP  (duplicate value at stack top)
      WRD TID
      WRD TICKS   ; 'S ( index another task's local variable )
      WRD STORE   ; !  (write value at second stack item to address at stack top)
      WRD EXITT   ; EXIT  (return from word execution)

; ( numeric input )
; 
; : digit? ( c base -- u f ) ( 0xa3 )
;   >r [char] 0 - 9 over <
;   if 7 - dup 10 < or then dup r> u< ;
; DIGIT?	( c base -- u t )
;		Convert a character to its numeric value. A flag indicates success.

      WRD L117
L118  WRD $06
      TXT "DIGIT?"
      WRD 0
DIGQ  WRD LIST1  ; Process colon list
      WRD TOR     ; >R  (push data stack to return stack)
      WRD ULIT    ; push next inline literal
         WRD 48  ; ASCII '0'
      WRD MINUS   ; -  (subtract numbers at stack top)
      WRD ULIT    ; push next inline literal
        WRD $09
      WRD OVER    ; OVER  (copy second value at stack to stack top)
      WRD LESS    ; <  (is second on stack less than top on stack)
      WRD UIF     ; jump to next inline literal if top of stack is nonzero
        WRD DIGQ1
      WRD ULIT    ; push next inline literal
        WRD $07
      WRD MINUS   ; -  (subtract numbers at stack top)
      WRD DUP     ; DUP  (duplicate value at stack top)
      WRD ULIT    ; push next inline literal
        WRD $0A
      WRD LESS    ; <  (is second on stack less than top on stack)
      WRD ORR     ; OR  (bitwise OR between two numbers on stack)
DIGQ1 WRD DUP     ; DUP  (duplicate value at stack top)
      WRD RFROM   ; R> (pop return stack to  data stack)
      WRD ULESS   ; U<  (is second on stack unsigned less than top on stack)
      WRD EXITT   ; EXIT  (return from word execution)

; 
; : >number ( ud a u -- ud a u ) ( 6.1.0570 )
;   begin dup
;   while >r  dup >r c@ base @ digit?
;   while swap base @ um* drop rot base @ um* d+ r> char+ r> 1 -
;   repeat drop r> r> then ;
; >NUMBER ( ud1 c-addr1 u1 -- ud2 c-addr2 u2 )
; ud2 is the unsigned result of converting the characters within the string specified by c-addr1 u1 into digits, using the number in BASE, and adding each into ud1 after multiplying ud1 by the number in BASE. 
      WRD L118
L119  WRD $07
      TXT ">NUMBER"
      WRD 0
TNUMB WRD LIST1  ; Process colon list
TNUM1 WRD DUP     ; DUP  (duplicate value at stack top)
      WRD UIF     ; jump to next inline literal if top of stack is nonzero
        WRD TNUM3
      WRD TOR     ; >R  (push data stack to return stack)
      WRD DUP     ; DUP  (duplicate value at stack top)
      WRD TOR     ; >R  (push data stack to return stack)
      WRD CAT     ; C@ (read byte from address at stack top ))
      WRD BASE    ; BASE (return address of variable pointing number base system)
      WRD ATT     ; @  (put to stack value at address on the stack top)
      WRD DIGQ
      WRD UIF     ; jump to next inline literal if top of stack is nonzero
        WRD TNUM2
      WRD SWAP    ; SWAP  (swap two values at stack top)
      WRD BASE    ; BASE (return address of variable pointing number base system)
      WRD ATT     ; @  (put to stack value at address on the stack top)
      WRD UMSTA   ; UM * unsigned multiply double product
      WRD DROP    ; DROP  (remove value at stack)
      WRD ROT     ; ROT  (rotate three numbers at stack top)
      WRD BASE    ; BASE (return address of variable pointing number base system)
      WRD ATT     ; @  (put to stack value at address on the stack top)
      WRD UMSTA   ; UM * unsigned multiply double product
      WRD DPLUS   ; D+ (Doulbe addition)
      WRD RFROM   ; R> (pop return stack to  data stack)
      WRD CHARP   ; CHAR+ (Increment address at top by 1 characer size)
      WRD RFROM   ; R> (pop return stack to  data stack)
      WRD ULIT    ; push next inline literal
        WRD $01
      WRD MINUS   ; -  (subtract numbers at stack top)
      WRD UELSE   ; jump to next inline literal
        WRD TNUM1
TNUM2 WRD DROP    ; DROP  (remove value at stack)
      WRD RFROM   ; R> (pop return stack to  data stack)
      WRD RFROM   ; R> (pop return stack to  data stack)
TNUM3 WRD EXITT   ; EXIT  (return from word execution)

; 
; : number? ( a u -- d -1 | a u 0 )
;   over c@ [char] - = dup >r if 1 /string then
;   >r >r  0 dup  r> r>  -1 dpl !
;   begin >number dup
;   while over c@ [char] . xor
;     if rot drop rot r> 2drop  0 exit
;     then 1 - dpl !  char+  dpl @
;   repeat 2drop r> if dnegate then -1 ;
; NUMBER?	( a -- n T | a F )
;		Convert a number string to integer. Push a flag on tos.

      WRD L119
L120  WRD $07
      TXT "NUMBER?"
      WRD 0
NUMQ  WRD LIST1  ; Process colon list
      WRD OVER    ; OVER  (copy second value at stack to stack top)
      WRD CAT     ; C@ (read byte from address at stack top ))
      WRD ULIT    ; push next inline literal
        TXT "-"
      WRD EQUAL
      WRD DUP     ; DUP  (duplicate value at stack top)
      WRD TOR     ; >R  (push data stack to return stack)
      WRD UIF     ; jump to next inline literal if top of stack is nonzero
        WRD NUMQ1
      WRD ULIT    ; push next inline literal
        WRD $01
      WRD SSTRI
NUMQ1 WRD TOR     ; >R  (push data stack to return stack)
      WRD TOR     ; >R  (push data stack to return stack)
      WRD ULIT    ; push next inline literal
        WRD 0
      WRD DUP     ; DUP  (duplicate value at stack top)
      WRD RFROM   ; R> (pop return stack to  data stack)
      WRD RFROM   ; R> (pop return stack to  data stack)
      WRD ULIT    ; push next inline literal
        WRD -1
      WRD DPL
      WRD STORE   ; !  (write value at second stack item to address at stack top)
NUMQ2 WRD TNUMB
      WRD DUP     ; DUP  (duplicate value at stack top)
      WRD UIF     ; jump to next inline literal if top of stack is nonzero
        WRD NUMQ4
      WRD OVER    ; OVER  (copy second value at stack to stack top)
      WRD CAT     ; C@ (read byte from address at stack top ))
      WRD ULIT    ; push next inline literal
        TXT "."
      WRD XORR    ; XOR  (bitwise XOR between two numbers on stack)
      WRD UIF     ; jump to next inline literal if top of stack is nonzero
        WRD NUMQ3
      WRD ROT     ; ROT  (rotate three numbers at stack top)
      WRD DROP    ; DROP  (remove value at stack)
      WRD ROT     ; ROT  (rotate three numbers at stack top)
      WRD RFROM   ; R> (pop return stack to  data stack)
      WRD TDROP   ; 2DROP remove 2 items from stack
      WRD ULIT    ; push next inline literal
        WRD 0
      WRD EXITT   ; EXIT  (return from word execution)
NUMQ3 WRD ULIT    ; push next inline literal
        WRD $01
      WRD MINUS   ; -  (subtract numbers at stack top)
      WRD DPL
      WRD STORE   ; !  (write value at second stack item to address at stack top)
      WRD CHARP   ; CHAR+ (Increment address at top by 1 characer size)
      WRD DPL
      WRD ATT     ; @  (put to stack value at address on the stack top)
      WRD UELSE   ; jump to next inline literal
        WRD NUMQ2
NUMQ4 WRD TDROP   ; 2DROP remove 2 items from stack
      WRD RFROM   ; R> (pop return stack to  data stack)
      WRD UIF     ; jump to next inline literal if top of stack is nonzero
        WRD NUMQ5
      WRD DNEGA   ; DNEGATE (2 complement of top double. )
NUMQ5 WRD ULIT    ; push next inline literal
        WRD $FFFF
      WRD EXITT   ; EXIT  (return from word execution)

; 
; ( numeric output )
; 
; : here ( -- a ) ( 6.1.1650 )( 0xad ) dp @ ;
; HERE	( -- a )
;		Return the top of the code dictionary.

      WRD L120
L121  WRD $04
      TXT "HERE"
      WRD 0
HERE  WRD LIST1  ; Process colon list
      WRD DP
      WRD ATT     ; @  (put to stack value at address on the stack top)
      WRD EXITT   ; EXIT  (return from word execution)

; : pad ( -- a ) ( 6.2.2000 ) here [ #pad chars ] literal + ;
; PAD		( -- a )
;		Return the address of a temporary buffer.

      WRD L121
L122  WRD $03
      TXT "PAD"
      WRD 0
PAD   WRD LIST1  ; Process colon list
      WRD HERE    ; HERE (return top of code directory)
      WRD ULIT    ; push next inline literal
        WRD NPAD
      WRD PLUS    ; + (add two numbers on stack)
      WRD EXITT   ; EXIT  (return from word execution)

; 
; : <# ( -- ) ( 6.1.0490 )( 0x96 ) pad hld ! ;
; <#		( -- )
;		Initiate the numeric output process.

      WRD L122
L123  WRD $02
      TXT "<#"
      WRD 0
BDIGS WRD LIST1  ; Process colon list
      WRD PAD
      WRD HLD
      WRD STORE   ; !  (write value at second stack item to address at stack top)
      WRD EXITT   ; EXIT  (return from word execution)

; : digit ( u -- c ) 9 over < 7 and + [char] 0 + ;
; DIGIT	( u -- c )
;		Convert digit u to a character.

      WRD L123
L124  WRD $05
      TXT "DIGIT"
      WRD 0
DIGIT WRD LIST1  ; Process colon list
      WRD ULIT    ; push next inline literal
        WRD $09
      WRD OVER    ; OVER  (copy second value at stack to stack top)
      WRD LESS    ; <  (is second on stack less than top on stack)
      WRD ULIT    ; push next inline literal
        WRD $07
      WRD ANDD    ; AND  (bitwise AND between two numbers on stack)
      WRD PLUS    ; + (add two numbers on stack)
      WRD ULIT    ; push next inline literal
         WRD 48  ; ASCII '0'
      WRD PLUS    ; + (add two numbers on stack)
      WRD EXITT   ; EXIT  (return from word execution)

; : hold ( c -- ) ( 6.1.1670 )( 0x95 ) hld @ char- dup hld ! c! ;
; HOLD	( c -- )
;		Insert a character into the numeric output string.

      WRD L124
L125  WRD $04
      TXT "HOLD"
      WRD 0
HOLD  WRD LIST1  ; Process colon list
      WRD HLD
      WRD ATT     ; @  (put to stack value at address on the stack top)
      WRD CHARM   ; CHAR- (Decrement address at top by 1 characer size)
      WRD DUP     ; DUP  (duplicate value at stack top)
      WRD HLD
      WRD STORE   ; !  (write value at second stack item to address at stack top)
      WRD CSTOR   ; C!  (write byte at second stack item to address at stack top)
      WRD EXITT   ; EXIT  (return from word execution)

; 
; : # ( d -- d ) ( 6.1.0030 )( 0xc7 )
;   0 base @ um/mod >r base @ um/mod swap digit hold r> ;
; #		( u -- u )
;		Extract one digit from u and append the digit to output string.

      WRD L125
L126  WRD $01
      TXT "#"
      WRD 0
NDIG  WRD LIST1  ; Process colon list
      WRD ULIT    ; push next inline literal
        WRD 0
      WRD BASE    ; BASE (return address of variable pointing number base system)
      WRD ATT     ; @  (put to stack value at address on the stack top)
      WRD UMMOD   ; UM/MOD (Unsigned divide of a double by a single. Return mod and quotient. )
      WRD TOR     ; >R  (push data stack to return stack)
      WRD BASE    ; BASE (return address of variable pointing number base system)
      WRD ATT     ; @  (put to stack value at address on the stack top)
      WRD UMMOD   ; UM/MOD (Unsigned divide of a double by a single. Return mod and quotient. )
      WRD SWAP    ; SWAP  (swap two values at stack top)
      WRD DIGIT
      WRD HOLD
      WRD RFROM   ; R> (pop return stack to  data stack)
      WRD EXITT   ; EXIT  (return from word execution)

; 
; : #s ( d -- d ) ( 6.1.0050 )( 0xc8 ) begin # 2dup or 0= until ;
; #S		( u -- 0 )
;		Convert u until all digits are added to the output string.

      WRD L126
L127  WRD $02
      TXT "#S"
      WRD 0
DIGS  WRD LIST1  ; Process colon list
DIGS1 WRD NDIG
      WRD TDUP    ; 2DUP (duplicate top two numbers)
      WRD ORR     ; OR  (bitwise OR between two numbers on stack)
      WRD ZEQ     ; 0= (is number equal zero)
      WRD UIF     ; jump to next inline literal if top of stack is nonzero
        WRD DIGS1
      WRD EXITT   ; EXIT  (return from word execution)

; : #> ( d -- a u ) ( 6.1.0040 )( 0xc9 ) 2drop hld @ pad over - ;
; #>		( w -- b u )
;		Prepare the output string to be TYPE'd.

      WRD L127
L128  WRD $02
      TXT "#>"
      WRD 0
EDIGS WRD LIST1  ; Process colon list
      WRD TDROP   ; 2DROP remove 2 items from stack
      WRD HLD
      WRD ATT     ; @  (put to stack value at address on the stack top)
      WRD PAD
      WRD OVER    ; OVER  (copy second value at stack to stack top)
      WRD MINUS   ; -  (subtract numbers at stack top)
      WRD EXITT   ; EXIT  (return from word execution)

; 
; : sign ( n -- ) ( 6.1.2210 )( 0x98 ) 0< if [char] - hold then ;
; SIGN	( n -- )
;		Add a minus sign to the numeric output string.
;
      WRD L128
L129  WRD $04
      TXT "SIGN"
      WRD 0
SIGN  WRD LIST1  ; Process colon list
      WRD ZLESS   ; 0<  (true if negative number on stack)
      WRD UIF     ; jump to next inline literal if top of stack is nonzero
        WRD SIGN1
      WRD ULIT    ; push next inline literal
        TXT "-"
      WRD HOLD
SIGN1 WRD EXITT   ; EXIT  (return from word execution)
; 
; ( error handling )
; 
; : catch ( xt -- 0 | err ) ( 9.6.1.0875 )( 0x217 )
;   sp@ >r  tf @ >r  rp@ tf !  execute  r> tf !  r> drop  0 ;
; CATCH	( ca -- 0 | err# )
;		Execute word at ca and set up an error frame for it.

      WRD L129
L130  WRD $05
      TXT "CATCH"
      WRD 0
CATCH WRD LIST1  ; Process colon list
      WRD SPAT
      WRD TOR     ; >R  (push data stack to return stack)
      WRD TF
      WRD ATT     ; @  (put to stack value at address on the stack top)
      WRD TOR     ; >R  (push data stack to return stack)
      WRD RPAT    ; RP@   Push return stack pointer to data stack
      WRD TF
      WRD STORE   ; !  (write value at second stack item to address at stack top)
      WRD EXECU   ; EXECUTE  (execute word adressed at stack)
      WRD RFROM   ; R> (pop return stack to  data stack)
      WRD TF
      WRD STORE   ; !  (write value at second stack item to address at stack top)
      WRD RFROM   ; R> (pop return stack to  data stack)
      WRD DROP    ; DROP  (remove value at stack)
      WRD ULIT    ; push next inline literal
        WRD 0
      WRD EXITT   ; EXIT  (return from word execution)

; 
; : throw ( 0 | err -- | err ) ( r: i*x i*y -- i*x i*y | i*x ) ( 9.6.1.2275 )( 0x218 )
;   ?dup if tf @ rp!  r> tf !  r> swap >r sp! drop r> then ;
; THROW	( err# -- err# )
;		Reset system to current local error frame an update error flag.

      WRD L130
L131  WRD $05
      TXT "THROW"
      WRD 0
THROW WRD LIST1  ; Process colon list
      WRD QDUP    ; ?DUP (duplicate number on stack top if it is not zero)
      WRD UIF     ; jump to next inline literal if top of stack is nonzero
        WRD THRO1
      WRD TF
      WRD ATT     ; @  (put to stack value at address on the stack top)
      WRD RPSTO   ; RP! Set return stack pointer
      WRD RFROM   ; R> (pop return stack to  data stack)
      WRD TF
      WRD STORE   ; !  (write value at second stack item to address at stack top)
      WRD RFROM   ; R> (pop return stack to  data stack)
      WRD SWAP    ; SWAP  (swap two values at stack top)
      WRD TOR     ; >R  (push data stack to return stack)
      WRD SPSTO   ; SP!  (Set data stack pointer)
      WRD DROP    ; DROP  (remove value at stack)
      WRD RFROM   ; R> (pop return stack to  data stack)
THRO1 WRD EXITT   ; EXIT  (return from word execution)

; 
; : abort ( i*n -- ) ( r: i*x i*y -- i*x ) ( 9.6.2.0670 )( 0x216 ) -1 throw ;
; ABORT	( -- )
;		Reset data stack and jump to QUIT.

      WRD L131
L132  WRD $05
      TXT "ABORT"
      WRD 0
ABORT WRD LIST1  ; Process colon list
      WRD ULIT    ; push next inline literal
        WRD -1
      WRD THROW
      WRD EXITT   ; EXIT  (return from word execution)

; 
; ( basic i/o )
; 
; : ?key ( -- c -1 | 0 )  pause  '?key @ execute ;
; ?KEY	( -- c T | F )
;		Return input character and true, or a false if no input.

      WRD L132
L133  WRD $04
      TXT "?KEY"
      WRD 0
QKEY  WRD LIST1  ; Process colon list
      WRD PAUS
      WRD TQKEY
      WRD ATT     ; @  (put to stack value at address on the stack top)
      WRD EXECU   ; EXECUTE  (execute word adressed at stack)
      WRD EXITT   ; EXIT  (return from word execution)
; : key ( -- c ) ( 6.1.1750 )( 0x8e ) begin ?key until ;
; KEY		( -- c )
;		Wait for and return an input character.

      WRD L133
L134  WRD $03
      TXT "KEY"
      WRD 0
KEY   WRD LIST1  ; Process colon list
KEY1  WRD QKEY
      WRD UIF     ; jump to next inline literal if top of stack is nonzero
        WRD KEY1
      WRD EXITT   ; EXIT  (return from word execution)

; : nuf? ( -- f ) ?key dup if 2drop key [ =cr ] literal = then ;
; NUF?	( -- t )
;		Return false if no input, else pause and if CR return true.

      WRD L134
L135  WRD $04
      TXT "NUF?"
      WRD 0
NUFQ  WRD LIST1  ; Process colon list
      WRD QKEY
      WRD DUP     ; DUP  (duplicate value at stack top)
      WRD UIF     ; jump to next inline literal if top of stack is nonzero
        WRD NUFQ1
      WRD TDROP   ; 2DROP remove 2 items from stack
      WRD KEY
      WRD ULIT    ; push next inline literal
        WRD ECR
      WRD EQUAL
NUFQ1 WRD EXITT   ; EXIT  (return from word execution)

; 
; : emit ( c -- ) ( 6.1.1320 )( 0x8f ) 'emit @ execute ;
; EMIT	( c -- )
;		Send a character to the output device.

      WRD L135
L136  WRD $04
      TXT "EMIT"
      WRD 0
EMIT  WRD LIST1  ; Process colon list
      WRD TEMIT
      WRD ATT     ; @  (put to stack value at address on the stack top)
      WRD EXECU   ; EXECUTE  (execute word adressed at stack)
      WRD EXITT   ; EXIT  (return from word execution)

; : space ( -- ) ( 6.1.2220 ) bl emit ; ,c" coyote"
; SPACE	( -- )
;		Send the blank character to the output device.

      WRD L136
L137  WRD $05
      TXT "SPACE"
      WRD 0
SPACE WRD LIST1  ; Process colon list
      WRD BLL
      WRD EMIT
      WRD EXITT   ; EXIT  (return from word execution)

; 
; : emits ( n c -- )
;   swap 0 max begin dup while over emit 1 - repeat 2drop ;
; EMITS ( n c -- )
;      Send n characters of code c to output device
      WRD L137
L138  WRD $05
      TXT "EMITS"
      WRD 0
EMITS WRD LIST1  ; Process colon list
      WRD SWAP    ; SWAP  (swap two values at stack top)
      WRD ULIT    ; push next inline literal
        WRD 0
      WRD MAX
EMTS1 WRD DUP     ; DUP  (duplicate value at stack top)
      WRD UIF     ; jump to next inline literal if top of stack is nonzero
        WRD EMTS2
      WRD OVER    ; OVER  (copy second value at stack to stack top)
      WRD EMIT
      WRD ULIT    ; push next inline literal
        WRD $01
      WRD MINUS   ; -  (subtract numbers at stack top)
      WRD UELSE   ; jump to next inline literal
        WRD EMTS1
EMTS2 WRD TDROP   ; 2DROP remove 2 items from stack
      WRD EXITT   ; EXIT  (return from word execution)

; : spaces ( n -- ) ( 6.1.2230 ) bl emits ;
; SPACES	( +n -- )
;		Send n spaces to the output device.

      WRD L138
L139  WRD $06
      TXT "SPACES"
      WRD 0
SPACS WRD LIST1  ; Process colon list
      WRD BLL
      WRD EMITS
      WRD EXITT   ; EXIT  (return from word execution)

; 
; : type ( a u -- ) ( 6.1.2310 )( 0x90 )
;   chars bounds begin 2dup xor while count emit repeat 2drop ;
; TYPE	( b u -- )
;		Output u characters from b.

      WRD L139
L140  WRD $04
      TXT "TYPE"
      WRD 0
TYPE  WRD LIST1  ; Process colon list
      WRD BNDS    ; BOUNDS (From addr and length, produce  addr+u and the start address)
TYPE1 WRD TDUP    ; 2DUP (duplicate top two numbers)
      WRD XORR    ; XOR  (bitwise XOR between two numbers on stack)
      WRD UIF     ; jump to next inline literal if top of stack is nonzero
        WRD TYPE2
      WRD COUNT
      WRD EMIT
      WRD UELSE   ; jump to next inline literal
        WRD TYPE1
TYPE2 WRD TDROP   ; 2DROP remove 2 items from stack
      WRD EXITT   ; EXIT  (return from word execution)

; : cr ( -- ) ( 6.1.0990 )( 0x92 ) [ =cr ] literal emit [ =lf ] literal emit ;
; CR		( -- )
;		Output a carriage return and a line feed.

      WRD L140
L141  WRD $02
      TXT "CR"
      WRD 0
CR    WRD LIST1  ; Process colon list
      WRD ULIT    ; push next inline literal
        WRD ECR
      WRD EMIT
      WRD ULIT    ; push next inline literal
        WRD ELF
      WRD EMIT
      WRD EXITT   ; EXIT  (return from word execution)

; 
; : _" ( -- a )
;   r> r> dup count chars + aligned >r swap >r ; compile-only
; _" ( -- a )
;		Return the address of a compiled string.

      WRD L141
L142  WRD $02
      WRD $5F
        WRD $22 ; _"
      WRD ECOMP
UQUOT WRD LIST1  ; Process colon list
      WRD RFROM   ; R> (pop return stack to  data stack)
      WRD RFROM   ; R> (pop return stack to  data stack)
      WRD DUP     ; DUP  (duplicate value at stack top)
      WRD COUNT
      WRD PLUS    ; + (add two numbers on stack)
      WRD TOR     ; >R  (push data stack to return stack)
      WRD SWAP    ; SWAP  (swap two values at stack top)
      WRD TOR     ; >R  (push data stack to return stack)
      WRD EXITT   ; EXIT  (return from word execution)

; 
; : _s" ( -- a u ) _" count ; compile-only
; _S" ( -- a u )
;		Return the address and byte count of a compiled string.

      WRD L142
L143  WRD $03
      WRD $5F
        WRD $53
        WRD $22 ; _S"
      WRD ECOMP
USQ   WRD LIST1  ; Process colon list
      WRD UQUOT
      WRD COUNT
      WRD EXITT   ; EXIT  (return from word execution)

; : _." ( -- ) ( 0x12 ) _" count type ; compile-only
; _." ( -- )
      WRD L143
L144  WRD $03
      WRD $5F
        WRD $2E
        WRD $22 ; _."
      WRD ECOMP
UDOTQ WRD LIST1  ; Process colon list
      WRD UQUOT
      WRD COUNT
      WRD TYPE
      WRD EXITT   ; EXIT  (return from word execution)
      WRD L144

; : _abort" ( i*n f -- i*n | ) ( r: i*x i*y -- i*x i*y | i*x )
;   if _" csp ! -2 throw then _" drop ; compile-only
; _ABORT" ( i*n f -- i*n | ) ( R: i*x i*y -- i*x i*y | i*x )
L145  WRD $07
      WRD $5F
        WRD $41
        WRD $42
        WRD $4F
        WRD $52
        WRD $54
        WRD $22 ; _ABORT"
      WRD ECOMP
UABOR WRD LIST1  ; Process colon list
      WRD UIF     ; jump to next inline literal if top of stack is nonzero
        WRD UABO1
      WRD UQUOT
      WRD CSP
      WRD STORE   ; !  (write value at second stack item to address at stack top)
      WRD ULIT    ; push next inline literal
        WRD -2
      WRD THROW
UABO1 WRD UQUOT
      WRD DROP    ; DROP  (remove value at stack)
      WRD EXITT   ; EXIT  (return from word execution)

; 
; : s.r ( a u n -- ) over - spaces type ;
;		Display a signed integer in a field of n columns, right justified.
; S.R		( a u n -- )

      WRD L145
L146  WRD $03
      TXT "S.R"
      WRD 0
SDOTR WRD LIST1  ; Process colon list
      WRD OVER    ; OVER  (copy second value at stack to stack top)
      WRD MINUS   ; -  (subtract numbers at stack top)
      WRD SPACS
      WRD TYPE
      WRD EXITT   ; EXIT  (return from word execution)

; : d.r ( d n -- ) ( 8.6.1.1070 ) >r dup >r dabs <# #s r> sign #> r> s.r ;
;		Display a double integer in a field of n columns, right justified.
; D.R		( d +n -- )
      WRD L146
L147  WRD $03
      TXT "D.R"
      WRD 0
DDOTR WRD LIST1  ; Process colon list
      WRD TOR     ; >R  (push data stack to return stack)
      WRD DUP     ; DUP  (duplicate value at stack top)
      WRD TOR     ; >R  (push data stack to return stack)
      WRD DABS    ; DABS absolute value od fouble number
      WRD BDIGS
      WRD DIGS
      WRD RFROM   ; R> (pop return stack to  data stack)
      WRD SIGN
      WRD EDIGS
      WRD RFROM   ; R> (pop return stack to  data stack)
      WRD SDOTR
      WRD EXITT   ; EXIT  (return from word execution)
; : u.r ( u n -- ) ( 6.2.2330 )( 0x9c ) 0 swap d.r ;
;		Display an integer in a field of n columns, right justified.
; U.R		( u +n -- )

      WRD L147
L148  WRD $03
      TXT "U.R"
      WRD 0
UDOTR WRD LIST1  ; Process colon list
      WRD ULIT    ; push next inline literal
        WRD 0
      WRD SWAP    ; SWAP  (swap two values at stack top)
      WRD DDOTR
      WRD EXITT   ; EXIT  (return from word execution)

; : .r ( n n -- ) ( 6.2.0210 )( 0x9e ) >r s>d r> d.r ;
; .R		( n +n -- )
;		Display an integer in a field of n columns, right justified.

      WRD L148
L149  WRD $02
      TXT ".R"
      WRD 0
DOTR  WRD LIST1  ; Process colon list
      WRD TOR     ; >R  (push data stack to return stack)
      WRD STOD
      WRD RFROM   ; R> (pop return stack to  data stack)
      WRD DDOTR
      WRD EXITT   ; EXIT  (return from word execution)

; 
; : d. ( d -- ) ( 8.6.1.1060 ) 0 d.r space ;
; D. ( d -- )
;        Display double integer in free format
      WRD L149
L150  WRD $02
      TXT "D."
      WRD 0
DDOT  WRD LIST1  ; Process colon list
      WRD ULIT    ; push next inline literal
        WRD 0
      WRD DDOTR
      WRD SPACE
      WRD EXITT   ; EXIT  (return from word execution)
      WRD L150

; : u. ( u -- ) ( 6.1.2320 )( 0x9b ) 0 d. ;
; U.		( u -- )
;		Display an unsigned integer in free format.

L151  WRD $02
      TXT "U."
      WRD 0
UDOT  WRD LIST1  ; Process colon list
      WRD ULIT    ; push next inline literal
        WRD 0
      WRD DDOT
      WRD EXITT   ; EXIT  (return from word execution)

; : . ( n -- ) ( 6.1.0180 )( 0x9d ) base @ 10 xor if u. exit then s>d d. ;
; .		( w -- )
;		Display an integer in free format, preceeded by a space.

      WRD L151
L152  WRD $01
      TXT "."
      WRD 0
DOT   WRD LIST1  ; Process colon list
      WRD BASE    ; BASE (return address of variable pointing number base system)
      WRD ATT     ; @  (put to stack value at address on the stack top)
      WRD ULIT    ; push next inline literal
        WRD $0A
      WRD XORR    ; XOR  (bitwise XOR between two numbers on stack)
      WRD UIF     ; jump to next inline literal if top of stack is nonzero
        WRD DOT1
      WRD UDOT
      WRD EXITT   ; EXIT  (return from word execution)
DOT1  WRD STOD
      WRD DDOT
      WRD EXITT   ; EXIT  (return from word execution)

; : ? ( a -- ) ( 15.6.1.0600 ) @ . ;
; ?		( a -- )
;		Display the contents in a memory cell.

      WRD L152
L153  WRD $01
      TXT "?"
      WRD 0
QUEST WRD LIST1  ; Process colon list
      WRD ATT     ; @  (put to stack value at address on the stack top)
      WRD DOT
      WRD EXITT   ; EXIT  (return from word execution)

; 
; ( bits & bytes )
; 
; : pack ( a1 u a2 -- a2 ) ( 0x83 )
;   over 256 u<
;   if dup >r  over >r  char+ swap chars move  r> r@ c!  r> exit
;   then -18 throw ;
; PACK ( a1 u a2 -- a2 )

      WRD L153
L154  WRD $04
      TXT "PACK"
      WRD 0
PACK  WRD LIST1  ; Process colon list
      WRD OVER    ; OVER  (copy second value at stack to stack top)
      WRD ULIT    ; push next inline literal, max allowed string constant length
        WRD $FF   ; BUG: original version had WRD RESET !!!
      WRD ULESS   ; U<  (is second on stack unsigned less than top on stack)
      
      WRD UIF     ; jump to next inline literal if top of stack is nonzero
        WRD PACK1
      WRD DUP     ; DUP  (duplicate value at stack top)
      WRD TOR     ; >R  (push data stack to return stack)
      WRD OVER    ; OVER  (copy second value at stack to stack top)
      WRD TOR     ; >R  (push data stack to return stack)
      WRD CHARP   ; CHAR+ (Increment address at top by 1 characer size)
      WRD SWAP    ; SWAP  (swap two values at stack top)
      WRD MOVE
      WRD RFROM   ; R> (pop return stack to  data stack)
      WRD RAT     ; R@ (copy top of return stack to  data stack)
      WRD CSTOR   ; C!  (write byte at second stack item to address at stack top)
      WRD RFROM   ; R> (pop return stack to  data stack)
      WRD EXITT   ; EXIT  (return from word execution)
PACK1 WRD ULIT    ; push next inline literal
        WRD -18
      WRD THROW
      WRD EXITT   ; EXIT  (return from word execution)

; 
; : depth ( -- n ) ( 6.1.1200 )( 0x51 )
;   sp@  tid @ cell+ @  swap - [ 1 cells ] literal / ;
; DEPTH	( -- n )
;		Return the depth of the data stack.

      WRD L154
L155  WRD $05
      TXT "DEPTH"
      WRD 0
DEPTH WRD LIST1  ; Process colon list
      WRD SPAT
      WRD TID
      WRD ATT     ; @  (put to stack value at address on the stack top)
      WRD CELLP   ; CELL+ (Increment address at top by 1 cell size)
      WRD CELLP   ; CELL+ (Increment address at top by 1 cell size)
      WRD ATT     ; @  (put to stack value at address on the stack top)
      WRD SWAP    ; SWAP  (swap two values at stack top)
      WRD MINUS   ; -  (subtract numbers at stack top)
      WRD ULIT    ; push next inline literal
        WRD CELL1
      WRD SLASH
      WRD EXITT   ; EXIT  (return from word execution)

; : ?stack ( -- ) depth 0< abort" depth?" ;
; ?STACK	( -- )
;		Abort if the data stack underflows.

      WRD L155
L156  WRD $06
      TXT "?STACK"
      WRD 0
QSTAC WRD LIST1  ; Process colon list
      WRD DEPTH
      WRD ZLESS   ; 0<  (true if negative number on stack)
      WRD UABOR
      WRD $06
      TXT "depth?"
      WRD EXITT   ; EXIT  (return from word execution)
; ( terminal )
; 
; : accept ( a u -- u ) ( 6.1.0695 )
;   over + over ( bot eot cur )
;   begin key
;     dup [ =cr ] literal xor ( carrage return ? )
;   while
;     dup [ =bs ] literal = ( backspace ? )
;     if ( destructive backspace )
;       drop  >r over r@ < dup ( any chars ? )
;       if [ =bs ] literal dup emit  bl emit  emit
;       then r> +
;     else ( printable )
;       >r  2dup xor ( more ? )
;       if r@ over c!  char+  r@ emit
;       then r> drop
;     then
;   repeat drop  nip  swap - ;
; 
; ACCEPT ( a u -- u )
;  accept characters from input buffer
      WRD L156
L157  WRD $06
      TXT "ACCEPT"
      WRD 0
ACCEP WRD LIST1  ; Process colon list
      WRD OVER    ; OVER  (copy second value at stack to stack top)
      WRD PLUS    ; + (add two numbers on stack)
      WRD OVER    ; OVER  (copy second value at stack to stack top)
ACCE1 WRD KEY
      WRD DUP     ; DUP  (duplicate value at stack top)
      WRD ULIT    ; push next inline literal
        WRD ECR
      WRD XORR    ; XOR  (bitwise XOR between two numbers on stack)
      WRD UIF     ; jump to next inline literal if top of stack is nonzero
        WRD ACCE6
      WRD DUP     ; DUP  (duplicate value at stack top)
      WRD ULIT    ; push next inline literal
        WRD EBS
      WRD EQUAL
      WRD UIF     ; jump to next inline literal if top of stack is nonzero
        WRD ACCE3
      WRD DROP    ; DROP  (remove value at stack)
      WRD TOR     ; >R  (push data stack to return stack)
      WRD OVER    ; OVER  (copy second value at stack to stack top)
      WRD RAT     ; R@ (copy top of return stack to  data stack)
      WRD LESS    ; <  (is second on stack less than top on stack)
      WRD DUP     ; DUP  (duplicate value at stack top)
      WRD UIF     ; jump to next inline literal if top of stack is nonzero
        WRD ACCE2
      WRD ULIT    ; push next inline literal
        WRD EBS
      WRD DUP     ; DUP  (duplicate value at stack top)
      WRD EMIT
      WRD BLL
      WRD EMIT
      WRD EMIT
ACCE2 WRD RFROM   ; R> (pop return stack to  data stack)
      WRD PLUS    ; + (add two numbers on stack)
      WRD UELSE   ; jump to next inline literal
        WRD ACCE5
ACCE3 WRD TOR     ; >R  (push data stack to return stack)
      WRD TDUP    ; 2DUP (duplicate top two numbers)
      WRD XORR    ; XOR  (bitwise XOR between two numbers on stack)
      WRD UIF     ; jump to next inline literal if top of stack is nonzero
        WRD ACCE4
      WRD RAT     ; R@ (copy top of return stack to  data stack)
      WRD OVER    ; OVER  (copy second value at stack to stack top)
      WRD CSTOR   ; C!  (write byte at second stack item to address at stack top)
      WRD CHARP   ; CHAR+ (Increment address at top by 1 characer size)
      WRD RAT     ; R@ (copy top of return stack to  data stack)
      WRD EMIT
ACCE4 WRD RFROM   ; R> (pop return stack to  data stack)
      WRD DROP    ; DROP  (remove value at stack)
ACCE5 WRD UELSE   ; jump to next inline literal
        WRD ACCE1
ACCE6 WRD DROP    ; DROP  (remove value at stack)
      WRD NIP     ; NIP (remove 2nd item from stack)
      WRD SWAP    ; SWAP  (swap two values at stack top)
      WRD MINUS   ; -  (subtract numbers at stack top)
      WRD EXITT   ; EXIT  (return from word execution)

; ( interpreter )
; 
; : same? ( a a u -- f ) \ ???faster chars
;   swap >r
;   begin dup
;   while char-  2dup + c@  over r@ + c@  xor
;   until r> drop 2drop  0 exit ( no match )
;   then r> drop 2drop  -1 ; ( found )
; SAME?	( a a u -- a a f \ -0+ )
;		Compare u cells in two strings. Return 0 if identical.

      WRD L157
L158  WRD $05
      TXT "SAME?"
      WRD 0
SAMEQ WRD LIST1  ; Process colon list
      WRD SWAP    ; SWAP  (swap two values at stack top)
      WRD TOR     ; >R  (push data stack to return stack)
SAMQ1 WRD DUP     ; DUP  (duplicate value at stack top)
      WRD UIF     ; jump to next inline literal if top of stack is nonzero
        WRD SAMQ2
      WRD CHARM   ; CHAR- (Decrement address at top by 1 characer size)
      WRD TDUP    ; 2DUP (duplicate top two numbers)
      WRD PLUS    ; + (add two numbers on stack)
      WRD CAT     ; C@ (read byte from address at stack top ))
      WRD OVER    ; OVER  (copy second value at stack to stack top)
      WRD RAT     ; R@ (copy top of return stack to  data stack)
      WRD PLUS    ; + (add two numbers on stack)
      WRD CAT     ; C@ (read byte from address at stack top ))
      WRD XORR    ; XOR  (bitwise XOR between two numbers on stack)
      WRD UIF     ; jump to next inline literal if top of stack is nonzero
        WRD SAMQ1
      WRD RFROM   ; R> (pop return stack to  data stack)
      WRD DROP    ; DROP  (remove value at stack)
      WRD TDROP   ; 2DROP remove 2 items from stack
      WRD ULIT    ; push next inline literal
        WRD 0
      WRD EXITT   ; EXIT  (return from word execution)
SAMQ2 WRD RFROM   ; R> (pop return stack to  data stack)
      WRD DROP    ; DROP  (remove value at stack)
      WRD TDROP   ; 2DROP remove 2 items from stack
      WRD ULIT    ; push next inline literal
        WRD $FFFF
      WRD EXITT   ; EXIT  (return from word execution)

; 
; : _delimit ( a u -- a u delta ) \ ???chars
;   bounds  dup >r  char-
;   begin char+  2dup xor ( skip leading bl )
;   while bl over c@ <
;   until swap over ( save first non blank addr )
;     begin char+  2dup xor ( scan trailing bl )
;     while dup c@  bl 1 +  <
;     until nip  dup char+ ( found )
;     else drop dup ( not found )
;     then >r  over -  r>
;   else drop 0 over ( all bl )
;   then r> - ;
; _DELIMIT ( a u -- a u delta )
      WRD L158
L159  WRD $08
      TXT "_DELIMIT"
      WRD 0
UDELI WRD LIST1  ; Process colon list
      WRD BNDS    ; BOUNDS (From addr and length, produce  addr+u and the start address)
      WRD DUP     ; DUP  (duplicate value at stack top)
      WRD TOR     ; >R  (push data stack to return stack)
      WRD CHARM   ; CHAR- (Decrement address at top by 1 characer size)
UDEL1 WRD CHARP   ; CHAR+ (Increment address at top by 1 characer size)
      WRD TDUP    ; 2DUP (duplicate top two numbers)
      WRD XORR    ; XOR  (bitwise XOR between two numbers on stack)
      WRD UIF     ; jump to next inline literal if top of stack is nonzero
        WRD UDEL5
      WRD BLL
      WRD OVER    ; OVER  (copy second value at stack to stack top)
      WRD CAT     ; C@ (read byte from address at stack top ))
      WRD LESS    ; <  (is second on stack less than top on stack)
      WRD UIF     ; jump to next inline literal if top of stack is nonzero
        WRD UDEL1
      WRD SWAP    ; SWAP  (swap two values at stack top)
      WRD OVER    ; OVER  (copy second value at stack to stack top)
UDEL2 WRD CHARP   ; CHAR+ (Increment address at top by 1 characer size)
      WRD TDUP    ; 2DUP (duplicate top two numbers)
      WRD XORR    ; XOR  (bitwise XOR between two numbers on stack)
      WRD UIF     ; jump to next inline literal if top of stack is nonzero
        WRD UDEL3
      WRD DUP     ; DUP  (duplicate value at stack top)
      WRD CAT     ; C@ (read byte from address at stack top ))
      WRD BLL
      WRD ULIT    ; push next inline literal
        WRD $01
      WRD PLUS    ; + (add two numbers on stack)
      WRD LESS    ; <  (is second on stack less than top on stack)
      WRD UIF     ; jump to next inline literal if top of stack is nonzero
        WRD UDEL2
      WRD NIP     ; NIP (remove 2nd item from stack)
      WRD DUP     ; DUP  (duplicate value at stack top)
      WRD CHARP   ; CHAR+ (Increment address at top by 1 characer size)
      WRD UELSE   ; jump to next inline literal
        WRD UDEL4
UDEL3 WRD DROP    ; DROP  (remove value at stack)
      WRD DUP     ; DUP  (duplicate value at stack top)
UDEL4 WRD TOR     ; >R  (push data stack to return stack)
      WRD OVER    ; OVER  (copy second value at stack to stack top)
      WRD MINUS   ; -  (subtract numbers at stack top)
      WRD RFROM   ; R> (pop return stack to  data stack)
      WRD UELSE   ; jump to next inline literal
        WRD UDEL6
UDEL5 WRD DROP    ; DROP  (remove value at stack)
      WRD ULIT    ; push next inline literal
        WRD 0
      WRD OVER    ; OVER  (copy second value at stack to stack top)
UDEL6 WRD RFROM   ; R> (pop return stack to  data stack)
      WRD MINUS   ; -  (subtract numbers at stack top)
      WRD EXITT   ; EXIT  (return from word execution)

; 
; : _parse ( a1 u1 c -- a1 u2 delta ) \ ???chars
;   >r  over +  over char- ( save char, adjust addr )
;   begin char+  2dup xor ( inc addr ? )
;   while dup c@ r@ = ( match ? )
;   until swap r> 2drop  over -  dup 1 + exit ( found )
;   then  swap r> 2drop  over -  dup ; ( not found )
; 

; :PARSE	( b u c -- b u delta ; <string> )
;		Scan string delimited by c. Return found string and its offset.

      WRD L159
L160  WRD $06
      TXT "_PARSE"
      WRD 0
UPARS WRD LIST1  ; Process colon list
      WRD TOR     ; >R  (push data stack to return stack)
      WRD OVER    ; OVER  (copy second value at stack to stack top)
      WRD PLUS    ; + (add two numbers on stack)
      WRD OVER    ; OVER  (copy second value at stack to stack top)
      WRD CHARM   ; CHAR- (Decrement address at top by 1 characer size)
UPAR1 WRD CHARP   ; CHAR+ (Increment address at top by 1 characer size)
      WRD TDUP    ; 2DUP (duplicate top two numbers)
      WRD XORR    ; XOR  (bitwise XOR between two numbers on stack)
      WRD UIF     ; jump to next inline literal if top of stack is nonzero
        WRD UPAR2
      WRD DUP     ; DUP  (duplicate value at stack top)
      WRD CAT     ; C@ (read byte from address at stack top ))
      WRD RAT     ; R@ (copy top of return stack to  data stack)
      WRD EQUAL
      WRD UIF     ; jump to next inline literal if top of stack is nonzero
        WRD UPAR1
      WRD SWAP    ; SWAP  (swap two values at stack top)
      WRD RFROM   ; R> (pop return stack to  data stack)
      WRD TDROP   ; 2DROP remove 2 items from stack
      WRD OVER    ; OVER  (copy second value at stack to stack top)
      WRD MINUS   ; -  (subtract numbers at stack top)
      WRD DUP     ; DUP  (duplicate value at stack top)
      WRD ULIT    ; push next inline literal
        WRD $01
      WRD PLUS    ; + (add two numbers on stack)
      WRD EXITT   ; EXIT  (return from word execution)
UPAR2 WRD SWAP    ; SWAP  (swap two values at stack top)
      WRD RFROM   ; R> (pop return stack to  data stack)
      WRD TDROP   ; 2DROP remove 2 items from stack
      WRD OVER    ; OVER  (copy second value at stack to stack top)
      WRD MINUS   ; -  (subtract numbers at stack top)
      WRD DUP     ; DUP  (duplicate value at stack top)
      WRD EXITT   ; EXIT  (return from word execution)
; : name> ( a -- xt ) count chars + char+ aligned ;
; NAME>	( na -- ca )
;		Return a code address given a name address.

      WRD L160
L161  WRD $05
      TXT "NAME>"
      WRD 0
NAMET WRD LIST1  ; Process colon list
      WRD COUNT
      WRD PLUS    ; + (add two numbers on stack)
      WRD CHARP   ; CHAR+ (Increment address at top by 1 characer size)
      WRD EXITT   ; EXIT  (return from word execution)
; 
; : wid? ( a u wid -- xt lex -1 | a u 0 ) \ ???chars
;   swap >r  @ ( address of last word )
;   begin dup ( last word ? )
;   while count r@ = ( count ? )
;     if 2dup r@ same? ( match )
;       if swap r> 2drop char-
;         dup name>  swap count chars + c@  -1 exit ( found )
;       then
;     then char-  cell- @ ( link )
;   repeat drop r>  0 ; ( no match )
      WRD L161
L162  WRD $04
      TXT "WID?"
      WRD 0
WIDQ  WRD LIST1  ; Process colon list
      WRD SWAP    ; SWAP  (swap two values at stack top)
      WRD TOR     ; >R  (push data stack to return stack)
      WRD ATT     ; @  (put to stack value at address on the stack top)
WIDQ1 WRD DUP     ; DUP  (duplicate value at stack top)
      WRD UIF     ; jump to next inline literal if top of stack is nonzero
        WRD WIDQ4
      WRD COUNT
      WRD RAT     ; R@ (copy top of return stack to  data stack)
      WRD EQUAL
      WRD UIF     ; jump to next inline literal if top of stack is nonzero
        WRD WIDQ3
      WRD TDUP    ; 2DUP (duplicate top two numbers)
      WRD RAT     ; R@ (copy top of return stack to  data stack)
      WRD SAMEQ
      WRD UIF     ; jump to next inline literal if top of stack is nonzero
        WRD WIDQ2
      WRD SWAP    ; SWAP  (swap two values at stack top)
      WRD RFROM   ; R> (pop return stack to  data stack)
      WRD TDROP   ; 2DROP remove 2 items from stack
      WRD CHARM   ; CHAR- (Decrement address at top by 1 characer size)
      WRD DUP     ; DUP  (duplicate value at stack top)
      WRD NAMET
      WRD SWAP    ; SWAP  (swap two values at stack top)
      WRD COUNT
      WRD PLUS    ; + (add two numbers on stack)
      WRD CAT     ; C@ (read byte from address at stack top ))
      WRD ULIT    ; push next inline literal
        WRD $FFFF
      WRD EXITT   ; EXIT  (return from word execution)
WIDQ2:
WIDQ3 WRD CHARM   ; CHAR- (Decrement address at top by 1 characer size)
      WRD CELLM   ; CELL- (Decrement address at top by 1 cell size)
      WRD ATT     ; @  (put to stack value at address on the stack top)
      WRD UELSE   ; jump to next inline literal
        WRD WIDQ1
WIDQ4 WRD DROP    ; DROP  (remove value at stack)
      WRD RFROM   ; R> (pop return stack to  data stack)
      WRD ULIT    ; push next inline literal
        WRD 0
      WRD EXITT   ; EXIT  (return from word execution)

; 
; create context ( search order )
;   #vocs 1 + cells allot ( wids )
; CONTEXT	( -- a )
;		A area to specify vocabulary search order.

      WRD L162
L163  WRD $07
      TXT "CONTEXT"
      WRD 0
CONTE WRD LIST1  ; Process colon list
      WRD UVAR    ; _VAR  (put to data stack address of next word and exit)
      WRD 0
      WRD 0
      WRD 0
      WRD 0
      WRD 0
      WRD 0
      WRD 0
      WRD 0
      WRD 0

; 
; : sfind ( a u -- xt lex -1 | a u 0 )
;   context cell- >r ( setup )
;   begin r> cell+ dup >r @ dup ( wid | 0 )
;   while wid? ( found ? )
;   until -1 then r> drop ;
; SFIND ( a u -- xt lex -1 | a u 0 )
      WRD L163
L164  WRD $05
      TXT "SFIND"
      WRD 0
SFIND WRD LIST1  ; Process colon list
      WRD CONTE
      WRD CELLM   ; CELL- (Decrement address at top by 1 cell size)
      WRD TOR     ; >R  (push data stack to return stack)
SFIN1 WRD RFROM   ; R> (pop return stack to  data stack)
      WRD CELLP   ; CELL+ (Increment address at top by 1 cell size)
      WRD DUP     ; DUP  (duplicate value at stack top)
      WRD TOR     ; >R  (push data stack to return stack)
      WRD ATT     ; @  (put to stack value at address on the stack top)
      WRD DUP     ; DUP  (duplicate value at stack top)
      WRD UIF     ; jump to next inline literal if top of stack is nonzero
        WRD SFIN2
      WRD WIDQ
      WRD UIF     ; jump to next inline literal if top of stack is nonzero
        WRD SFIN1
      WRD ULIT    ; push next inline literal
        WRD $FFFF
SFIN2 WRD RFROM   ; R> (pop return stack to  data stack)
      WRD DROP    ; DROP  (remove value at stack)
      WRD EXITT   ; EXIT  (return from word execution)

; 
; : _[ ( a u -- ) ( the forth interpreter )
;   sfind ( search dictionary )
;   if [ =comp ] literal and abort" compile?"
;     execute ?stack exit
;   then
;   number? ( unknown symbol, try to convert a number )
;   if dpl @ 0< ( single? )
;     if drop then exit
;   then -13 throw ; compile-only
; _[ ( a u -- ) 
; ( the Forth interpreter )
      WRD L164
L165  WRD $02
      TXT "_["
      WRD ECOMP
ULBR  WRD LIST1  ; Process colon list
      WRD SFIND
      WRD UIF     ; jump to next inline literal if top of stack is nonzero
        WRD ULBR1
      WRD ULIT    ; push next inline literal
        WRD ECOMP
      WRD ANDD    ; AND  (bitwise AND between two numbers on stack)
      WRD UABOR
      WRD $08
      TXT "compile?"
      WRD EXECU   ; EXECUTE  (execute word adressed at stack)
      WRD QSTAC
      WRD EXITT   ; EXIT  (return from word execution)
ULBR1 WRD NUMQ
      WRD UIF     ; jump to next inline literal if top of stack is nonzero
        WRD ULBR3
      WRD DPL
      WRD ATT     ; @  (put to stack value at address on the stack top)
      WRD ZLESS   ; 0<  (true if negative number on stack)
      WRD UIF     ; jump to next inline literal if top of stack is nonzero
        WRD ULBR2
      WRD DROP    ; DROP  (remove value at stack)
ULBR2 WRD EXITT   ; EXIT  (return from word execution)
ULBR3 WRD ULIT    ; push next inline literal
        WRD -13
      WRD THROW
      WRD EXITT   ; EXIT  (return from word execution)

; : [ ( -- ) ( 6.1.2500 ) ['] _[  0  state 2! ; immediate
; [		( -- )
;		Start the text interpreter. Commands after inside word definition will be executed immediately

      WRD L165
L166  WRD $01
      TXT "["
      WRD EIMED
LBRAC WRD LIST1  ; Process colon list
      WRD ULIT    ; push next inline literal
        WRD ULBR  ; ***CHECK IT
      WRD ULIT    ; push next inline literal
        WRD 0
      WRD STATE
      WRD TSTOR
      WRD EXITT   ; EXIT  (return from word execution)

; 
; : source ( -- a u ) ( 6.1.2216 ) #in 2@ ;
; SOURCE ( -- a u )
; directly accessing the input buffer 
      WRD L166
L167  WRD $06
      TXT "SOURCE"
      WRD 0
SOURC WRD LIST1  ; Process colon list
      WRD NIN
      WRD TAT
      WRD EXITT   ; EXIT  (return from word execution)

; : parse-word ( "ccc" -- a u ) source >in @ /string _delimit >in +! ;
; PARSE-WORD ( "ccc" -- a u )
      WRD L167
L168  WRD $0A
      TXT "PARSE-WORD"
      WRD 0
PARSW WRD LIST1  ; Process colon list
      WRD SOURC
      WRD TOIN
      WRD ATT     ; @  (put to stack value at address on the stack top)
      WRD SSTRI
      WRD UDELI
      WRD TOIN
      WRD PLUST
      WRD EXITT   ; EXIT  (return from word execution)

; 
; : evaluate ( a u -- ) ( 6.1.1360 )( 0xcd )
;   >in @ >r  0 >in !  source >r >r  #in 2!
;   begin parse-word dup
;   while state cell+ @ execute
;   repeat 2drop  r> r> #in 2!  r> >in ! ;
; EVALUATE ( a u -- ) 
; Save the current input source specification. Store minus-one (-1) in SOURCE-ID if it is present. 
      WRD L168
L169  WRD $08
      TXT "EVALUATE"
      WRD 0
EVALU WRD LIST1  ; Process colon list
      WRD TOIN
      WRD ATT     ; @  (put to stack value at address on the stack top)
      WRD TOR     ; >R  (push data stack to return stack)
      WRD ULIT    ; push next inline literal
        WRD 0
      WRD TOIN
      WRD STORE   ; !  (write value at second stack item to address at stack top)
      WRD SOURC
      WRD TOR     ; >R  (push data stack to return stack)
      WRD TOR     ; >R  (push data stack to return stack)
      WRD NIN
      WRD TSTOR
EVAL1 WRD PARSW
      WRD DUP     ; DUP  (duplicate value at stack top)
      WRD UIF     ; jump to next inline literal if top of stack is nonzero
        WRD EVAL2
      WRD STATE
      WRD CELLP   ; CELL+ (Increment address at top by 1 cell size)
      WRD ATT     ; @  (put to stack value at address on the stack top)
      WRD EXECU   ; EXECUTE  (execute word adressed at stack)
      WRD UELSE   ; jump to next inline literal
        WRD EVAL1
EVAL2 WRD TDROP   ; 2DROP remove 2 items from stack
      WRD RFROM   ; R> (pop return stack to  data stack)
      WRD RFROM   ; R> (pop return stack to  data stack)
      WRD NIN
      WRD TSTOR
      WRD RFROM   ; R> (pop return stack to  data stack)
      WRD TOIN
      WRD STORE   ; !  (write value at second stack item to address at stack top)
      WRD EXITT   ; EXIT  (return from word execution)


; create 'ok ( prompt options )
;   ' noop , ( typically .s )

; 'OK 
; ( prompt options )
      WRD L169
L170  WRD $03
      TXT "'OK"
      WRD 0
TOK   WRD LIST1  ; Process colon list
      WRD UVAR    ; _VAR  (put to data stack address of next word and exit)
      WRD NOOP
;***********************************************************************
;*  OUTER INTERPRETER                                                  *
;***********************************************************************

; : quit ( -- ) ( r: i*x -- ) ( 6.1.2050 )
;   sup @ rp!         ( reset return stack )
;   [ ' [ compile, ]  ( reset interpret state )
;   s" con" stdin     ( reset console i/o, ms-dos only )
;   begin
;     begin
;       [ =tib ] literal  ( input buffer )
;       dup [ #tib ] literal accept space ( user input )
;       ['] evaluate catch dup ( error ? )
;       if dup -1 xor      ( abort  = -1 )
;         if cr dup -2 xor ( abort" = -2 )
;           if source drop ( undefined error )
;             >in @ -trailing type ."  ?(" 0 .r ." )"
;           else csp @ count type
;           then space
;         then
;         sup cell+ @ sp! ( reset data stack )
;         recurse         ( restart )
;       then cr state @ = ( 0 from catch )
;     until 'ok @ execute ." ok " ( prompt )
;   again ;
; 

; QUIT	( -- )
;		Reset return stack pointer and start text interpreter.

      WRD L170
L171  WRD $04
      TXT "QUIT"
      WRD 0
QUIT  WRD LIST1  ; Process colon list
      WRD SUP
      WRD CELLP   ; CELL+ (Increment address at top by 1 cell size)
      WRD ATT     ; @  (put to stack value at address on the stack top)
      WRD RPSTO   ; RP! Set return stack pointer
      WRD LBRAC
QUIT1 WRD ULIT    ; push next inline literal
        WRD ETIB
      WRD DUP     ; DUP  (duplicate value at stack top)
      WRD ULIT    ; push next inline literal
        WRD NTIB
      WRD ACCEP
      WRD SPACE
      WRD ULIT    ; push next inline literal
        WRD EVALU
      WRD CATCH
      WRD DUP     ; DUP  (duplicate value at stack top)
      WRD UIF     ; jump to next inline literal if top of stack is nonzero
        WRD QUIT5
      WRD DUP     ; DUP  (duplicate value at stack top)
      WRD ULIT    ; push next inline literal
        WRD -1
      WRD XORR    ; XOR  (bitwise XOR between two numbers on stack)
      WRD UIF     ; jump to next inline literal if top of stack is nonzero
        WRD QUIT4
      WRD CR
      WRD DUP     ; DUP  (duplicate value at stack top)
      WRD ULIT    ; push next inline literal
        WRD -2
      WRD XORR    ; XOR  (bitwise XOR between two numbers on stack)
      WRD UIF     ; jump to next inline literal if top of stack is nonzero
        WRD QUIT2
      WRD SOURC
      WRD DROP    ; DROP  (remove value at stack)
      WRD TOIN
      WRD ATT     ; @  (put to stack value at address on the stack top)
      WRD DTRAI
      WRD TYPE
      WRD UDOTQ
      WRD $03
      TXT " ?("
      WRD ULIT    ; push next inline literal
        WRD 0
      WRD DOTR
      WRD UDOTQ
      WRD $01
      TXT ")"
      WRD UELSE   ; jump to next inline literal
        WRD QUIT3
QUIT2 WRD CSP
      WRD ATT     ; @  (put to stack value at address on the stack top)
      WRD COUNT
      WRD TYPE
QUIT3 WRD SPACE
QUIT4 WRD SUP
      WRD CELLP   ; CELL+ (Increment address at top by 1 cell size)
      WRD CELLP   ; CELL+ (Increment address at top by 1 cell size)
      WRD ATT     ; @  (put to stack value at address on the stack top)
      WRD SPSTO   ; SP!  (Set data stack pointer)
      WRD QUIT
QUIT5 WRD CR
      WRD STATE
      WRD ATT     ; @  (put to stack value at address on the stack top)
      WRD EQUAL
      WRD UIF     ; jump to next inline literal if top of stack is nonzero
        WRD QUIT1
      WRD TOK
      WRD ATT     ; @  (put to stack value at address on the stack top)
      WRD EXECU   ; EXECUTE  (execute word adressed at stack)
      WRD UDOTQ
      WRD $03
      TXT "ok "
      WRD UELSE   ; jump to next inline literal
        WRD QUIT1

; ( compiler )
; 
; : align ( -- ) ( 6.1.0705 ) here aligned dp ! ;
; ALIGN ( -- ) 
; Align dictionary to cell boundary
      WRD L171
L172  WRD $05
      TXT "ALIGN"
      WRD EIMED
ALGNN WRD LIST1  ; Process colon list
      WRD EXITT   ; EXIT  (return from word execution)

; 
; : allot ( n -- ) ( 6.1.0710 ) dp +! ;
; ALLOT	( n -- )
;		Allocate n bytes to the code dictionary.

      WRD L172
L173  WRD $05
      TXT "ALLOT"
      WRD 0
ALLOT WRD LIST1  ; Process colon list
      WRD DP
      WRD PLUST
      WRD EXITT   ; EXIT  (return from word execution)
; : s, ( a u -- ) here  over chars char+ allot  pack drop ;
; S, ( a u -- )
      WRD L173
L174  WRD $02
      TXT "S,"
      WRD 0
SCOMA WRD LIST1  ; Process colon list
      WRD HERE    ; HERE (return top of code directory)
      WRD OVER    ; OVER  (copy second value at stack to stack top)
      WRD CHARP   ; CHAR+ (Increment address at top by 1 characer size)
      WRD ALLOT
      WRD PACK
      WRD DROP    ; DROP  (remove value at stack)
      WRD EXITT   ; EXIT  (return from word execution)

; : c, ( n -- ) ( 6.1.0860 )( 0xd0 ) here  [ 1 chars ] literal allot  c! ;
; C, ( char -- )
; Reserve space for one character in the data space and store char in the space. 
      WRD L174
L175  WRD $02
      TXT "C,"
      WRD 0
CCOMA WRD LIST1  ; Process colon list
      WRD HERE    ; HERE (return top of code directory)
      WRD ULIT    ; push next inline literal
        WRD CHAR1
      WRD ALLOT
      WRD CSTOR   ; C!  (write byte at second stack item to address at stack top)
      WRD EXITT   ; EXIT  (return from word execution)

; : , ( n -- ) ( 6.1.0150 )( 0xd3 ) here  [ 1 cells ] literal allot  ! ;
; ,		( w -- )
;		Compile an integer into the code dictionary.

      WRD L175
L176  WRD $01
      TXT ","
      WRD 0
COMMA WRD LIST1  ; Process colon list
      WRD HERE    ; HERE (return top of code directory)
      WRD ULIT    ; push next inline literal
        WRD CELL1
      WRD ALLOT
      WRD STORE   ; !  (write value at second stack item to address at stack top)
      WRD EXITT   ; EXIT  (return from word execution)

; 
; : compile, ( xt -- ) ( 6.2.0945 )( 0xdd ) , ;
; COMPILE, ( xt -- )
; Append the execution semantics of the definition represented by xt to the execution semantics of the current definition. 
      WRD L176
L177  WRD $08
      TXT "COMPILE,"
      WRD 0
COMPC WRD LIST1  ; Process colon list
      WRD COMMA   ; ,  (compile integer number at stack into code dictionary)
      WRD EXITT   ; EXIT  (return from word execution)

; : literal ( n -- ) ( 6.1.1780 ) ['] _lit compile, , ; immediate
; LITERAL	( w -- )
;		Used only inside a colon definition. At compile time, compiles a value from the stack into the definition as a literal. At run time, the value will be pushed on the stack.

      WRD L177
L178  WRD $07
      TXT "LITERAL"
      WRD EIMED
LITER WRD LIST1  ; Process colon list
      WRD ULIT    ; push next inline literal
        WRD ULIT    ; push next inline literal
      WRD COMPC
      WRD COMMA   ; ,  (compile integer number at stack into code dictionary)
      WRD EXITT   ; EXIT  (return from word execution)

; 
; : char ( "ccc" -- c ) ( 6.1.0895 ) parse-word drop c@ ;
; CHAR	( -- c )
;		Parse next word and return its first character.

      WRD L178
L179  WRD $04
      TXT "CHAR"
      WRD 0
CHARR WRD LIST1  ; Process colon list
      WRD PARSW
      WRD DROP    ; DROP  (remove value at stack)
      WRD CAT     ; C@ (read byte from address at stack top ))
      WRD EXITT   ; EXIT  (return from word execution)

; : [char] ( "ccc" -- ) ( 6.1.2520 ) char  [ ' literal compile, ] ; immediate
; CHAR ( "<spaces>name" -- )
; Skip leading space delimiters. Parse name delimited by a space. Append the run-time semantics given below to the current definition.
; Run-time: ( -- char )
; Place char, the value of the first character of name, on the stack. 
      WRD L179
L180  WRD $06
      TXT "[CHAR]"
      WRD EIMED
BCHAR WRD LIST1  ; Process colon list
      WRD CHARR
      WRD LITER
      WRD EXITT   ; EXIT  (return from word execution)
; 
; : ' ( "name" -- xt ) ( 6.1.0070 ) parse-word sfind if drop exit then -13 throw ;
; '		( -- ca )
;		Search context vocabularies for the next word in input stream.

      WRD L180
L181  WRD $01
      TXT "'"
      WRD 0
TICK  WRD LIST1  ; Process colon list
      WRD PARSW
      WRD SFIND
      WRD UIF     ; jump to next inline literal if top of stack is nonzero
        WRD TICK1
      WRD DROP    ; DROP  (remove value at stack)
      WRD EXITT   ; EXIT  (return from word execution)
TICK1 WRD ULIT    ; push next inline literal
        WRD -13
      WRD THROW
      WRD EXITT   ; EXIT  (return from word execution)

; : ['] ( "name" -- ) ( 6.1.2510 ) '  [ ' literal compile, ] ; immediate
; Compilation: ( "<spaces>name" -- ) Skip leading space delimiters. Parse name delimited by a space. Find name. Append the run-time semantics given below to the current definition.
; Run-time: ( -- xt ) Place name's execution token xt on the stack. The execution token returned by the compiled phrase "['] X" is the same value returned by "' X" outside of compilation state.

      WRD L181
L182  WRD $03
      TXT "[']"
      WRD EIMED
BTICK WRD LIST1  ; Process colon list
      WRD TICK
      WRD LITER
      WRD EXITT   ; EXIT  (return from word execution)
; 
; : parse ( c "ccc" -- a u ) ( 6.2.2008 ) \ ???move
;   >r source >in @ /string r> _parse >in +! ;
; PARSE	( c -- b u ; <string> )
;		Scan input stream and return counted string delimited by c.

      WRD L182
L183  WRD $05
      TXT "PARSE"
      WRD 0
PARSE WRD LIST1  ; Process colon list
      WRD TOR     ; >R  (push data stack to return stack)
      WRD SOURC
      WRD TOIN
      WRD ATT     ; @  (put to stack value at address on the stack top)
      WRD SSTRI
      WRD RFROM   ; R> (pop return stack to  data stack)
      WRD UPARS
      WRD TOIN
      WRD PLUST
      WRD EXITT   ; EXIT  (return from word execution)
; 
; : .( ( "comment" -- ) ( 6.2.0200 ) [char] ) parse type ; immediate
; .(		( -- )
;		Output following string up to next ) .

      WRD L183
L184  WRD $02
      TXT ".("
      WRD EIMED
DOTP  WRD LIST1  ; Process colon list
      WRD ULIT    ; push next inline literal
        TXT ")"
      WRD PARSE
      WRD TYPE
      WRD EXITT   ; EXIT  (return from word execution)
; : ( ( "comment" -- ) ( 6.1.0080 ) [char] ) parse 2drop ; immediate
; (		( -- )
;		Ignore following string up to next ) . A comment.

      WRD L184
L185  WRD $01
      TXT "("
      WRD EIMED
PAREN WRD LIST1  ; Process colon list
      WRD ULIT    ; push next inline literal
        TXT ")"
      WRD PARSE
      WRD TDROP   ; 2DROP remove 2 items from stack
      WRD EXITT   ; EXIT  (return from word execution)

; : \ ( "comment" -- ) ( 6.2.2535 ) source >in ! drop ; immediate
; \		( -- )
;		Ignore following text till the end of line.

      WRD L185
L186  WRD $01
      WRD $5C ; "\"
      WRD EIMED
BSLSH WRD LIST1  ; Process colon list
      WRD SOURC
      WRD TOIN
      WRD STORE   ; !  (write value at second stack item to address at stack top)
      WRD DROP    ; DROP  (remove value at stack)
      WRD EXITT   ; EXIT  (return from word execution)

; 
; : sliteral ( a u -- ) ( -- a u ) ( 17.6.1.2212 )
;   ['] _s" compile, s, align ; immediate compile-only
; SLITERAL  ( c-addr1 u -- )
; Compilation: Append the run-time semantics given below to the current definition.
; Run-time: ( -- c-addr2 u ) Return c-addr2 u describing a string consisting of the characters specified by c-addr1 u during compilation. A program shall not alter the returned string.


      WRD L186
L187  WRD $08
      TXT "SLITERAL"
      WRD EIMCO
SLITE WRD LIST1  ; Process colon list
      WRD ULIT    ; push next inline literal
        WRD USQ
      WRD COMPC
      WRD SCOMA
      WRD EXITT   ; EXIT  (return from word execution)

; 
; : ,c" ( "ccc" -- ) [char] " parse s, align ;
; ,C"
;Compilation: ( "ccc<quote>" -- ) Parse ccc delimited by " (double-quote). Append the run-time semantics given below to the current definition.
; Run-time: ( -- c-addr u ) Return c-addr string consisting of the characters ccc. A program shall not alter the returned string. 

      WRD L187
L188  WRD $03
      WRD $2C
        WRD $43
        WRD $22 ; comma c quote
      WRD 0
CCQ   WRD LIST1  ; Process colon list
      WRD ULIT    ; push next inline literal
        WRD $22
      WRD PARSE
      WRD SCOMA
      WRD EXITT   ; EXIT  (return from word execution)
; 
; : s" ( "ccc" -- ) ( 6.1.2165 ) ['] _s" compile, ,c" ; immediate compile-only
; ,S"
;Compilation: ( "ccc<quote>" -- ) Parse ccc delimited by " (double-quote). Append the run-time semantics given below to the current definition.
; Run-time: ( -- c-addr u ) Return c-addr and u describing a string consisting of the characters ccc. A program shall not alter the returned string. 
      WRD L188
L189  WRD $02
      WRD $53
        WRD $22 ; S"
      WRD EIMCO
SQUOT WRD LIST1  ; Process colon list
      WRD ULIT    ; push next inline literal
        WRD USQ
      WRD COMPC
      WRD CCQ
      WRD EXITT   ; EXIT  (return from word execution)

; : ." ( "ccc" -- ) ( 6.1.0190 ) ['] _." compile, ,c" ; immediate compile-only
; ."		( -- ; <string> )
; Parse ccc delimited by " (double-quote). Append the run-time semantics given below to the current definition.
; Run-time: ( -- )

; Display ccc. 
      WRD L189
L190  WRD $02
      WRD $2E
        WRD $22 ; ."
      WRD EIMCO

DOTQ  WRD LIST1  ; Process colon list
      WRD ULIT    ; push next inline literal
        WRD UDOTQ
      WRD COMPC
      WRD CCQ
      WRD EXITT   ; EXIT  (return from word execution)

; 
; : abort" ( "ccc" -- ) ( 6.1.0680 )
;   ['] _abort" compile, ,c" ; immediate compile-only
; ABORT"	( -- ; <string> )
;		Conditional abort with an error message.

      WRD L190
L191  WRD $06
      WRD $41
        WRD $42
        WRD $4F
        WRD $52
        WRD $54
        WRD $22 ; ABORT"
      WRD EIMCO
ABORQ WRD LIST1  ; Process colon list
      WRD ULIT    ; push next inline literal
        WRD UABOR
      WRD COMPC
      WRD CCQ
      WRD EXITT   ; EXIT  (return from word execution)

; 
; : _] ( a u -- ) ( the forth compiler )
;   sfind ( search dictionary )
;   if [ =imed ] literal and
;     if execute ?stack exit ( immediate )
;     then compile, exit
;   then
;   number? ( unknown symbol, try to convert a number )
;   if dpl @ 0<
;     if drop ( single )
;     else swap  [ ' literal compile, ] ( double )
;     then  [ ' literal compile, ] exit
;   then -13 throw ; compile-only
; _] ( a u -- ) 
; ( the Forth compiler )
      WRD L191
L192  WRD $02
      TXT "_]"
      WRD ECOMP
URBR  WRD LIST1  ; Process colon list
      WRD SFIND
      WRD UIF     ; jump to next inline literal if top of stack is nonzero
        WRD URBR2
      WRD ULIT    ; push next inline literal
        WRD EIMED
      WRD ANDD    ; AND  (bitwise AND between two numbers on stack)
      WRD UIF     ; jump to next inline literal if top of stack is nonzero
        WRD URBR1
      WRD EXECU   ; EXECUTE  (execute word adressed at stack)
      WRD QSTAC
      WRD EXITT   ; EXIT  (return from word execution)
URBR1 WRD COMPC
      WRD EXITT   ; EXIT  (return from word execution)
URBR2 WRD NUMQ
      WRD UIF     ; jump to next inline literal if top of stack is nonzero
        WRD URBR5
      WRD DPL
      WRD ATT     ; @  (put to stack value at address on the stack top)
      WRD ZLESS   ; 0<  (true if negative number on stack)
      WRD UIF     ; jump to next inline literal if top of stack is nonzero
        WRD URBR3
      WRD DROP    ; DROP  (remove value at stack)
      WRD UELSE   ; jump to next inline literal
        WRD URBR4
URBR3 WRD SWAP    ; SWAP  (swap two values at stack top)
      WRD LITER
URBR4 WRD LITER
      WRD EXITT   ; EXIT  (return from word execution)
URBR5 WRD ULIT    ; push next inline literal
        WRD -13
      WRD THROW
      WRD EXITT   ; EXIT  (return from word execution)

; : ] ( -- ) ( 6.1.2540 ) align ['] _] -1 state 2! ;
; ]		( -- )
;		Start compiling the words in the input stream.

      WRD L192
L193  WRD $01
      TXT "]"
      WRD 0
RBRAC WRD LIST1  ; Process colon list
      WRD ULIT    ; push next inline literal
        WRD URBR
      WRD ULIT    ; push next inline literal
        WRD $FFFF
      WRD STATE
      WRD TSTOR
      WRD EXITT   ; EXIT  (return from word execution)

; 
; create forth-wordlist ( -- wid ) ( 16.6.1.1595 )
;   0 , ( na, of last definition, linked )
;   0 , ( wid|0, next or last wordlist in chain )
;   0 , ( na, wordlist name pointer )
; FORTH-WORDLIST ( -- wid )
      WRD L193
L194  WRD $0E
      TXT "FORTH-WORDLIST"
      WRD 0
FRTHW WRD LIST1  ; Process colon list
      WRD UVAR    ; _VAR  (put to data stack address of next word and exit)
FRTW1 WRD BYE0
      WRD 0
      WRD 0

; 
; create last ( -- a )
;   1 cells allot ( na, of last definition, unlinked )
;   1 cells allot ( wid, current wordlist for linking )
; label =token  / ????
;   1 cells allot ( xt, of last definition )

; LAST	( -- a )
;		Point to the last name in the name dictionary.

      WRD L194
L195  WRD $04
      TXT "LAST"
      WRD 0
LAST  WRD LIST1  ; Process colon list
      WRD UVAR    ; _VAR  (put to data stack address of next word and exit)
      WRD 0
      WRD 0
ERECU WRD 0
EDOES WRD 0
; 
; create current ( -- a )
;   forth-wordlist , ( wid, new definitions )
;   forth-wordlist , ( wid, head of chain )
; CURRENT	( -- a )
;		Point to the vocabulary to be extended.

      WRD L195
L196  WRD $07
      TXT "CURRENT"
      WRD 0
CURRE WRD LIST1  ; Process colon list
      WRD UVAR    ; _VAR  (put to data stack address of next word and exit)
      WRD FRTW1
      WRD FRTW1

; 
; : get-current ( -- wid ) ( 16.6.1.1643 ) current @ ;
; GET-CURRENT ( -- wid )
; Return wid, the identifier of the compilation word list. 
      WRD L196
L197  WRD $0B
      TXT "GET-CURRENT"
      WRD 0
GETCU WRD LIST1  ; Process colon list
      WRD CURRE
      WRD ATT     ; @  (put to stack value at address on the stack top)
      WRD EXITT   ; EXIT  (return from word execution)

; : set-current ( wid -- ) ( 16.6.1.2195 ) current ! ;
; SET-CURRENT ( wid -- ) 
; Set the compilation word list to the word list identified by wid. 
      WRD L197
L198  WRD $0B
      TXT "SET-CURRENT"
      WRD 0
SETCU WRD LIST1  ; Process colon list
      WRD CURRE
      WRD STORE   ; !  (write value at second stack item to address at stack top)
      WRD EXITT   ; EXIT  (return from word execution)
; : definitions ( -- ) ( 16.6.1.1180 ) context @ set-current ;
; DEFINITIONS ( -- )
; Make the compilation word list the same as the first word list in the search order.
      WRD L198
L199  WRD $0B
      TXT "DEFINITIONS"
      WRD 0
DEFIN WRD LIST1  ; Process colon list
      WRD CONTE
      WRD ATT     ; @  (put to stack value at address on the stack top)
      WRD SETCU
      WRD EXITT   ; EXIT  (return from word execution)

; 
; : ?unique ( a u -- a u )
;   2dup  get-current wid?
;   if 2drop cr ." redef " 2dup type exit then 2drop ;
; ?UNIQUE	( a -- a )
;		Display a warning message if the word already exists.

      WRD L199
L200  WRD $07
      TXT "?UNIQUE"
      WRD 0
QUNIQ WRD LIST1  ; Process colon list
      WRD TDUP    ; 2DUP (duplicate top two numbers)
      WRD GETCU
      WRD WIDQ
      WRD UIF     ; jump to next inline literal if top of stack is nonzero
        WRD QUNI1
      WRD TDROP   ; 2DROP remove 2 items from stack
      WRD CR
      WRD UDOTQ
      WRD $06
      TXT "reDef "
      WRD TDUP    ; 2DUP (duplicate top two numbers)
      WRD TYPE
      WRD EXITT   ; EXIT  (return from word execution)
QUNI1 WRD TDROP   ; 2DROP remove 2 items from stack
      WRD EXITT   ; EXIT  (return from word execution)

; 
; : head, ( "name" -- ) \ ???fix ( xt "name" -- )
;   parse-word  dup
;   if ?unique ( warn if redefined )
;     align
;     get-current  dup @ ,  here last 2! ( link )
;     dup c, ( save count )
;     here swap  dup allot  move ( build name )
;     0 c, ( build attribute byte )
;     exit
;   then -16 throw ; ( attempt to use zero-length string )

; HEAD, ( "name" -- ) 
; Create header of colon definition
      WRD L200
L201  WRD $05
      TXT "HEAD,"
      WRD 0
HEADC WRD LIST1  ; Process colon list
      WRD PARSW
      WRD DUP     ; DUP  (duplicate value at stack top)
      WRD UIF     ; jump to next inline literal if top of stack is nonzero
        WRD HEDC1
      WRD QUNIQ
      WRD GETCU
      WRD DUP     ; DUP  (duplicate value at stack top)
      WRD ATT     ; @  (put to stack value at address on the stack top)
      WRD COMMA   ; ,  (compile integer number at stack into code dictionary)
      WRD HERE    ; HERE (return top of code directory)
      WRD LAST
      WRD TSTOR
      WRD DUP     ; DUP  (duplicate value at stack top)
      WRD CCOMA
      WRD HERE    ; HERE (return top of code directory)
      WRD SWAP    ; SWAP  (swap two values at stack top)
      WRD DUP     ; DUP  (duplicate value at stack top)
      WRD ALLOT
      WRD MOVE
      WRD ULIT    ; push next inline literal
        WRD 0
      WRD CCOMA
      WRD EXITT   ; EXIT  (return from word execution)
HEDC1 WRD ULIT    ; push next inline literal
        WRD -16
      WRD THROW
      WRD EXITT   ; EXIT  (return from word execution)
LEXST WRD LIST1  ; Process colon list
      WRD LAST
      WRD ATT     ; @  (put to stack value at address on the stack top)
      WRD COUNT
      WRD PLUS    ; + (add two numbers on stack)
      WRD DUP     ; DUP  (duplicate value at stack top)
      WRD TOR     ; >R  (push data stack to return stack)
      WRD CAT     ; C@ (read byte from address at stack top ))
      WRD ORR     ; OR  (bitwise OR between two numbers on stack)
      WRD RFROM   ; R> (pop return stack to  data stack)
      WRD CSTOR   ; C!  (write byte at second stack item to address at stack top)
      WRD EXITT   ; EXIT  (return from word execution)

; 
; | : lex! ( u -- ) last @ count chars + dup >r c@ or r> c! ;
; : immediate ( -- ) ( 6.1.1710 ) [ =imed ] literal  lex! ;
; IMMEDIATE	( -- )
;		Make the last compiled word an immediate word.

      WRD L201
L202  WRD $09
      TXT "IMMEDIATE"
      WRD 0
IMMED WRD LIST1  ; Process colon list
      WRD ULIT    ; push next inline literal
        WRD EIMED
      WRD LEXST
      WRD EXITT   ; EXIT  (return from word execution)

; : compile-only ( -- ) [ =comp ] literal  lex! ;
; COMPILE-ONLY	( -- )
;		Make the last compiled word a compile only word.

      WRD L202
L203  WRD $0C
      TXT "COMPILE-ONLY"
      WRD 0
COMPO WRD LIST1  ; Process colon list
      WRD ULIT    ; push next inline literal
        WRD ECOMP
      WRD LEXST
      WRD EXITT   ; EXIT  (return from word execution)

; 
; : reveal ( -- ) last 2@ swap ! [ ' [ compile, ] ;
; REVEAL ( -- )
      WRD L203
L204  WRD $06
      TXT "REVEAL"
      WRD 0
REVEA WRD LIST1  ; Process colon list
      WRD LAST
      WRD TAT
      WRD SWAP    ; SWAP  (swap two values at stack top)
      WRD STORE   ; !  (write value at second stack item to address at stack top)
      WRD LBRAC
      WRD EXITT   ; EXIT  (return from word execution)

; : recurse ( -- ) ( 6.1.2120 ) [ =token ] literal @ compile, ; immediate
; RECURSE	( -- )
;		Make the current word available for compilation.

      WRD L204
L205  WRD $07
      TXT "RECURSE"
      WRD EIMED
RECUR WRD LIST1  ; Process colon list
      WRD ULIT    ; push next inline literal
        WRD ERECU
      WRD ATT     ; @  (put to stack value at address on the stack top)
      WRD COMPC
      WRD EXITT   ; EXIT  (return from word execution)

; 
; : postpone ( "name" -- ) ( 6.1.2033 )
;   parse-word sfind
;   if [ =imed ] literal and if compile, exit then
;     [ ' literal compile, ]  ['] compile, compile,  exit
;   then -13 throw ; immediate
; POSTPONE ( "<spaces>name" -- )
; Skip leading space delimiters. Parse name delimited by a space. Find name. Append the compilation semantics of name to the current definition. An ambiguous condition exists if name is not found. 
      WRD L205
L206  WRD $08
      TXT "POSTPONE"
      WRD EIMED
POSTP WRD LIST1  ; Process colon list
      WRD PARSW
      WRD SFIND
      WRD UIF     ; jump to next inline literal if top of stack is nonzero
        WRD PSTP2
      WRD ULIT    ; push next inline literal
        WRD EIMED
      WRD ANDD    ; AND  (bitwise AND between two numbers on stack)
      WRD UIF     ; jump to next inline literal if top of stack is nonzero
        WRD PSTP1
      WRD COMPC
      WRD EXITT   ; EXIT  (return from word execution)
PSTP1 WRD LITER
      WRD ULIT    ; push next inline literal
        WRD COMPC
      WRD COMPC
      WRD EXITT   ; EXIT  (return from word execution)
PSTP2 WRD ULIT    ; push next inline literal
        WRD -13
      WRD THROW
      WRD EXITT   ; EXIT  (return from word execution)

; 
; ( defining words )
; 
; : code ( "name" -- ) ( 15.6.2.0930 ) \ itc
;   head, align here cell+ , reveal ;
; 
; CODE  ( "<spaces>name" -- )
; Skip leading space delimiters. Parse name delimited by a space. Create a definition for name, called a "code definition", with the execution semantics defined below. 
; name Execution: ( i * x -- j * x )
; Execute the machine code sequence that was generated following CODE. 
      WRD L206
L207  WRD $04
      TXT "CODE"
      WRD 0
CODE  WRD LIST1  ; Process colon list
      WRD HEADC
      WRD HERE    ; HERE (return top of code directory)
      WRD CELLP   ; CELL+ (Increment address at top by 1 cell size)
      WRD COMMA   ; ,  (compile integer number at stack into code dictionary)
      WRD REVEA
      WRD EXITT   ; EXIT  (return from word execution)

; : next, ( -- ) \ itc 80x86 only
;   [ next1 ] literal  h# e9 c,  here 2 + - , ;
; next, ( -- ) 
; Generate jump to next
      WRD L207
L208  WRD $05
      TXT "next,"
      WRD 0
NEXTC WRD LIST1  ; Process colon list
      WRD ULIT    ; push next inline literal
        WRD JPNX1
      WRD COMMA   ; ,  (compile integer number at stack into code dictionary)
      WRD EXITT   ; EXIT  (return from word execution)

; 
; : :noname ( -- xt ) ( 6.2.0455 ) \ itc
;   align here  dup [ =token ] literal !  [ list1 ] literal , ] ;

; :noname     ( -- xt )
; Create anonymous word This leaves the execution token for the word on the stack after the closing ;.

      WRD L208
L209  WRD $07
      TXT ":NONAME"
      WRD 0
CNONA WRD LIST1  ; Process colon list
      WRD HERE    ; HERE (return top of code directory)
      WRD DUP     ; DUP  (duplicate value at stack top)
      WRD ULIT    ; push next inline literal
        WRD ERECU
      WRD STORE   ; !  (write value at second stack item to address at stack top)
      WRD ULIT    ; push next inline literal
        WRD LIST1  ; pointer to colon word entry
      WRD COMMA   ; ,  (compile integer number at stack into code dictionary)
      WRD RBRAC
      WRD EXITT   ; EXIT  (return from word execution)

; 
; : : ( "name" -- ) ( 6.1.0450 ) head, :noname drop ;
; :		( -- ; <string> )
;		Start a new colon definition using next word as its name.

      WRD L209
L210  WRD $01
      TXT ":"
      WRD 0
COLON WRD LIST1  ; Process colon list
      WRD HEADC   ; HEAD, (create header of comon definition)
      WRD CNONA   ; :NONAME (create anonymous word)
      WRD DROP    ; DROP  (remove value at stack)
      WRD EXITT   ; EXIT  (return from word execution)

; : ; ( -- ) ( 6.1.0460 ) ['] exit compile, reveal ; immediate compile-only
; ;		( -- )
;		Terminate a colon definition.

      WRD L210
L211  WRD $01
      WRD 59     ; ";"
      WRD EIMCO
SEMIC WRD LIST1  ; Process colon list
      WRD ULIT    ; push next inline literal
        WRD EXITT   ; EXIT  (return from word execution)
      WRD COMPC
      WRD REVEA
      WRD EXITT   ; EXIT  (return from word execution)

; 
; : _does> ( -- ) ( link child )
; \  align ( child ) \ ???why
;   r>  [ =token ] literal @  cell+ ( itc )  ! ; compile-only
; _DOES>
      WRD L211
L212  WRD $06
      TXT "_DOES>"
      WRD ECOMP
UDOES WRD LIST1  ; Process colon list
      WRD RFROM   ; R> (pop return stack to  data stack)
      WRD ULIT    ; push next inline literal
        WRD EDOES
      WRD ATT     ; @  (put to stack value at address on the stack top)
      WRD STORE   ; !  (write value at second stack item to address at stack top)
      WRD EXITT   ; EXIT  (return from word execution)

; 
; : does> ( -- ) ( 6.1.1250 ) ( build parent )
;   ['] _does> compile, ( link child )
;   :noname drop  ['] r> compile, ( begin child )
; ; immediate compile-only

; DOES>
;Compilation: ( C: colon-sys1 -- colon-sys2 )
; Append the run-time semantics below to the current definition. Whether or not the current definition is rendered findable in the dictionary by the compilation of DOES> is implementation defined. Consume colon-sys1 and produce colon-sys2. Append the initiation semantics given below to the current definition.
;Run-time: ( -- ) ( R: nest-sys1 -- )
; Replace the execution semantics of the most recent definition, referred to as name, with the name execution semantics given below. Return control to the calling definition specified by nest-sys1. An ambiguous condition exists if name was not defined with CREATE or a user-defined word that calls CREATE.
; Initiation: ( i*x -- i*x a-addr ) ( R:  -- nest-sys2 )
; Save implementation-dependent information nest-sys2 about the calling definition. Place name's data field address on the stack. The stack effects i*x represent arguments to name.
; name Execution: ( i*x -- j*x )
; Execute the portion of the definition that begins with the initiation semantics appended by the DOES> which modified name. The stack effects i*x and j*x represent arguments to and results from name, respectively. 

      WRD L212
L213  WRD $05
      TXT "DOES>"
      WRD EIMCO
DOES  WRD LIST1  ; Process colon list
      WRD ULIT    ; push next inline literal
        WRD UDOES
      WRD COMPC
      WRD CNONA
      WRD DROP    ; DROP  (remove value at stack)
      WRD ULIT    ; push next inline literal
        WRD RFROM   ; R> (pop return stack to  data stack)
      WRD COMPC
      WRD EXITT   ; EXIT  (return from word execution)

; 
; : create ( "name" -- ) ( 6.1.1000 ) ['] _var  : reveal compile, ;
; CREATE	( "<spaces>name" -- )
; Skip leading space delimiters. Parse name delimited by a space. 
; Create a definition for name with the execution semantics defined below. 
; If the data-space pointer is not aligned, reserve enough data space to align it. 
; The new data-space pointer defines name's data field. CREATE does not allocate data space in name's data field.
;	name Execution: ( -- a-addr )
; a-addr is the address of name's data field. The execution semantics of name may be extended by using DOES>. 
      WRD L213
L214  WRD $06
      TXT "CREATE"
      WRD 0
CREAT WRD LIST1  ; Process colon list
      WRD ULIT    ; push next inline literal
        WRD UVAR    ; _VAR  (put to data stack address of next word and exit)
      WRD COLON
      WRD REVEA
      WRD HERE    ; HERE (return top of code directory)
      WRD ULIT    ; push next inline literal
        WRD EDOES
      WRD STORE   ; !  (write value at second stack item to address at stack top)
      WRD COMPC
      WRD EXITT   ; EXIT  (return from word execution)

; : variable ( "name" -- ) ( 6.1.2410 ) create 0 , ;
; VARIABLE	( -- ; <string> )
;		Compile a new variable initialized to 0.

      WRD L214
L215  WRD $08
      TXT "VARIABLE"
      WRD 0
VARIA WRD LIST1  ; Process colon list
      WRD CREAT   ; CREATE (create definition for name)
      WRD ULIT    ; push next inline literal
        WRD 0
      WRD COMMA   ; ,  (compile integer number at stack into code dictionary)
      WRD EXITT   ; EXIT  (return from word execution)
; : constant ( n "name" -- ) ( 6.1.0950 ) ['] _con  : reveal compile,  , ;
; CONSTANT	( x -- ; <string> )
;		Compile a new constant.

      WRD L215
L216  WRD $08
      TXT "CONSTANT"
      WRD 0
CONST WRD LIST1  ; Process colon list
      WRD ULIT    ; push next inline literal
        WRD UCON    ; _CON (get immediate constant after IP and exit)
      WRD COLON
      WRD REVEA
      WRD COMPC
      WRD COMMA   ; ,  (compile integer number at stack into code dictionary)
      WRD EXITT   ; EXIT  (return from word execution)
; 
; : user ( n "name" -- ) ['] _usr  : reveal compile,  , ;
; USER	( u -- ; <string> )
;		Compile a new user variable.

      WRD L216
L217  WRD $04
      TXT "USER"
      WRD 0
USER  WRD LIST1  ; Process colon list
      WRD ULIT    ; push next inline literal
        WRD UUSR
      WRD COLON
      WRD REVEA
      WRD COMPC
      WRD COMMA   ; ,  (compile integer number at stack into code dictionary)
      WRD EXITT   ; EXIT  (return from word execution)
; 
; : hat ( u s r "name" -- ) ( -- tid )
;   create + swap [ 7 cells ] literal + ( tf\tid\tos\status\follower\r>--<s )
;   dup here + ( rp0 ) , + dup here + ( sp0 ) , allot ;

; HAT ( u s r "name" -- ) ( -- tid )
      WRD L217
L218  WRD $03
      TXT "HAT"
      WRD 0
HAT   WRD LIST1  ; Process colon list
      WRD CREAT   ; CREATE (create definition for name)
      WRD ROT     ; ROT  (rotate three numbers at stack top)
      WRD ULIT    ; push next inline literal
        WRD 8     ; Needs be 8*CELL1
      WRD PLUS    ; + (add two numbers on stack)
      WRD HERE    ; HERE (return top of code directory)
      WRD PLUS    ; + (add two numbers on stack)
      WRD DUP     ; DUP  (duplicate value at stack top)
      WRD COMMA   ; ,  (compile integer number at stack into code dictionary)
      WRD PLUS    ; + (add two numbers on stack)
      WRD DUP     ; DUP  (duplicate value at stack top)
      WRD COMMA   ; ,  (compile integer number at stack into code dictionary)
      WRD PLUS    ; + (add two numbers on stack)
      WRD DUP     ; DUP  (duplicate value at stack top)
      WRD COMMA   ; ,  (compile integer number at stack into code dictionary)
      WRD HERE    ; HERE (return top of code directory)
      WRD MINUS   ; -  (subtract numbers at stack top)
      WRD ALLOT
      WRD EXITT   ; EXIT  (return from word execution)

; 
; : wordlist ( -- wid ) ( 16.6.1.2460 )
;   align here 0 ,  dup current cell+  dup @ ,  !  0 , ;
; WORDLIST	( -- wid )
; Create a new empty word list, returning its word list identifier wid.
      WRD L218
L219  WRD $08
      TXT "WORDLIST"
      WRD 0
WORDL WRD LIST1  ; Process colon list
      WRD HERE    ; HERE (return top of code directory)
      WRD ULIT    ; push next inline literal
        WRD 0
      WRD COMMA   ; ,  (compile integer number at stack into code dictionary)
      WRD DUP     ; DUP  (duplicate value at stack top)
      WRD CURRE
      WRD CELLP   ; CELL+ (Increment address at top by 1 cell size)
      WRD DUP     ; DUP  (duplicate value at stack top)
      WRD ATT     ; @  (put to stack value at address on the stack top)
      WRD COMMA   ; ,  (compile integer number at stack into code dictionary)
      WRD STORE   ; !  (write value at second stack item to address at stack top)
      WRD ULIT    ; push next inline literal
        WRD 0
      WRD COMMA   ; ,  (compile integer number at stack into code dictionary)
      WRD EXITT   ; EXIT  (return from word execution)
; 
; : order@ ( a -- u*wid u )
;   dup @ dup if >r cell+  recurse  r> swap 1 + exit then nip ;
      WRD L219
L220  WRD $06
      TXT "ORDER@"
      WRD 0
ORDAT WRD LIST1  ; Process colon list
      WRD DUP     ; DUP  (duplicate value at stack top)
      WRD ATT     ; @  (put to stack value at address on the stack top)
      WRD DUP     ; DUP  (duplicate value at stack top)
      WRD UIF     ; jump to next inline literal if top of stack is nonzero
        WRD ORDA1
      WRD TOR     ; >R  (push data stack to return stack)
      WRD CELLP   ; CELL+ (Increment address at top by 1 cell size)
      WRD ORDAT
      WRD RFROM   ; R> (pop return stack to  data stack)
      WRD SWAP    ; SWAP  (swap two values at stack top)
      WRD ULIT    ; push next inline literal
        WRD $01
      WRD PLUS    ; + (add two numbers on stack)
      WRD EXITT   ; EXIT  (return from word execution)
ORDA1 WRD NIP     ; NIP (remove 2nd item from stack)
      WRD EXITT   ; EXIT  (return from word execution)

; : get-order ( -- u*wid u ) ( 16.6.1.1647 ) context order@ ;

; GET-ORDER ( -- widn ... wid1 n )
; Returns the number of word lists n in the search order and the word list identifiers widn ... wid1 identifying these word lists. wid1 identifies the word list that is searched first, and widn the word list that is searched last. 
      WRD L220
L221  WRD $09
      TXT "GET-ORDER"
      WRD 0
GETOR WRD LIST1  ; Process colon list
      WRD CONTE
      WRD ORDAT
      WRD EXITT   ; EXIT  (return from word execution)

; 
; : set-order ( u*wid n -- ) ( 16.6.1.2197 )
;   dup -1 = if drop forth-wordlist 1 then ( default ? )
;   [ #vocs ] literal over u< if -46 throw then ( range ? )
;   context swap
;   begin dup
;   while >r  swap over !  cell+  r> 1 -
;   repeat  ( 0 ) swap ! ;
; SET-ORDER	( widn ... wid1 n -- )
; Set the search order to the word lists identified by widn ... wid1. Subsequently, word list wid1 will be searched first, and word list widn searched last. 
      WRD L221
L222  WRD $09
      TXT "SET-ORDER"
      WRD 0
SETOR WRD LIST1  ; Process colon list
      WRD DUP     ; DUP  (duplicate value at stack top)
      WRD ULIT    ; push next inline literal
        WRD -1
      WRD EQUAL
      WRD UIF     ; jump to next inline literal if top of stack is nonzero
        WRD SETO1
      WRD DROP    ; DROP  (remove value at stack)
      WRD FRTHW
      WRD ULIT    ; push next inline literal
        WRD $01
SETO1 WRD ULIT    ; push next inline literal
        WRD NVOCS
      WRD OVER    ; OVER  (copy second value at stack to stack top)
      WRD ULESS   ; U<  (is second on stack unsigned less than top on stack)
      WRD UIF     ; jump to next inline literal if top of stack is nonzero
        WRD SETO2
      WRD ULIT    ; push next inline literal
        WRD -46
      WRD THROW
SETO2 WRD CONTE
      WRD SWAP    ; SWAP  (swap two values at stack top)
SETO3 WRD DUP     ; DUP  (duplicate value at stack top)
      WRD UIF     ; jump to next inline literal if top of stack is nonzero
        WRD SETO4
      WRD TOR     ; >R  (push data stack to return stack)
      WRD SWAP    ; SWAP  (swap two values at stack top)
      WRD OVER    ; OVER  (copy second value at stack to stack top)
      WRD STORE   ; !  (write value at second stack item to address at stack top)
      WRD CELLP   ; CELL+ (Increment address at top by 1 cell size)
      WRD RFROM   ; R> (pop return stack to  data stack)
      WRD ULIT    ; push next inline literal
        WRD $01
      WRD MINUS   ; -  (subtract numbers at stack top)
      WRD UELSE   ; jump to next inline literal
        WRD SETO3
SETO4 WRD SWAP    ; SWAP  (swap two values at stack top)
      WRD STORE   ; !  (write value at second stack item to address at stack top)
      WRD EXITT   ; EXIT  (return from word execution)

;  (marker)
; : _marker ( -- ) ( r: dfa -- ) \ ???
;   r> 2@ ( * ) dup @ follower !  dup context
;   begin >r cell+ dup @ dup r@ ! while r> cell+ repeat ( search order )
;   cell+ dup 2@ current 2!  cell+ dup @ ( cur wid & head )
;   begin >r  cell+ dup @ r@ !  r> cell+ @ ?dup 0= until ( wid last na's )
;   r> 2drop ( * ) dp 2! ; compile-only
; _MARKER ( -- ) ( R: dfa -- )
      WRD L222
L223  WRD $07
      TXT "_MARKER"
      WRD ECOMP
UMARK WRD LIST1  ; Process colon list
      WRD RFROM   ; R> (pop return stack to  data stack)
      WRD TAT
      WRD DUP     ; DUP  (duplicate value at stack top)
      WRD ATT     ; @  (put to stack value at address on the stack top)
      WRD FOLLO   ; FOLLOWER ( address of next task's STATUS )
      WRD STORE   ; !  (write value at second stack item to address at stack top)
      WRD DUP     ; DUP  (duplicate value at stack top)
      WRD CONTE
UMAR1 WRD TOR     ; >R  (push data stack to return stack)
      WRD CELLP   ; CELL+ (Increment address at top by 1 cell size)
      WRD DUP     ; DUP  (duplicate value at stack top)
      WRD ATT     ; @  (put to stack value at address on the stack top)
      WRD DUP     ; DUP  (duplicate value at stack top)
      WRD RAT     ; R@ (copy top of return stack to  data stack)
      WRD STORE   ; !  (write value at second stack item to address at stack top)
      WRD UIF     ; jump to next inline literal if top of stack is nonzero
        WRD UMAR2
      WRD RFROM   ; R> (pop return stack to  data stack)
      WRD CELLP   ; CELL+ (Increment address at top by 1 cell size)
      WRD UELSE   ; jump to next inline literal
        WRD UMAR1
UMAR2 WRD CELLP   ; CELL+ (Increment address at top by 1 cell size)
      WRD DUP     ; DUP  (duplicate value at stack top)
      WRD TAT
      WRD CURRE
      WRD TSTOR
      WRD CELLP   ; CELL+ (Increment address at top by 1 cell size)
      WRD DUP     ; DUP  (duplicate value at stack top)
      WRD ATT     ; @  (put to stack value at address on the stack top)
UMAR3 WRD TOR     ; >R  (push data stack to return stack)
      WRD CELLP   ; CELL+ (Increment address at top by 1 cell size)
      WRD DUP     ; DUP  (duplicate value at stack top)
      WRD ATT     ; @  (put to stack value at address on the stack top)
      WRD RAT     ; R@ (copy top of return stack to  data stack)
      WRD STORE   ; !  (write value at second stack item to address at stack top)
      WRD RFROM   ; R> (pop return stack to  data stack)
      WRD CELLP   ; CELL+ (Increment address at top by 1 cell size)
      WRD ATT     ; @  (put to stack value at address on the stack top)
      WRD QDUP    ; ?DUP (duplicate number on stack top if it is not zero)
      WRD ZEQ     ; 0= (is number equal zero)
      WRD UIF     ; jump to next inline literal if top of stack is nonzero
        WRD UMAR3
      WRD RFROM   ; R> (pop return stack to  data stack)
      WRD TDROP   ; 2DROP remove 2 items from stack
      WRD DP
      WRD TSTOR
      WRD EXITT   ; EXIT  (return from word execution)

; 
; : marker ( "name" -- ) \ ???
;   align dp 2@ ( * ) follower @ ,  context
;   begin dup @ dup , while cell+ repeat  drop ( search order )
;   current 2@ , dup , ( cur wid & head )
;   begin dup @ , cell+ @ ?dup 0= until ( wid last na's )
;   ['] _marker : reveal compile, ( * ) , , ;
; MARKER ( "name" -- )
      WRD L223
L224  WRD $06
      TXT "MARKER"
      WRD 0
MARKE WRD LIST1  ; Process colon list
      WRD DP
      WRD TAT
      WRD FOLLO   ; FOLLOWER ( address of next task's STATUS )
      WRD ATT     ; @  (put to stack value at address on the stack top)
      WRD COMMA   ; ,  (compile integer number at stack into code dictionary)
      WRD CONTE
MARK1 WRD DUP     ; DUP  (duplicate value at stack top)
      WRD ATT     ; @  (put to stack value at address on the stack top)
      WRD DUP     ; DUP  (duplicate value at stack top)
      WRD COMMA   ; ,  (compile integer number at stack into code dictionary)
      WRD UIF     ; jump to next inline literal if top of stack is nonzero
        WRD MARK2
      WRD CELLP   ; CELL+ (Increment address at top by 1 cell size)
      WRD UELSE   ; jump to next inline literal
        WRD MARK1
MARK2 WRD DROP    ; DROP  (remove value at stack)
      WRD CURRE
      WRD TAT
      WRD COMMA   ; ,  (compile integer number at stack into code dictionary)
      WRD DUP     ; DUP  (duplicate value at stack top)
      WRD COMMA   ; ,  (compile integer number at stack into code dictionary)
MARK3 WRD DUP     ; DUP  (duplicate value at stack top)
      WRD ATT     ; @  (put to stack value at address on the stack top)
      WRD COMMA   ; ,  (compile integer number at stack into code dictionary)
      WRD CELLP   ; CELL+ (Increment address at top by 1 cell size)
      WRD ATT     ; @  (put to stack value at address on the stack top)
      WRD QDUP    ; ?DUP (duplicate number on stack top if it is not zero)
      WRD ZEQ     ; 0= (is number equal zero)
      WRD UIF     ; jump to next inline literal if top of stack is nonzero
        WRD MARK3
      WRD ULIT    ; push next inline literal
        WRD UMARK
      WRD COLON
      WRD REVEA
      WRD COMPC
      WRD COMMA   ; ,  (compile integer number at stack into code dictionary)
      WRD COMMA   ; ,  (compile integer number at stack into code dictionary)
      WRD EXITT   ; EXIT  (return from word execution)

; ( control flow )
; 
; : begin ( -- a ) ( 6.1.0760 ) here ; immediate
; BEGIN	( -- a )
;		Start an infinite or indefinite loop structure.

      WRD L224
L225  WRD $05
      TXT "BEGIN"
      WRD EIMED
BEGIN WRD LIST1  ; Process colon list
      WRD HERE    ; HERE (return top of code directory)
      WRD EXITT   ; EXIT  (return from word execution)

; : then ( a -- ) ( 6.1.2270 ) [ ' begin compile, ] ( over - ) swap ! ; immediate
; THEN	( A -- )
;		Terminate a conditional branch structure.

      WRD L225
L226  WRD $04
      TXT "THEN"
      WRD EIMED
THEN  WRD LIST1  ; Process colon list
      WRD BEGIN
      WRD SWAP    ; SWAP  (swap two values at stack top)
      WRD STORE   ; !  (write value at second stack item to address at stack top)
      WRD EXITT   ; EXIT  (return from word execution)

; 
; : resolve ( a -- ) ( [ ' begin compile, ] - ) , ;
; RESOLVE ( a -- )
      WRD L226
L227  WRD $07
      TXT "RESOLVE"
      WRD 0
RESOL WRD LIST1  ; Process colon list
      WRD COMMA   ; ,  (compile integer number at stack into code dictionary)
      WRD EXITT   ; EXIT  (return from word execution)

; : mark ( -- a ) here [ ' begin compile, ] resolve ;
; MARK ( -- a )
      WRD L227
L228  WRD $04
      TXT "MARK"
      WRD 0
MARK  WRD LIST1  ; Process colon list
      WRD HERE    ; HERE (return top of code directory)
      WRD BEGIN
      WRD RESOL
      WRD EXITT   ; EXIT  (return from word execution)

; 
; : if ( -- a ) ( 6.1.1700 ) ['] _if compile, mark ; immediate
; IF		( -- A )
;		Begin a conditional branch structure.

      WRD L228
L229  WRD $02
      TXT "IF"
      WRD EIMED
IFF   WRD LIST1  ; Process colon list
      WRD ULIT    ; push next inline literal
        WRD UIF     ; jump to next inline literal if top of stack is nonzero
      WRD COMPC
      WRD MARK
      WRD EXITT   ; EXIT  (return from word execution)

; : ahead ( -- a ) ( 15.6.2.0702 ) ['] _else compile, mark ; immediate
; AHEAD	( -- A )
;		Compile a forward branch instruction.

      WRD L229
L230  WRD $05
      TXT "AHEAD"
      WRD EIMED
AHEAD WRD LIST1  ; Process colon list
      WRD ULIT    ; push next inline literal
        WRD UELSE   ; jump to next inline literal
      WRD COMPC
      WRD MARK
      WRD EXITT   ; EXIT  (return from word execution)
; : else ( a -- a ) ( 6.1.1310 ) [ ' ahead compile, ] swap [ ' then compile, ] ; immediate
; ELSE	( A -- A )
;		Start the false clause in an IF-ELSE-THEN structure.

      WRD L230
L231  WRD $04
      TXT "ELSE"
      WRD EIMED
ELSEE WRD LIST1  ; Process colon list
      WRD AHEAD
      WRD SWAP    ; SWAP  (swap two values at stack top)
      WRD THEN
      WRD EXITT   ; EXIT  (return from word execution)

; : while ( a -- a a ) ( 6.1.2430 ) [ ' if compile, ] swap ; immediate
; WHILE	( a -- A a )
;		Conditional branch out of a BEGIN-WHILE-REPEAT loop.

      WRD L231
L232  WRD $05
      TXT "WHILE"
      WRD EIMED
WHIL  WRD LIST1  ; Process colon list
      WRD IFF
      WRD SWAP    ; SWAP  (swap two values at stack top)
      WRD EXITT   ; EXIT  (return from word execution)
; 
; : until ( a -- ) ( 6.1.2390 ) ['] _if compile, resolve ; immediate
; UNTIL	( a -- )
;		Terminate a BEGIN-UNTIL indefinite loop structure.

      WRD L232
L233  WRD $05
      TXT "UNTIL"
      WRD EIMED
UNTL  WRD LIST1  ; Process colon list
      WRD ULIT    ; push next inline literal
        WRD UIF     ; jump to next inline literal if top of stack is nonzero
      WRD COMPC
      WRD RESOL
      WRD EXITT   ; EXIT  (return from word execution)

; : again ( a -- ) ( 6.2.0700 ) ['] _else compile, resolve ; immediate
; AGAIN	( a -- )
;		Terminate a BEGIN-AGAIN infinite loop structure.

      WRD L233
L234  WRD $05
      TXT "AGAIN"
      WRD EIMED
AGAIN WRD LIST1  ; Process colon list
      WRD ULIT    ; push next inline literal
        WRD UELSE   ; jump to next inline literal
      WRD COMPC
      WRD RESOL
      WRD EXITT   ; EXIT  (return from word execution)

; : repeat ( a a -- ) ( 6.1.2140 ) [ ' again compile, ' then compile, ] ; immediate
; REPEAT	( A a -- )
;		Terminate a BEGIN-WHILE-REPEAT indefinite loop.

      WRD L234
L235  WRD $06
      TXT "REPEAT"
      WRD EIMED
REPEA WRD LIST1  ; Process colon list
      WRD AGAIN
      WRD THEN
      WRD EXITT   ; EXIT  (return from word execution)

; 
; ( tools )
; 
; : .s ( -- ) ( 15.6.1.0220 )( 0x9f )
;   ?stack depth begin ?dup while dup pick . 1 - repeat ;
; .S		( ... -- ... )
;		Display the contents of the data stack.

      WRD L235
L236  WRD $02
      TXT ".S"
      WRD 0
DOTS  WRD LIST1  ; Process colon list
      WRD QSTAC
      WRD DEPTH
DOTS1 WRD QDUP    ; ?DUP (duplicate number on stack top if it is not zero)
      WRD UIF     ; jump to next inline literal if top of stack is nonzero
        WRD DOTS2
      WRD DUP     ; DUP  (duplicate value at stack top)
      WRD PICK
      WRD DOT
      WRD ULIT    ; push next inline literal
        WRD $01
      WRD MINUS   ; -  (subtract numbers at stack top)
      WRD UELSE   ; jump to next inline literal
        WRD DOTS1
DOTS2 WRD EXITT   ; EXIT  (return from word execution)

; 
; : !csp ( -- ) sp@ csp ! ;
; !CSP	( -- )
;		Save stack pointer in CSP for error checking.

      WRD L236
L237  WRD $04
      TXT "!CSP"
      WRD 0
STCSP WRD LIST1  ; Process colon list
      WRD SPAT
      WRD CSP
      WRD STORE   ; !  (write value at second stack item to address at stack top)
      WRD EXITT   ; EXIT  (return from word execution)
; : ?csp ( -- ) sp@ csp @ xor abort" csp?" ;
; ?CSP	( -- )
;		Abort if stack pointer differs from that saved in CSP.

      WRD L237
L238  WRD $04
      TXT "?CSP"
      WRD 0
QCSP  WRD LIST1  ; Process colon list
      WRD SPAT
      WRD CSP
      WRD ATT     ; @  (put to stack value at address on the stack top)
      WRD XORR    ; XOR  (bitwise XOR between two numbers on stack)
      WRD UABOR
      WRD $04
      TXT "csp?"
      WRD EXITT   ; EXIT  (return from word execution)

; 
; : >char ( c -- c )
;   h# 7f and dup 127 bl within if drop [char] _ then ;
; >CHAR	( c -- c )
;		Filter non-printing characters.

      WRD L238
L239  WRD $05
      TXT ">CHAR"
      WRD 0
TCHAR WRD LIST1  ; Process colon list
      WRD ULIT    ; push next inline literal
        WRD $7F
      WRD ANDD    ; AND  (bitwise AND between two numbers on stack)
      WRD DUP     ; DUP  (duplicate value at stack top)
      WRD ULIT    ; push next inline literal
        WRD $7F
      WRD BLL
      WRD WITHI
      WRD UIF     ; jump to next inline literal if top of stack is nonzero
        WRD TCHR1
      WRD DROP    ; DROP  (remove value at stack)
      WRD ULIT    ; push next inline literal
        TXT "_"
TCHR1 WRD EXITT   ; EXIT  (return from word execution)

; 
; : _type ( a u -- ) ( alpha dump )
;   chars bounds begin 2dup xor while count >char emit repeat 2drop ;
; _TYPE	( b u -- )
;		Display a string. Filter non-printing characters.

      WRD L239
L240  WRD $05
      TXT "_TYPE"
      WRD 0
UTYPE WRD LIST1  ; Process colon list
      WRD BNDS    ; BOUNDS (From addr and length, produce  addr+u and the start address)
UTYP1 WRD TDUP    ; 2DUP (duplicate top two numbers)
      WRD XORR    ; XOR  (bitwise XOR between two numbers on stack)
      WRD UIF     ; jump to next inline literal if top of stack is nonzero
        WRD UTYP2
      WRD COUNT
      WRD TCHAR
      WRD EMIT
      WRD UELSE   ; jump to next inline literal
        WRD UTYP1
UTYP2 WRD TDROP   ; 2DROP remove 2 items from stack
      WRD EXITT   ; EXIT  (return from word execution)

; 
; : _dump ( a u -- ) ( numeric dump )
;   chars bounds begin 2dup xor while count 3 u.r repeat 2drop ;
; _DUMP	( a u -- )
;		Numeric dump range of bytes.

      WRD L240
L241  WRD $05
      TXT "_DUMP"
      WRD 0
UDUMP WRD LIST1  ; Process colon list
      WRD BNDS    ; BOUNDS (From addr and length, produce  addr+u and the start address)
UDMP1 WRD TDUP    ; 2DUP (duplicate top two numbers)
      WRD XORR    ; XOR  (bitwise XOR between two numbers on stack)
      WRD UIF     ; jump to next inline literal if top of stack is nonzero
        WRD UDMP2
      WRD COUNT
      WRD ULIT    ; push next inline literal
        WRD $05   ; width of column
      WRD UDOTR
      WRD UELSE   ; jump to next inline literal
        WRD UDMP1
UDMP2 WRD TDROP   ; 2DROP remove 2 items from stack
      WRD EXITT   ; EXIT  (return from word execution)

; 
; : dump ( a u -- ) ( 15.6.1.1280 )
;   base @ >r hex  chars bounds
;   begin 2dup swap u< while ( range? )
;     cr dup 0 <#  # # # #  #> type ( address )
;     space [ #dump ] literal  2dup _dump ( numeric )
;     space space  2dup _type ( alpha )
;     chars +  nuf? ( user? )
;   until then 2drop  r> base ! ;
; DUMP	( a u -- )
;		Dump u bytes from a, in a formatted manner.

      WRD L241
L242  WRD $04
      TXT "DUMP"
      WRD 0
DUMP  WRD LIST1  ; Process colon list
      WRD BASE    ; BASE (return address of variable pointing number base system)
      WRD ATT     ; @  (put to stack value at address on the stack top)
      WRD TOR     ; >R  (push data stack to return stack)
      WRD HEXX
      WRD BNDS    ; BOUNDS (From addr and length, produce  addr+u and the start address)
DUMP1 WRD TDUP    ; 2DUP (duplicate top two numbers)
      WRD SWAP    ; SWAP  (swap two values at stack top)
      WRD ULESS   ; U<  (is second on stack unsigned less than top on stack)
      WRD UIF     ; jump to next inline literal if top of stack is nonzero
        WRD DUMP2
      WRD CR
      WRD DUP     ; DUP  (duplicate value at stack top)
      WRD ULIT    ; push next inline literal
        WRD 0
      WRD BDIGS
      WRD NDIG
      WRD NDIG
      WRD NDIG
      WRD NDIG
      WRD EDIGS
      WRD TYPE
      WRD SPACE
      WRD ULIT    ; push next inline literal
        WRD NDUMP
      WRD TDUP    ; 2DUP (duplicate top two numbers)
      WRD UDUMP
      WRD SPACE
      WRD SPACE
      WRD TDUP    ; 2DUP (duplicate top two numbers)
      WRD UTYPE
      WRD PLUS    ; + (add two numbers on stack)
      WRD NUFQ
      WRD UIF     ; jump to next inline literal if top of stack is nonzero
        WRD DUMP1
DUMP2 WRD TDROP   ; 2DROP remove 2 items from stack
      WRD RFROM   ; R> (pop return stack to  data stack)
      WRD BASE    ; BASE (return address of variable pointing number base system)
      WRD STORE   ; !  (write value at second stack item to address at stack top)
      WRD EXITT   ; EXIT  (return from word execution)
; 
; : .id ( a -- ) count _type ;

      WRD L242
L243  WRD $03
      TXT ".ID"
      WRD 0
DOTID WRD LIST1  ; Process colon list
      WRD COUNT
      WRD UTYPE
      WRD EXITT   ; EXIT  (return from word execution)

; 
; : widwords ( a u wid -- a u )
;   swap >r  dup
;   if cr dup ." wid=" u. cr
;     begin @ dup ( last name ? )
;     while 2dup char+ r@ same? ( match ? )
;       if dup .id space then cell-  nuf?
;     until then
;   then drop r> ;

;  WIDWORDS ( a u wid -- a u )
      WRD L243
L244  WRD $08
      TXT "WIDWORDS"
      WRD 0
WIDWO WRD LIST1  ; Process colon list
      WRD SWAP    ; SWAP  (swap two values at stack top)
      WRD TOR     ; >R  (push data stack to return stack)
      WRD DUP     ; DUP  (duplicate value at stack top)
      WRD UIF     ; jump to next inline literal if top of stack is nonzero
        WRD WIDW4
      WRD CR
      WRD DUP     ; DUP  (duplicate value at stack top)
      WRD UDOTQ
      WRD $04
      TXT "wid="
      WRD UDOT
      WRD CR
WIDW1 WRD ATT     ; @  (put to stack value at address on the stack top)
      WRD DUP     ; DUP  (duplicate value at stack top)
      WRD UIF     ; jump to next inline literal if top of stack is nonzero
        WRD WIDW3
      WRD TDUP    ; 2DUP (duplicate top two numbers)
      WRD CHARP   ; CHAR+ (Increment address at top by 1 characer size)
      WRD RAT     ; R@ (copy top of return stack to  data stack)
      WRD SAMEQ
      WRD UIF     ; jump to next inline literal if top of stack is nonzero
        WRD WIDW2
      WRD DUP     ; DUP  (duplicate value at stack top)
      WRD DOTID
      WRD SPACE
WIDW2 WRD CELLM   ; CELL- (Decrement address at top by 1 cell size)
      WRD NUFQ
      WRD UIF     ; jump to next inline literal if top of stack is nonzero
        WRD WIDW1
WIDW3:
WIDW4 WRD DROP    ; DROP  (remove value at stack)
      WRD RFROM   ; R> (pop return stack to  data stack)
      WRD EXITT   ; EXIT  (return from word execution)

; : words ( "ccc" -- )
;   bl parse  dup
;   if current begin cell+ @ ?dup while dup >r widwords r> repeat ( all wid )
;   else context @ widwords
;   then 2drop ;

; WORDS	( -- )
;		Display the names in the context vocabulary.

      WRD L244
L245  WRD $05
      TXT "WORDS"
      WRD 0
WORDS WRD LIST1  ; Process colon list
      WRD BLL
      WRD PARSE
      WRD DUP     ; DUP  (duplicate value at stack top)
      WRD UIF     ; jump to next inline literal if top of stack is nonzero
        WRD WRDS3
      WRD CURRE
WRDS1 WRD CELLP   ; CELL+ (Increment address at top by 1 cell size)
      WRD ATT     ; @  (put to stack value at address on the stack top)
      WRD QDUP    ; ?DUP (duplicate number on stack top if it is not zero)
      WRD UIF     ; jump to next inline literal if top of stack is nonzero
        WRD WRDS2
      WRD DUP     ; DUP  (duplicate value at stack top)
      WRD TOR     ; >R  (push data stack to return stack)
      WRD WIDWO
      WRD RFROM   ; R> (pop return stack to  data stack)
      WRD UELSE   ; jump to next inline literal
        WRD WRDS1
WRDS2 WRD UELSE   ; jump to next inline literal
        WRD WRDS4
WRDS3 WRD CONTE
      WRD ATT     ; @  (put to stack value at address on the stack top)
      WRD WIDWO
WRDS4 WRD TDROP   ; 2DROP remove 2 items from stack
      WRD EXITT   ; EXIT  (return from word execution)

; 
; : named? ( aa -- na | 0 )
;   current ( all wid )
;   begin cell+ @ dup ( last link ? )
;   while dup >r
;     begin @ ?dup ( zero link ? )
;     while 2dup name> >adr = ( match ? )
;        if swap r> 2drop exit ( found )
;        then cell-
;     repeat r>
;   repeat nip ( not found ) ;
; 


; NAMED? ( aa -- na | 0 )
; Is name defined
      WRD L245
L246  WRD $06
      TXT "NAMED?"
      WRD 0
NAMDQ WRD LIST1  ; Process colon list
      WRD CURRE
NMDQ1 WRD CELLP   ; CELL+ (Increment address at top by 1 cell size)
      WRD ATT     ; @  (put to stack value at address on the stack top)
      WRD DUP     ; DUP  (duplicate value at stack top)
      WRD UIF     ; jump to next inline literal if top of stack is nonzero
        WRD NMDQ5
      WRD DUP     ; DUP  (duplicate value at stack top)
      WRD TOR     ; >R  (push data stack to return stack)
NMDQ2 WRD ATT     ; @  (put to stack value at address on the stack top)
      WRD QDUP    ; ?DUP (duplicate number on stack top if it is not zero)
      WRD UIF     ; jump to next inline literal if top of stack is nonzero
        WRD NMDQ4
      WRD TDUP    ; 2DUP (duplicate top two numbers)
      WRD NAMET
      WRD EQUAL
      WRD UIF     ; jump to next inline literal if top of stack is nonzero
        WRD NMDQ3
      WRD SWAP    ; SWAP  (swap two values at stack top)
      WRD RFROM   ; R> (pop return stack to  data stack)
      WRD TDROP   ; 2DROP remove 2 items from stack
      WRD EXITT   ; EXIT  (return from word execution)
NMDQ3 WRD CELLM   ; CELL- (Decrement address at top by 1 cell size)
      WRD UELSE   ; jump to next inline literal
        WRD NMDQ2
NMDQ4 WRD RFROM   ; R> (pop return stack to  data stack)
      WRD UELSE   ; jump to next inline literal
        WRD NMDQ1
NMDQ5 WRD NIP     ; NIP (remove 2nd item from stack)
      WRD EXITT   ; EXIT  (return from word execution)

; : ssee ( a u -- ) ( simple decompiler )
;   cells bounds
;   begin 2dup xor ( done? )
;   while dup named? ?dup if cr .id cr then
;     space dup @ >adr named? ?dup
;     if .id ( display named token )
;     else dup @ 0 u.r ( unnamed token )
;     then cell+  nuf?
;   until then 2drop ;

; SSEE ( a u -- )
; ( simple decompiler )
      WRD L246
L247  WRD $04
      TXT "SSEE"
      WRD 0
SSEE  WRD LIST1  ; Process colon list
      WRD BNDS    ; BOUNDS (From addr and length, produce  addr+u and the start address)
SSEE1 WRD TDUP    ; 2DUP (duplicate top two numbers)
      WRD XORR    ; XOR  (bitwise XOR between two numbers on stack)
      WRD UIF     ; jump to next inline literal if top of stack is nonzero
        WRD SSEE5
      WRD DUP     ; DUP  (duplicate value at stack top)
      WRD NAMDQ
      WRD QDUP    ; ?DUP (duplicate number on stack top if it is not zero)
      WRD UIF     ; jump to next inline literal if top of stack is nonzero
        WRD SSEE2
      WRD CR
      WRD DOTID
      WRD CR
SSEE2 WRD SPACE
      WRD DUP     ; DUP  (duplicate value at stack top)
      WRD ATT     ; @  (put to stack value at address on the stack top)
      WRD NAMDQ
      WRD QDUP    ; ?DUP (duplicate number on stack top if it is not zero)
      WRD UIF     ; jump to next inline literal if top of stack is nonzero
        WRD SSEE3
      WRD DOTID
      WRD UELSE   ; jump to next inline literal
        WRD SSEE4
SSEE3 WRD DUP     ; DUP  (duplicate value at stack top)
      WRD ATT     ; @  (put to stack value at address on the stack top)
      WRD ULIT    ; push next inline literal
        WRD 0
      WRD UDOTR
SSEE4 WRD CELLP   ; CELL+ (Increment address at top by 1 cell size)
      WRD NUFQ
      WRD UIF     ; jump to next inline literal if top of stack is nonzero
        WRD SSEE1
SSEE5 WRD TDROP   ; 2DROP remove 2 items from stack
      WRD EXITT   ; EXIT  (return from word execution)

; : see ( "name" -- ) ( 15.6.1.2194 ) ' >adr -1 ssee ;

; SEE		( -- ; <string> )
;		A simple decompiler.
      WRD L247
L248  WRD $03
      TXT "SEE"
      WRD 0
SEE   WRD LIST1  ; Process colon list
      WRD TICK
      WRD ULIT    ; push next inline literal
        WRD $FFFF
      WRD SSEE
      WRD EXITT   ; EXIT  (return from word execution)
; *******************************************************************
; *     ASSEMBLER, PLATFORM SPECICIFIC, IMPLEMENT OPTIONALLY        *
; *******************************************************************

; : >ASM 16 * + ; 
; ASM ( n n-- n   )
; Calculates instruction shifting and adding operand

      WRD L248

AS01  WRD $04
      TXT ">ASM"
      WRD 0
TOASM WRD LIST1  ; Process colon list
      WRD SWAP
      WRD ULIT
         WRD $10
      WRD STAR
      WRD PLUS
      WRD EXITT
; 0 constant lod 
; lod (  -- n  ) generates initial opcode and count for this assembly instruction
      WRD AS01
AS02  WRD $03
      TXT "lod"
      WRD 0
ALOD  WRD LIST1  ; Process colon list
      WRD UCON
         WRD $0

; 1 constant add 
; add (  -- n  ) generates initial opcode and count for this assembly instruction

      WRD AS02
AS03  WRD $03
      TXT "add"
      WRD 0
AADD  WRD LIST1  ; Process colon list
      WRD UCON
         WRD $1

; 2 constant sub 
; sub (  -- n  ) generates initial opcode and count for this assembly instruction

      WRD AS03
AS04  WRD $03
      TXT "sub"
      WRD 0
ASUB  WRD LIST1  ; Process colon list
      WRD UCON
         WRD $2

; 3 constant and
; and (  -- n  ) generates initial opcode and count for this assembly instruction

      WRD AS04
AS05  WRD $03
      TXT "and"
      WRD 0
AAND  WRD LIST1  ; Process colon list
      WRD UCON
         WRD $3

; 4 constant ora
; ora (  -- n  ) generates initial opcode and count for this assembly instruction
      
      WRD AS05
AS06  WRD $03
      TXT "ora"
      WRD 0
AORA  WRD LIST1  ; Process colon list
      WRD UCON
         WRD $4

; 5 constant xor
; xor (  -- n ) generates initial opcode and count for this assembly instruction

      WRD AS06
AS07  WRD $03
      TXT "xor"
      WRD 0
AXOR  WRD LIST1  ; Process colon list
      WRD UCON
         WRD $5

; 6 constant shr
; shr (  -- n  ) generates initial opcode and count for this assembly instruction

      WRD AS07
AS08  WRD $03
      TXT "shr"
      WRD 0
ASHR  WRD LIST1  ; Process colon list
      WRD UCON
        WRD $6


; 7 constant mul
; mul (  -- n  ) generates initial opcode and count for this assembly instruction

      WRD AS08
AS09  WRD $03
      TXT "mul"
      WRD 0
AMUL  WRD LIST1  ; Process colon list
      WRD UCON
         WRD $7

; 8 constant sto
; sto (  -- n ) generates initial opcode and count for this assembly instruction
      
      WRD AS09
AS10  WRD $03
      TXT "sto"
      WRD 0
ASTO  WRD LIST1  ; Process colon list
      WRD UCON
        WRD $8

; 9 constant mif
; mif (  -- n  ) generates initial opcode and count for this assembly instruction


      WRD AS10
AS11  WRD $03
      TXT "mif"
      WRD 0
AMIF  WRD LIST1  ; Process colon list
      WRD UCON
         WRD $9

; 10 constant gtu
; gtu (  -- n  ) generates initial opcode and count for this assembly instruction

      WRD AS11
AS12  WRD $03
      TXT "gtu"
      WRD 0
AGTU  WRD LIST1  ; Process colon list
      WRD UCON
        WRD $A

; 11 constant gts
; gts (  -- n  ) generates initial opcode and count for this assembly instruction

      WRD AS12
AS13  WRD $03
      TXT "gts"
      WRD 0
AGTS  WRD LIST1  ; Process colon list
      WRD UCON
         WRD $B
 
; 12 constant ltu
; ltu (  -- n  ) generates initial opcode and count for this assembly instruction
      
      WRD AS13
AS14  WRD $03
      TXT "ltu"
      WRD 0
ALTU  WRD LIST1  ; Process colon list
      WRD UCON
        WRD $C


; 13 constant lts
; lts (  -- n  ) generates initial opcode and count for this assembly instruction

      WRD AS14
AS15  WRD $03
      TXT "lts"
      WRD 0
ALTS  WRD LIST1  ; Process colon list
      WRD UCON
         WRD $D


; 14 constant equ
; equ (  -- n  ) generates initial opcode and count for this assembly instruction

      WRD AS15
AS16  WRD $03
      TXT "equ"
      WRD 0
AEQU  WRD LIST1  ; Process colon list
      WRD UCON
         WRD $E


; 15 constant maj
; maj (  -- n  ) generates initial opcode and count for this assembly instruction

      WRD AS16
AS17  WRD $03
      TXT "maj"
      WRD 0
AMAJ  WRD LIST1  ; Process colon list
      WRD UCON
        WRD $F


; : r0 0 >ASM 
; r0 ( n -- n) appends register operand to opcode

      WRD AS17
AS18  WRD $02
      TXT "r0"
      WRD 0
AR0   WRD LIST1  ; Process colon list
      WRD ULIT
         WRD $0
      WRD TOASM
      WRD EXITT
; : r1 1 >ASM 
; r1 ( n -- n) appends register operand to opcode

      WRD AS18
AS19  WRD $02
      TXT "r1"
      WRD 0
AR1   WRD LIST1  ; Process colon list
      WRD ULIT
         WRD $1
      WRD TOASM
      WRD EXITT
; : r2 2 >ASM 
; r2 ( n -- n) appends register operand to opcode

      WRD AS19
AS20  WRD $02
      TXT "r2"
      WRD 0
AR2   WRD LIST1  ; Process colon list
      WRD ULIT
         WRD $2
      WRD TOASM
      WRD EXITT
; : r3 3 >ASM 
; r3 ( n -- n) appends register operand to opcode

      WRD AS20
AS21  WRD $02
      TXT "r3"
      WRD 0
AR3   WRD LIST1  ; Process colon list
      WRD ULIT
         WRD $3
      WRD TOASM
      WRD EXITT
; : r4 4 >ASM 
; r4 ( n -- n) appends register operand to opcode

      WRD AS21
AS22  WRD $02
      TXT "r4"
      WRD 0
AR4   WRD LIST1  ; Process colon list
      WRD ULIT
         WRD $4
      WRD TOASM
      WRD EXITT
; : r5 5 >ASM 
; r5 ( n -- n) appends register operand to opcode

      WRD AS22
AS23  WRD $02
      TXT "r5"
      WRD 0
AR5   WRD LIST1  ; Process colon list
      WRD ULIT
         WRD $5
      WRD TOASM
      WRD EXITT
; : r6 6 >ASM 
; r6 ( n -- n) appends register operand to opcode

      WRD AS23
AS24  WRD $02
      TXT "r6"
      WRD 0
AR5   WRD LIST1  ; Process colon list
      WRD ULIT
         WRD $6
      WRD TOASM
      WRD EXITT
; : r7 7 >ASM 
; r7 ( n -- n) appends register operand to opcode

      WRD AS24
AS25  WRD $02
      TXT "r7"
      WRD 0
AR7   WRD LIST1  ; Process colon list
      WRD ULIT
         WRD $7
      WRD TOASM
      WRD EXITT
; : r8 8 >ASM 
; r8 ( n -- n) appends register operand to opcode

      WRD AS25
AS26  WRD $02
      TXT "r8"
      WRD 0
AR8   WRD LIST1  ; Process colon list
      WRD ULIT
         WRD $8
      WRD TOASM
      WRD EXITT
; : r9 9 >ASM 
; r9 ( n -- n) appends register operand to opcode

      WRD AS26
AS27  WRD $02
      TXT "r9"
      WRD 0
AR9   WRD LIST1  ; Process colon list
      WRD ULIT
         WRD $9
      WRD TOASM
      WRD EXITT
; : r10 10 >ASM 
; r10 ( n -- n) appends register operand to opcode

      WRD AS27
AS28  WRD $03
      TXT "r10"
      WRD 0
AR10  WRD LIST1  ; Process colon list
      WRD ULIT
         WRD $A
      WRD TOASM
      WRD EXITT
; : r11 11 >ASM 
; r11 ( n -- n) appends register operand to opcode

      WRD AS28
AS29  WRD $03
      TXT "r11"
      WRD 0
AR11  WRD LIST1  ; Process colon list
      WRD ULIT
         WRD $B
      WRD TOASM
      WRD EXITT
; : r12 12 >ASM 
; r12 ( n -- n) appends register operand to opcode

      WRD AS29
AS30  WRD $03
      TXT "r12"
      WRD 0
AR13  WRD LIST1  ; Process colon list
      WRD ULIT
         WRD $C
      WRD TOASM
      WRD EXITT
; : r13 13 >ASM 
; r13 ( n -- n) appends register operand to opcode

      WRD AS30
AS31  WRD $03
      TXT "r13"
      WRD 0
AR13  WRD LIST1  ; Process colon list
      WRD ULIT
         WRD $D
      WRD TOASM
      WRD EXITT
; : r14 14 >ASM 
; r14 ( n -- n) appends register operand to opcode

      WRD AS31
AS32  WRD $03
      TXT "r14"
      WRD 0
AR14  WRD LIST1  ; Process colon list
      WRD ULIT
         WRD $E
      WRD TOASM
      WRD EXITT
; : r15 15 >ASM 
; r15 ( n -- n) appends register operand to opcode

      WRD AS32
L248A
AS33  WRD $03
      TXT "r15"
      WRD 0
AR15  WRD LIST1  ; Process colon list
      WRD ULIT
         WRD $F
      WRD TOASM
      WRD EXITT

; 
; ( software reset )
; 
; : cold ( -- )
;   sup 2@ rp! sp! ( init stacks )
;   sup @ cell- ( follower ) up ! ( init user pointer )
;   status follower !  sup tid !  sup awake ( init tasks )
;   0 !io ( init i/o device )
;   hex  -1 set-order definitions
;   cr [ =version ] literal count type
;   cr [ =(c) ] literal count type
;   cr quit ;

; COLD	( -- )
;		The hilevel cold start sequence.

      WRD L248A
L249  WRD $04
      TXT "COLD"
      WRD 0
COLD  WRD LIST1  ; Process colon list
      WRD SUP
      WRD CELLP   ; CELL+ (Increment address at top by 1 cell size)
      WRD TAT
      WRD RPSTO   ; RP! Set return stack pointer
      WRD SPSTO   ; SP!  (Set data stack pointer)
      WRD SUP
      WRD ATT     ; @  (put to stack value at address on the stack top)
      WRD CELLM   ; CELL- (Decrement address at top by 1 cell size)
      WRD UP
      WRD STORE   ; !  (write value at second stack item to address at stack top)
      WRD STATU
      WRD FOLLO   ; FOLLOWER ( address of next task's STATUS )
      WRD STORE   ; !  (write value at second stack item to address at stack top)
      WRD SUP
      WRD TID
      WRD STORE   ; !  (write value at second stack item to address at stack top)
      WRD SUP
      WRD AWAKE
      WRD ULIT    ; push next inline literal
        WRD 0
      WRD STOIO   ; !IO  (initialize input output system)
      WRD HEXX
      WRD ULIT    ; push next inline literal
        WRD -1
      WRD SETOR
      WRD DEFIN
      WRD CR
      WRD ULIT    ; push next inline literal
        WRD VERSI
      WRD COUNT
      WRD TYPE
      WRD CR
      WRD ULIT    ; push next inline literal
        WRD COPYR
      WRD COUNT
      WRD TYPE
      WRD CR
      WRD QUIT
      WRD EXITT   ; EXIT  (return from word execution)

; 
; code bye ( -- ) ( 15.6.2.0830 )
;   h# 20 int ( terminate process )
; end-code
; BYE		( -- )
;		Exit eForth.

      WRD L249
BYE0:
L250  WRD $03
      TXT "BYE"
      WRD 0
BYE   WRD VCOLD   ; BYE IS COLD START
VCOLD EQU R1,R1,R1  ; R1=1
      SUB R0,R0,R0, ; R0=0
      LOD R5,R5,R15    ; PUT R5 TO POINT TO INITIAL SP
      WRD SUPSP
      LOD R2,R2,R5     ; GET VALUE FOR PARAMETER SP
      LOD R5,R5,R15    ; PUT R5 TO POINT TO INITIAL rP
      WRD SUPRP
      LOD R3,R3,R5     ; GET VALUE FOR RETURN SP
      LOD R5,R5,R15    ; PUT R5 TO POINT TO XVAL
      WRD XVAL
      STO R1,R1,R5
      LOD R5,R5,R15    ; PUT R5 TO POINT TO YVAL
      WRD YVAL
      STO R1,R1,R5
	  
      LOD R9,R9,R15    ; SET R9 TO NEXT1
      WRD NEXT1
      LOD R4,R4,R15    ; 
      WRD STINT
      ORA R15,R9,R9   ; START INNER INTERPRETER AT NEXT1
STINT WRD COLD           
HERE0:
