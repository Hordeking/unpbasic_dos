; The program always assumes the first argument is the input. However, it can take an arbitrary
; number of arguments. Normal use would only be two args. However, the code actually keeps
; scanning until it finds the last space (which precedes the final argument) in the string, and
; uses THAT argument as argv[2]
ORG 0x100
BITS 16

JMP main

Key1	db 0x9A, 0xF7, 0x19, 0x83, 0x24, 0x63, 0x43, 0x83, 0x75, 0xCD, 0x8D, 0x84, 0xA9
Key2	db 0x7C, 0x88, 0x59, 0x74, 0xE0, 0x97, 0x26, 0x77, 0xC4, 0x1D, 0x1E
defaultOutfile	db `FIL.BAS\0`
FileNotFound	db `\r\nFile Not Found$`
DiskFull		db `\r\nDisk Full$`
UnprotectFail	db `\r\nUnable to Unprotect File$`
Usage			db `Unprotect Basic Version 1.10  12/21/1990  John Thomason\r\n\r\nUsage:  UNPBASIC  filename1  [filename2]\r\n  filename1 = protected Basic file\r\n  filename2 = unprotected Basic file (default FIL.BAS)\r\n$`
outFile			dw 0h
pSrcEnd			dw 0h

main:
	MOV BX, 0x81
	CMP byte [BX], 0x0d				;Check for no argument
	JNZ Arguments_Found
	LEA DX, [Usage]					;= "Unprotect Basic Version 1.10 12/...
	JMP PrintString

Arguments_Found:
	INC BX
	CMP byte [BX], 0x20				;Keep going till we find a space.
	JNZ .Not_A_Space
	MOV byte [BX], 0x00
	MOV word [outFile], BX
	INC word [outFile]

.Not_A_Space:
	CMP byte [BX], `\r`				;Check for EOL
	JNZ Arguments_Found
	MOV byte [BX], 0x00				;Change this \r to a \0 so we can use it as a null-terminated string
	CMP byte [outFile], 0x00
	JNZ Read_Source_File
	MOV word [outFile], defaultOutfile	;= "FIL.BAS"

Read_Source_File:
	MOV AX, 0x3d00
	MOV DX, 0x82					;0x82 is the pointer to argv[1]
	INT 0x21						;Open Source read-only.
	JNC .SourceFileOpen_Success
	LEA DX, [FileNotFound]			;= "\r\nFile Not Found$"
	JMP PrintString

.SourceFileOpen_Success:
	PUSH BX
	MOV BX, AX						;Put source file handle in BX for the read function.
	MOV CX, 0xf800					;Copy 63488 bytes max
	LEA DX, [pSrc]					;Buffer source right after the end of the code
	MOV AH, 0x3f
	INT 0x21

	ADD AX, pSrc					;INT 0x21 returns the actual number of bytes read into AX.
	MOV [pSrcEnd], AX				;After this section, pSrcEnd will point to the last byte of the file
	DEC word [pSrcEnd]				;pSrcEnd = pSrc + bytesread - 1

	MOV AH, 0x3e
	INT 0x21						;Close the source file, we're done with it.

Setup_Unprotect:
	MOV CX, 0x0d0b					;Set up the counters (CH, CL) for decryption. idxKey1 = CH, idxKey2 = CL

	; This section checks that it's an encrypted file, looking for the 0xfe magic number
	MOV BX, pSrc
	CMP byte [BX], 0xfe				;Check first byte for 0xfe. If it isn't 0xfe, it isn't GWBasic Encrypted
	JZ Unprotect_Begin
	LEA DX, [UnprotectFail]			;= "\r\nUnable to Unprotect File$"
	JMP PrintString

Unprotect_Begin:					;decoded = (encoded – CL) ^ Key1[CH – 1] ^ Key2[CL – 1] + CH
	MOV DX, BX						;Set DX to the source buffer.
	INC DX							;Increment DX by 1, since the first byte is known to be 0xfe anyway.
.DecodeNextChar:
	MOV BX, word [pSrcEnd]
	CMP BX, DX			;Wrap it up if the current pointer is at the end of the source (pCur == pSrcEnd).
	JZ Wrap_Up_And_Write

	; This section sets BX = Key1(idxKey1-1), with idxKey2 is 0x01 thru 0x0d
	MOV BX, (Key1-1)				;This is Key1[-1]. We're going to be adding a 1-based index in a moment.
	MOV AL, CH
	CBW								;Essentially AX = (signed short) idxKey1
	ADD BX, AX						;BX now references Key1[CH-1]

	MOV SI, DX						;Set SI to the current character.
	CLD								;Required? Let's move it to earlier in the code.
	LODSB							;AL = encoded
	SUB AL, CL						;AL = (AL - CH)
	XOR AL, byte [BX]				;AL = AL XOR Key1[CH-1]
	PUSH AX							;Save (AL - CH) XOR Key1[CH-1] for later.

	; This section sets BX = Key2(idxKey2-1), with idxKey2 is 0x01 thru 0x0b
	MOV BX, (Key2-1)				;This is Key2[-1]. We're going to be adding a 1-based index in a moment.
	MOV AL, CL
	CBW								;Essentially, AX = (signed short) idxKey2
	ADD BX, AX						;BX now references Key2[CL-1]

	POP AX							;Now we've got BX pointing to Key2[CL-1]. Restore the state of AL so we can continue.
	XOR AL, byte [BX]				;AL = {(AL-CH)^Key1[CH-1]} XOR Key2[CL-1]
	ADD AL, CH						;Final step: Add CH to the result.

	; AL now contains the unencrypted byte.
	MOV DI, DX
	CLD								;Is this required?
	STOSB							;Overwrite encrypted byte with decrypted byte in memory.
	INC DX							;Move to next byte

.DecrementKey2:						;Decrement counters
	DEC CL
	JNZ .DecrementKey1
	MOV CL, (defaultOutfile-Key2)	;Reset the Key2 Counter to repeat.
.DecrementKey1:
	DEC CH
	JNZ .DecodeNextChar
	MOV CH, (Key2-Key1)				;Reset the Key1 Counter to repeat.
	JMP .DecodeNextChar

Wrap_Up_And_Write:
	LEA BX, [pSrc]					; Set BX to point at data
	MOV byte [BX], 0xff				; Set magic number to "tokenized"
	MOV BX, word [pSrcEnd]
	MOV byte [BX], 0x1a				; Set last byte to 0x1a
	DEC BX
	MOV byte [BX + 0x0e], 0x00
	MOV AH, 0x3c
	MOV CX, 0x00
	MOV DX, word [outFile]
	INT 0x21
	JC .CantWriteOutput
	MOV BX, AX
	MOV AH, 0x40
	LEA DX, [pSrc]
	MOV CX, word [pSrcEnd]
	SUB CX, pSrc					; pEnd-pBegin (Data Length)
	INC CX
	INT 0x21
	CMP AX, CX
	JZ Close_File_And_Exit
.CantWriteOutput:
	LEA DX, [DiskFull]				;= "\r\nDisk Full$"

PrintString:
	MOV AH, 0x09
	INT 0x21
	JMP Return_To_OS

Close_File_And_Exit:
	MOV AH, 0x3e
	INT 0x21
Return_To_OS:
	INT 0x20

pSrc:
; This label simply points at the end of the code for later use. Think of it as a bss of sorts.
; It actually serves to point to the start of where the data is loaded and modified.
