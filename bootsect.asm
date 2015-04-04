;
; 2000-07-18
;
; crash 'n burn  --  prototype 
; real-mode version 0.0.0


	BITS 16
	ORG 0x0


%define BOOTSEG 0x07C0			; original address of bootsector
%define INITSEG 0x9000			; move bootsector here, out of the way
%define SYSSEG 0x0070			; load the OS here (0x0070:0x0000)
%define ATTRIB 0x04				; red font
	

	section .text
bootsect_start:
	jmp		start

start_str:			db	'bootsector loaded', 0xD, 0xA, 0
sofar_str			db	'so far so good', 0xD, 0xA, 0
hang_error:			db	'error: system is locked', 0xD, 0xA,
					db	'press a key to reboot', 0xD, 0xA, 0
cnbfile_error:		db	'error: CNB.BIN not loaded', 0xD, 0xA, 0
hd_error:			db	"error: can't read harddrive", 0xD, 0xA, 0


start:
;-----------------------------------------------------------
; copy bootsector from 0x07C0 (start location) to 0x9000
;-----------------------------------------------------------
	cli
	mov		ax, BOOTSEG
	mov		ds, ax
	mov		ax, INITSEG
	mov		es, ax
	xor		si, si
	xor		di, di
	mov		cx, 0x100
	cld
	rep		movsd
	jmp		INITSEG:go

;-----------------------------------------------------------
; continue execution here
;-----------------------------------------------------------
go:
	mov		ds, ax				; ax = INITSEG
	mov		ss, ax
	mov		ax, 0x4000
	mov		sp, ax

	sti

	mov		si, start_str
	call	PrintStr

;-----------------------------------------------------------
; load CNB.BIN to 0x70:0x0
;-----------------------------------------------------------
	xor		ah, ah				; reset disk system
	xor		dl, dl				; drive
	int		0x13

	mov		bx, SYSSEG
	mov		es, bx
	xor		bx, bx				; place file at 0070:0000
	mov		ax, 0x0220			; read 20 sectors into mem
	xor		dx, dx				; head, drive nr
	mov		cx, 0x0003			; cylinder, sector
	int		0x13
	mov		si, hd_error
	jc		error_exit

;-----------------------------------------------------------
;  check if this is the right file
;-----------------------------------------------------------
	mov		si, cnbfile_error
	mov		ax, [es:0]
	cmp		ax, 'CN'
	jnz		error_exit
	mov		ax, [es:2]
	cmp		ax, 'B '
	jnz		error_exit

;-----------------------------------------------------------
; transfer control to InitOS code
;-----------------------------------------------------------
	mov		word [laban+2], SYSSEG
	mov		ax, [es:4]
	mov		[laban], ax
	jmp		far [laban]

laban:		dd 0

error_exit:
	call	PrintStr
exit:
	call	Hang
		
	
;===========================================================
; stop execution
;===========================================================
Hang:
	mov		si, hang_error
	call	PrintStr
	xor		ax, ax
	int		0x16				; wait for a keypress
	int		0x19				; reboot
.hang:
	jmp		.hang				; if all else fails


;===========================================================
; ds:si pointer to null terminated string
;===========================================================
PrintStr:
	mov		ah, 0x0E			; teletype output
	mov		bx, 0x0007			; page 0, normal attributes
.write:
	lodsb
	or		al, al
	jz		PrintStr.exit
	int		0x10
	jmp		PrintStr.write
.exit:
	ret


;===========================================================
; padding bytes (pad to 512 bytes)
;===========================================================
times 510-$+bootsect_start db ' '
bootsect_mark:	db	0x55, 0xAA
