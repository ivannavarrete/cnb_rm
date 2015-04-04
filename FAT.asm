
	BITS 16



	section .data
FAT:
			db 1				; cnb.bin
			times 19 db 0		; one byte for each user file

entry1:		db 'cnb.bin', 0
			times 0xD-$+entry1 db 0
			dw 3				; start sector

			times 512-$+FAT db 0
