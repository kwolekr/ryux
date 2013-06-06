;
; Copyright (c) 2008 Ryan Kwolek
; All rights reserved.
;
; Redistribution and use in source and binary forms, with or without modification, are
; permitted provided that the following conditions are met:
;  1. Redistributions of source code must retain the above copyright notice, this list of
;     conditions and the following disclaimer.
;  2. Redistributions in binary form must reproduce the above copyright notice, this list
;     of conditions and the following disclaimer in the documentation and/or other materials
;     provided with the distribution.
;
; THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND ANY EXPRESS OR IMPLIED
; WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
; FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR OR
; CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
; CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
; SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
; ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
; NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
; ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
;

; bootloader_I.asm -
;    Minimal boot sector code that merely loads the second stage from the same
;    disk this was boot off of; attempts to use LBA if a hard disk.
;    Started on 12/31/07
;

[BITS 16]
[ORG 0x7C00]

	jmp 0000:real7c00    ;; make sure to fix up bogus starting addresses
	
real7c00:
	clc                  ;;;; errrors are on carry flag
	mov byte [1000h], dl ;;;; 1000h = my own block of system info easily obtainable with the bios

	test dl, 80h
	
	jz usechs
	
	mov ah, 41h	;; does this hard disk support LBA?
	mov bx, 55AAh   
	int 13h
	
	jc usechs
	
	cmp bx, 0AA55h ;; just to make sure...
	jne usechs

	uselba:
		;ah == major ver of disk extentions
		mov byte [1001h], ah
			
			
usechs:
	mov byte [1001h], 0
	
	mov si, loadstr
	call DisplayString

	mov ax, 0204h       ; ah = 02, read disk fxn code, al = 04, # sectors to read (512 * 4 = 2048)
	mov cx, 2
	xor dh, dh          ;;;; read from whatever it was loaded from
	push cs
	pop es
	mov bx, 8000h
	int 13h

	jc failedcheck
	cmp word [es:8000h], 'ry'
	je 8004h
	
failedcheck:
	mov si, errstr
	call DisplayString
errored:
	hlt
	jmp errored
Int10h:
	mov bx, 000Fh
	mov ah, 0Eh
	int 10h
DisplayString:
	mov al, byte [si]
	inc si
	cmp al, 0
	jne Int10h
	ret

loadstr: db  0Dh, 0Ah, 'RY/UX Stage I Bootloader', 0Dh, 0Ah, 'Loading Stage II Image...', 0Dh, 0Ah, 0
errstr:  db  'Error Reading Disk', 0Dh, 0Ah, 0

times 510-($-$$) db 0
dw 0AA55h

