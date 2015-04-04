
	BITS 16


%define FMINT 	0x20				; file manager int
%define MMINT	0x21				; memory manager int
%define CIINT	0x22				; command interpreter int

%define BG_COLOR	0x10
%define FG_COLOR	BG_COLOR+0x07


; multipush macro
%macro PUSH 1-*
%rep %0
	push	%1
%rotate 1
%endrep
%endmacro

; multipop macro
%macro POP 1-*
%rep %0
	pop		%1
%rotate 1
%endrep
%endmacro



	section .text
magic:			db	'CNB '
InitOS_offs:	dw	IOS_start		; ptr to InitOS code
FM_offs:		dw	FM_start		; ptr to file manager
MM_offs:		dw	MM_start		; ptr to memory manager
CI_recover_offs: dw	CI_recover		; ptr to emergency recover code

	
;***************************************************************
; InitOS code
;***************************************************************
IOS:
.sec_str		db	'InitOS code loaded', 0xD, 0

IOS_start:
	mov		ax, cs
	mov		ds, ax
	mov		es, ax
	cli
	mov		ss, ax
	xor		sp, sp
	sti

	mov		si, IOS.sec_str
	call	PrintStr

;---------------------------------------------------------------
;  set the OS interrupts (0x20, 0x21, 0x22)
;---------------------------------------------------------------
	cli
	push	es
	xor		ax, ax
	mov		es, ax

	mov		ax, [FM_offs]
	mov		[es:FMINT*4], ax
	mov		[es:FMINT*4+2], cs

	mov		ax, [MM_offs]
	mov		[es:MMINT*4], ax
	mov		[es:FMINT*4+2], cs			; << ERROR, should be MMINT

	mov		ax, [CI_recover_offs]
	mov		[es:CIINT*4], ax
	mov		[es:CIINT*4+2], cs

	pop		es
	sti

	call	ReadFAT
	
;---------------------------------------------------------------
; clear the user memory space
;---------------------------------------------------------------

;...
;...

;---------------------------------------------------------------
; InitOS done. Pass control to Command Interpreter
;---------------------------------------------------------------
	jmp		CI_start

	
;===============================================================
; ReadFAT/WriteFAT
;===============================================================
ReadFAT:
	push	ax
	mov		di, 0x0201				; read, one sector
	jmp		WriteFAT.go1
WriteFAT:
	push	ax
	mov		di, 0x0301				; write, one sector
.go1:
	PUSH	bx, cx, dx, si, di, es

	mov		si, 0xff ;ff				; try n times
	sti
.reset:
	xor		ah, ah					; reset disk
	mov		dh, 0x80
	int		0x13
	dec		si
	jnz		.reset
	
	mov		ax, di					; restore read/write select
	mov		bx, 0x0050				; 0x0050:0x0000 is sorce/destination buffer
	mov		es, bx
	xor		bx, bx
	xor		dx, dx					; head, drive
	mov		cx, 2					; cylinder, sector
	int		0x13
	jnc		.go2
	call	Hang
.go2:
	POP		es, di, si, ds, cx, bx
	pop		ax
	ret
	


;***************************************************************
; File Manager
;***************************************************************
FM:
.sec_str:		db	'file manager', 0xD, 0

FileEntry:
.name:			times 0xD db 0
.start_sec:		dw 0


FM_start:
	or		ah, ah
	jz		GetFile
	cmp		ah, 1
	jz		ListFiles
	cmp		ah, 2
	jnz		.go
	jmp		Format
.go:
	call	Hang

	mov		si, FM.sec_str
	call	PrintStr


;===============================================================
; GetFile
;---------------------------------------------------------------
; input:
;	es:di		filename ptr
; output:
;	ax			0 = not found, else start sector of file
;===============================================================
GetFile:
	PUSH	cx, si, ds

	mov		cx, 20					; scan 20 files (the whole filesystem)
	mov		ax, 0x0050
	mov		ds, ax
	mov		si, 1
.scan_files:
	cmp		byte [si], 0			; is the file block free?
	jz		.next_file

	push	si
	shl		si, 4
	add		si, 20
	call	StrCmp
	mov		ax, [si+0xD]			; get starting sector
	pop		si
	jz		.exit					; zf = file found

.next_file:
	inc		si						; next file
	loop	.scan_files
	xor		ax, ax					; file not found
.exit:
	POP		ds, si, cx
	iret


;===============================================================
; ListFiles
;===============================================================
ListFiles:
	PUSH	ax, bx, cx, si, di, ds, es
	
	xor		si, si
	mov		cx, 20
	mov		bx, ds
.list:
	mov		ax, 0x0050					; 0x0050:0x0000 is the FAT mirror
	mov		ds, ax
	push	si
	cmp		byte [si], 0				; chech the block table
	jz		.empty
	shl		si, 4						; index into the file name string
	add		si, 20
	mov		di, cmd_buffer
	call	StrCpy						; copy to OS memory space
	mov		si, di
	mov		ds, bx
	call	PrintStr					; print the filename
	call	NewLine
	jmp		.next

.empty:
	mov		ds, bx						; file block is empty
	mov		si, fb_empty
	call	PrintStr
.next:
	pop		si
	inc		si
	loop	.list

	POP		es, ds, di, si, cx, bx, ax
	iret

;=========================
; Dump -- dump 256 bytes
;=========================
Dump:
	PUSH	ax, cx, si, di, ds

	mov		ax, 0xB800
	mov		ds, ax
	xor		si, si

	mov		ah, 07
	mov		cx, 0x100
.loop:
	mov		al, [es:di]
	mov		[ds:si], ax
	inc		di
	inc		si
	inc		si
	loop	.loop
	
	POP		ds, di, si, cx, ax
	ret


;========================
; StrCpy
;------------------------
; input:
;	ds:si	source string
;	es:di	destination string
;========================
StrCpy:
	PUSH	ax, si, di
.copy:
	lodsb
	stosb
	or		al, al
	jz		.exit
	jmp		.copy
.exit:
	POP		di, si, ax
	ret


;===============================================================
; Format
;===============================================================
Format:
	PUSH	ax, cx, di, ds

	mov		ax, 0x0050
	mov		es, ax
	mov		di, 1					; exclude the first file (cnb.bin)

	mov		cx, 19 					; clear the FAT
	xor		al, al
	rep		stosb
	sti								; needed for the disk read
	call	WriteFAT				; store the fat on disk

	POP		ds, di, cx, ax
	iret



;***************************************************************
; Memory Manager
;***************************************************************
MM:
.sec_str		db	'memory manager', 0xD, 0

MM_start:
	mov		si, MM.sec_str
	call	PrintStr
	call	Hang


;***************************************************************
; Command Interpreter
;***************************************************************
CI:
.sec_str		db	'command interptreter loaded', 0xD, 0
.cmd_prompt		db	': ', 0

CI_start:
	mov		ax, cs
	mov		ds, ax
	mov		es, ax

	mov		si, CI.sec_str
	call	PrintStr
	call	ClearScreen
	call	Interpreter


;==============================================================
; Interpreter -- there's no escape from here
;==============================================================
Interpreter:
.read_new_line:
	mov		si, CI.cmd_prompt
	call	PrintStr

	mov		di, cmd_buffer
	cld
.read_line:
	xor		ah, ah						; read character
	mov		si, char_buf
	int		0x16
	mov		[si], al					; store char in char buffer
	stosb								; store char in command buffer
	cmp		al, 0x0D
	jz		.cmd_read
	cmp		al, 0x0A
	jz		.cmd_read
	mov		byte [si+1], 0
	call	PrintStr
	jmp		.read_line
	
.cmd_read:
	call	NewLine
	mov		byte [di-1], 0				; null terminator
	call	Command
	jmp		.read_new_line


;==============================================================
; execute command given on cmd line
;==============================================================
Command:
	PUSH	si, di
	push	word .exit
	
	mov		di, cmd_buffer
	mov		si, cmd_help
	call	StrCmp
	jc		Command_Help
	mov		si, cmd_list
	call	StrCmp
	jc		Command_List
	mov		si, cmd_mem
	call	StrCmp
	jc		Command_Mem
	mov		si, cmd_time
	call	StrCmp
	jc		Command_Time
	mov		si, cmd_boot
	call	StrCmp
	jc		Command_Boot
	mov		si, cmd_cls
	call	StrCmp
	jc		Command_Cls
	mov		si, cmd_format
	call	StrCmp
	jc		Command_Format
	mov		si, cmd_del
	call	StrCmp
	jc		Command_Del
	
	pop		si
	mov		si, syntax_error
	call	PrintStr
.exit:
	POP		di, si
	ret

;==============================================================
; Command_Help
;==============================================================
Command_Help:
	push	si
	mov		si, help_str
	call	PrintStr
	pop		si
	ret


;==============================================================
; Command_List
;==============================================================
Command_List:
	push	ax
	mov		ah, 1				; list files subfunction
	int		0x20				; file manager interrupt
	pop		ax
	ret
	

;==============================================================
; Command_Mem
;==============================================================
Command_Mem:
	push	si
	mov		si, not_ready
	call	PrintStr
	pop		si
	ret


;==============================================================
; Command_Time
;==============================================================
Command_Time:
	push	si
	mov		si, not_ready
	call	PrintStr
	pop		si
	ret



;==============================================================
; Command_Boot
;==============================================================
Command_Boot:
	call	ClearScreen
	xor		ax, ax
	int		0x19					; reboot
	call	Hang					; just in case

	
;==============================================================
; Command_Cls
;==============================================================
Command_Cls:
	call	ClearScreen
	ret


;==============================================================
; Command_Format
;==============================================================
Command_Format:
	push	ax
	mov		ah, 3				; format subfunction
	int		0x20				; file manager interrupt
	pop		ax
	ret


;==============================================================
; Command_Del
;==============================================================
Command_Del:
	push	si
	mov		si, not_ready
	call	PrintStr
	pop		si
	ret
	

;==============================================================
; recovery ISR
;==============================================================
CI_recover:
	cli
.hang
	jmp		.hang



;==============================================================
; stop execution
;==============================================================
hang_error:		db	'error: system locked', 0xD, 0
Hang:
	mov		si, hang_error
	call	PrintStr
.hang:
	jmp		Hang.hang


;==============================================================
; StrCmp -- compare two stings
;--------------------------------------------------------------
; input:
;	ds:si	source string
;	es:di	destination string
; output:
;	cf		1 = equal, 0 = not equal
;==============================================================
StrCmp:
	PUSH	ax, cx, si, di

	push	di					; calculate length of one string
	mov		cx, 0xFFFF
	xor		al, al
	cld
	repnz	scasb
	not		cx
	pop		di

.compare						; compare strings
	lodsb
	cmp		[di], al
	clc							; default to not equal
	jnz		.exit
	inc		di
	loop	.compare
	
	stc
.exit:
	POP		di, si, cx, ax
	ret


;==============================================================
; PrintStr -- print a string
;--------------------------------------------------------------
; input:
;	ds:si pointer to null terminated string
;==============================================================
PrintStr:
	PUSH	ax, bx, cx

.write:
	mov		ah, 0x09			; write character under cursor position
	mov		bx, 0x0000+FG_COLOR	; page 0
	mov		cx, 1				; write one character only
	cld
	lodsb
	or		al, al
	jz		.exit

	push	word .write
	cmp		al, 0xD
	jz		NewLine
	add		sp, 2
	cmp		al, 0xA
	jz		.write
	int		0x10

.get_cursor:
	mov		ah, 0x03			; get cursor position
	xor		bx, bx				; page 0
	int		0x10

	mov		ah, 0x02			; set cursor position
	cmp		dh, [rows]
	jb		.go1
	xor		dh, dh
.go1:
	inc		dl
	cmp		dl, [columns]
	jb		.go2
	xor		dl, dl
	inc		dh
.go2:
	int		0x10
	jmp		.write

.exit:
	POP		cx, bx, ax
	ret


;=======================
; Mark
;=======================
Mark:
	PUSH	si, ds
	
	mov		si, 0xB800
	mov		ds, si
	xor		si, si
	mov		[ds:si], al

	POP		ds, si
	ret


;==============================================================
; ClearScreen
;==============================================================
ClearScreen:
	PUSH	ax, bx, cx, dx

	mov		ah, 0x2				; set cursor position
	xor		bx, bx				; page
	xor		dx, dx				; row, column
	int		0x10

.clear:
	mov		ah, 0x9				; display char
	mov		al, 0x20
	mov		cx, [screensize]	; all over the screen
	mov		bx, 0x0000+BG_COLOR/0x10+BG_COLOR
	int		0x10

	mov		ah, 0x2				; set cursor position
	xor		bx, bx				; page
	xor		dx, dx				; row, column
	int		0x10

.exit:
	POP		dx, cx, bx, ax
	ret


;==============================================================
; NewLine
;==============================================================
NewLine:
	PUSH	ax, bx, cx, dx

	mov		ah, 0x9
	mov		al, 0x20
	mov		bx, 0x0000+FG_COLOR	; page 0
	mov		cx, 1
	int		0x10

	mov		ah, 0x3				; get cursor position
	xor		bx, bx				; page 0
	int		0x10

	mov		ah, 0x02			; set cursor position
	inc		dh					; row
	xor		dl, dl				; column
	int		0x10

	POP		dx, cx, bx, ax
	ret


;**************************************************************
; MAIN DATA AREA
;**************************************************************
cmd_buffer:		times 0x100 db 0
char_buf:		db 0, 0

; internal OS commands
cmd_help:		db 'help', 0
cmd_list:		db 'list', 0
cmd_mem:		db 'mem', 0
cmd_time:		db 'time', 0
cmd_boot:		db 'boot', 0
cmd_cls:		db 'cls', 0
cmd_format:		db 'format', 0
cmd_del:		db 'del', 0

syntax_error:	db 'syntax error', 0xD, 0
not_ready:		db 'command not implemented', 0xD, 0

help_str:		db 'HELP        display all internal commands', 0xD,
				db 'LIST        list the files in the file system', 0xD,
				db 'MEM         display memory system information', 0xD,
				db 'TIME        display the date and time', 0xD,
				db 'BOOT        do a soft reboot', 0xD
				db 'CLS         clear screen', 0xD
				db 'FORMAT      format the file system', 0xD, 0
				db 'DEL         delete a file from the file system', 0xD, 0

fb_empty:		db 'file block empty', 0xD, 0
mb_empty:		db 'memory block empty', 0xD, 0

screensize:		dw 80*25
rows:			db 25
columns:		db 80


;===============================================================
; padding bytes -- pad the file to 10k size
;===============================================================
pad:	times 10240 - $ + magic db 0
