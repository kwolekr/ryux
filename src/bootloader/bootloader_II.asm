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

; bootloader_II.asm -
;    The main bootloader of RY/UX.  Performs low-level initialization tasks, such
;    as loading the kernel, floppy and hard disk drivers, enabling A20 line,
;    remapping IRQs, gathering hardware information, and entering protected mode
;    before finally passing control to the kernel.
;    Started on 1/29/08
;

[BITS 16]

struc biosinfo
	.bootdrive: resb 1  ;boot drive  
	.uselba:	resb 1  ;able to use lba?
	.getdp_cx:	resw 1  ;cx from getdriveparams
	.getdp_dx:	resw 1  ;dx from getdriveparams
	.nmmapents: resw 1  ;number of mem map entries
endstruc

%define biosstuff  1000h
%define memmap_tmp 1100h

[ORG 0x8000]
	dd 'ryux'
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

start:
	mov si, str_loaded
	call _puts

	call BtlGetDriveParams

	call BtlGetMemoryMap

	;load kernel
	mov si, str_kern_loading
	call _puts
	
	push 6 ;;;; ((0x200 + 0x800) / 0x200) + 1
	push 0
	push 0
	call BtlLoadModule
	
	test ax, ax
	jnz .noerr1
		mov si, str_err_loadmod
		call _puts
		jmp BtlPanicRMode
	.noerr1:
	
	;load floppy driver
	mov si, str_flp_loading
	call _puts
	
	;;;((0x200 + 0x800 + 0x4000) / 0x200) == 37 in LBA...
	;;;80 cylinders, 18 sectors per cylinder, 2 heads
	;;; cyl = [37 / 18] / 2, sector = (37 % 18) + 1
	;;; this will be different for hard drives!
	
	push 2
	push 0
	push 1
	call BtlLoadModule
	
	test ax, ax
	jnz .noerr2
		mov si, str_err_loadmod
		call _puts
		jmp BtlPanicRMode
	.noerr2:
	
	cli
	call BtlDisableNMIs
	
	mov ax, 0
	mov ds, ax
	mov es, ax
	mov fs, ax
	mov gs, ax
	mov ss, ax

	lgdt [GDT_DESC]
	
	call BtlEnableA20Line
	
	mov si, str_a20_enabled
	call _puts
	
	lidt [IDT_DESC]
	
	mov eax, cr0
	or eax, 1 
	mov cr0, eax

	jmp 08h:BtlEnterPMode
	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
BtlPanicRMode:
	.rhltloop:
		hlt
	jmp .rhltloop
	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
BtlEnableA20Line:
	call BtlIoWait	
	mov al, 0D1h    
	out 064h, al
	call BtlIoWait
	mov al, 0DFh    ;;;;; A20 enable DFh, 110111[1]1, off DDh, 110111[0]1
	out 060h, al
	call BtlIoWait
	ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
BtlDisableNMIs: ;;; 
	in al, 070h
	or al, 080h
	out 070h, al
	ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
BtlEnableNMIs:
	in al, 070h
	and al, 07Fh
	out 070h, al
	ret
	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
BtlIoWait:
	in al, 64h
	test al, 2
	jnz BtlIoWait
	ret
	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;	INT 13 - DISK - GET DRIVE PARAMETERS (PC,XT286,CONV,PS,ESDI,SCSI)
;	AH = 08h
;	DL = drive (bit 7 set for hard disk)
;	ES:DI = 0000h:0000h to guard against BIOS bugs
;Return: CF set on error
;	    AH = status (07h) (see #00234)
;	CF clear if successful
;	    AH = 00h
;	    AL = 00h on at least some BIOSes
;	    BL = drive type (AT/PS2 floppies only) (see #00242)
;	    CH = low eight bits of maximum cylinder number
;	    CL = maximum sector number (bits 5-0)
;		 high two bits of maximum cylinder number (bits 7-6)
;	    DH = maximum head number
;	    DL = number of drives
;	    ES:DI -> drive parameter table (floppies only)

BtlGetDriveParams: ;;;void BtlGetDriveParams(dl:drive_no)
	test dl, 80h
	
	push 0
	pop es
	jz .is_floppy
		xor di, di   ;; ES:DI should be clear for buggy BIOSes, if dl is a hard drive
		jmp .is_floppy_end
	.is_floppy:
		mov di, 1100h ;; 0000:1100h, to be overwritten by memmap later
	.is_floppy_end:   ;; don't care about drive param table, since i read it in the driver
	
	mov ah, 08h
	int 13h
	jnc .error
		mov si, str_err_getdp
		call _puts
	.error:
	
	mov word [biosstuff + biosinfo.getdp_cx], cx
	mov word [biosstuff + biosinfo.getdp_dx], dx
	ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
BtlGetMemoryMap:
	push bp
	xor bp, bp
	
	xor ebx, ebx
	mov ecx, 20
	clc
	
	push 0
	pop es
	mov di, 1100h

	.cont_int15h:
		mov eax, 0000E820h
		mov edx, 'PAMS'	
		int 15h
		add di, cx
		inc bp
		test ebx, ebx
	jnz .cont_int15h
	
	mov word [biosstuff + biosinfo.nmmapents], bp
	pop bp
	ret
	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
BtlLoadModule: ;;;int BtlLoadModule([bp+4]:cylinder, [bp+6]:head, [bp+8]:sector)
	;To load a module:
	;1. Read it from the preset CHS
	;2. Check if the ryux signature is present
	;3. Relocate to the preferred base address
	;4. Apply protection (not now)
	;5. Gather requested imports
	;6. Start execution at base of code section (optional)
	
	push bp
	mov bp, sp

	mov dl, byte [1000h]
	mov dh, byte [bp + 6]
	mov ax, word [bp + 4]
	mov ch, al
	mov cl, ah
	shl cl, 6
	or cx, word [bp + 8]
	mov ax, 0201h  ; ah = 02 read, al = 01 # sectors
	push 0
	pop es  ;temp buf at 0000:2000
	mov bx, 2000h
	int 13h
	;xchg bx,bx;;;;
	jc .errorz
	
	cmp word [2000h], 'br'
	jne .errorz
	cmp word [2002h], 'ew'
	jne .errorz

	
	mov dl, byte [1000h]
	mov dh, byte [bp + 6]
	mov ax, word [bp + 4]
	mov ch, al
	mov cl, ah
	shl cl, 6
	or cx, word [bp + 8]
	inc cx               ;next sector
	mov ax, word [2008h] ;size
	shr ax, 9            ;divide by 512
	dec ax               ;subtract 1 because i already loaded it
	mov ah, 2            ;fxn code...
	mov bx, 2200h        ;aha, i had 2000h instead of 2200h
	int 13h
	jc .errorz
	
	mov cx, word [2008h]
	shr cx, 1
	push 0
	pop ds
	mov si, 2000h
	mov di, word [200Ch]
	
	mov ax, word [200Eh]
	shl ax, 12
	push ax
	pop es
	
	rep movsw
	
	push 0
	pop es
	mov ax, 1
	mov sp, bp
	pop bp
	ret 6
	
	.errorz:
	push 0
	pop es
	xor ax, ax
	mov sp, bp
	pop bp
	ret 6
	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; B8000h text colors:
;1 blue			;5 purple		;9 periwinkle		;d pink
;2 green		;6 orange		;a light green		;e pastel yellow
;3 light blue	;7 reg gray		;b teal				;f white
;4 red 			;8 dark gray	;c salmon

	callint10h: 
		mov bx, 000Fh
		mov ah, 0Eh
		int 10h
_puts: ;;;void _puts(si:str)
	mov al, byte [si]
	inc si
	cmp al, 0
	jne callint10h
	ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
dumphex: ;;;void dumphex(si:src, bp:len)
	movzx di, byte [si]
	inc si
	
	mov bx, di
	shr bx, 4
	mov al, byte [hexstr + bx]
	mov ah, 0Eh
	mov bx, 000Fh
	int 10h
	
	mov bx, di
	and bx, 0Fh
	mov al, byte [hexstr + bx]
	mov ah, 0Eh
	mov bx, 0000Fh
	int 10h
	
	mov ax, 0E20h
	mov bx, 000Fh
	int 10h
	
	dec bp
	jnz dumphex
	ret


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;; PMODE ENTRY POINT ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
[BITS 32]
align 16, db 0

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
BtlEnterPMode:
	mov ax, 10h
	mov ds, ax
	mov es, ax
	mov fs, ax
	mov gs, ax
	mov ss, ax
	
	mov byte [0B8000h], 'P'
	mov byte [0B8001h], 0x91
	
	call BtlRemapPIC
	call BtlEnableNMIs
	sti
	
	call BtlAddImports
	
	mov ebp, 4000h
	mov esp, 4000h

	mov ebx, 10000h
	;lea ebx, [ebx + SECT_CODE * 10h + 10h]
	lea ebx, [ebx + 10h]
	cmp dword [ebx], 'code'
	jne BtlPanicPMode
	
	mov ebx, dword [ebx	+ 4]
	test ebx, ebx
	jz BtlPanicPMode
	
	jmp ebx
	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
BtlPanicPMode:
	
	.phltloop:
		hlt
	jmp .phltloop

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
BtlAddImports:
	;at this point of loading, kernel imports are only supported
	;TODO: get imports for fdc module
	mov ebx, 30000h ;base addr of floppy
	;TODO: make this not constant!!
	
	;mov ebx, [ebx + SECT_IMPT * 10h + 10h]
	lea ebx, [ebx + 40h] 	;get import table
	cmp dword [ebx], 'impt' ;cmp section sig
	jne .errorz
	
	mov ebx, dword [ebx + 4] ;goto actual section
	
	mov ecx, dword [ebx] ;get number of libraries... preserve ebx!
	add ebx, 4
	
	.loop_top:
		test ecx, ecx
		jz .done_loop
		dec ecx
		
		
		mov edx, [ebx] ;get library name ptr
		cmp dword [edx], 'kern'
		jz .cont_loop
		cmp word [edx + 4], 'el'
		jz .cont_loop ;if not kernel import, continue...
			push ecx
			push ebx
		
			mov ecx, dword [ebx + 4]
			mov ebx, dword [ebx + 8]
			
			.loop_top2:
				test ecx, ecx
				jz .done_loop2
				dec ecx
				
				push dword [ebx + 4]
				push 10000h
				call BtlGetExportAddr
				
				mov [ebx + 8], eax
				
				add ebx, 0Ch
				
				jmp .loop_top2
			.done_loop2:
		
			pop ebx
			pop ecx
		.cont_loop:
		add ebx, 0Ch
		jmp .loop_top
	.done_loop:
	.errorz:
	ret
	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
BtlGetExportAddr: ;;target module base addr, name
	push ebx
	push ecx
	
	mov ebx, dword [esp + 12]
	;lea ebx, [eax + SECT_EXPT * 10h + 10h]
	lea ebx, [ebx + 50h]
	cmp dword [ebx], 'expt'
	jne .fail
	mov ebx, dword [ebx + 4] ;; ebx = base ptr of export section
	
	mov ecx, dword [ebx]
	add ebx, 4
	.top_loop:
		test ecx, ecx
		jz .done_loop
		dec ecx
	
		mov esi, dword [ebx + 4]
		mov edi, dword [esp + 16]
		call _strcmp
	
		test eax, eax
		jnz .not_yet
			mov eax, dword [ebx + 8]
			pop ecx
			pop ebx
			ret 8
		.not_yet:
	
		add ebx, 0Ch
		jmp .top_loop
	.done_loop:
	.fail:
	pop ecx
	pop ebx
	xor eax, eax
	ret 8
	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
_strcmp: ;;;int _strcmp(esi:s1, edi:s2)

	;mov esi, dword [esp + 4]
	;mov edi, dword [esp + 8]
	
	.ltop:
		mov al, byte [esi]	
		sub al, byte [edi]
		jne .ldone
		
		cmp byte [esi], 0
		je .ldone
		
		inc esi
		inc edi
		jmp .ltop
	.ldone:
	
	ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
BtlInterrupt00: ;;;;should be an exception trap
	push ds
	push es
	pushad
	mov byte [0B8000h], 'I'
	mov byte [0B8001h], 015h
	mov byte [0B8002h], 'N'
	mov byte [0B8003h], 015h
	mov byte [0B8004h], 'T'
	mov byte [0B8005h], 015h
	mov byte [0B8006h], ' '
	mov byte [0B8007h], 015h
	mov byte [0B8008h], '0'
	mov byte [0B8009h], 015h
	mov byte [0B800Ah], '!'
	mov byte [0B800Bh], 015h
	popad
	pop es
	pop ds
	iret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
BtlInterrupt0d: 
	;push ds
	;push es
	;pushad
	xchg bx, bx
	mov byte [0B8000h], 'G'
	mov byte [0B8001h], 015h
	mov byte [0B8002h], 'P'
	mov byte [0B8003h], 015h
	mov byte [0B8004h], 'F'
	mov byte [0B8005h], 015h
	mov byte [0B8006h], ' '
	mov byte [0B8007h], 015h
	mov byte [0B8008h], '!'
	mov byte [0B8009h], 015h
	mov byte [0B800Ah], '!'
	mov byte [0B800Bh], 015h
	;isr13halt:
	;jmp isr13halt     ;;;;???       EIP        CS        ??? 
	add esp, 4
	;popad              ;  0x43     0x821f     0x08     0x10202
	;pop es
	;pop ds
	iret
	
	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
BtlIrq00:
	mov al, 20h
	out 20h, al
	iret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
BtlIrq01:
	in al, 60h
	mov byte [0B8000h], al
	mov byte [0B8001h], 015h
	
	mov al, 20h
	out 20h, al
	iret
	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
BtlIrq06:
	mov al, 20h
	out 20h, al
	iret
	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
BtlRemapPIC: ;;;void BtlRemapPIC()
	in al, 021h ;master
	mov cl, al
	in al, 0A1h ;slave
	mov ch, al
	
	;init
	mov al, 011h
	out 020h, al           
	out 080h, al ;wait
	out 0A0h, al
	out 080h, al
	
	;new pic irq bases
	mov al, 020h
	out 021h, al
	out 080h, al
	mov al, 028h
	out 0A1h, al
	out 080h, al
	
	;continue init
	mov al, 4
	out 021h, al
	out 080h, al
	mov al, 2
	out 0A1h, al
	out 080h, al
	
	mov al, 1
	out 021h, al
	out 080h, al
	out 0A1h, al
	out 080h, al
	
	;reset masks
	mov al, cl
	out 021h, al
	mov al, ch
	out 0A1h, al
	ret
	
	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;; GDT ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

align 8

GDT:
NULL_GDT:
	dw 0000h	;limit_low
	dw 0000h	;base_low	
	db 00h		;base_middle 	
	db 00h		;access
	db 00h		;granularity
	db 00h		;base_high

CS_GDT:
	dw 0FFFFh
	dw 00h
	db 00h
	db 10011010b ;cs access: execute/read 9A
	db 0CFh
	db 00h

DS_GDT:
	dw 0FFFFh
	dw 00h
	db 00h
	db 10010010b ;ds access: read/write 92
	db 0CFh
	db 00h	
	
GDT_DESC:
	dw (GDT_DESC - GDT - 1)
	dd GDT

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;; IDT ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;struct IDTDescr{
;   uint16 offset_1; // offset bits 0..15
;   uint16 selector; // a code segment selector in GDT or LDT
;   uint8 zero;      // unused, set to 0
;   uint8 type_attr; // type and attributes, see below
;   uint16 offset_2; // offset bits 16..31
;}
align 8

IDT:
;;;; Exceptions
INT00_DESC:
	dw BtlInterrupt00
	dw 08h
	db 00h             ;;;pres | priv | sysseg | gatetype
	db 10001110b       ;;;[1]    [00]   [0]      [1110] (32 bit INT GATE)
	dw 0
	
times 8 * 12 db 0

INT0D_DESC:
	dw BtlInterrupt0d
	dw 08h
	db 00h
	db 10001110b
	dw 0
	
times 8 * 18 db 0 ;;;;should this be different?

;;;; IRQS
INT20_DESC:                 
	dw BtlIrq00
	dw 08h
	db 00h
	db 10001110b
	dw 0

IDT_DESC:
	dw (IDT_DESC - IDT - 1)
	dd IDT
	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;; STRINGS ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;strs_floppy_drive_type:
;	dd str_fdt_360k     ;;0x01
;	dd str_fdt_12m      ;;0x02
;	dd str_fdt_720k     ;;0x03
;	dd str_fdt_144m     ;;0x04
;	dd str_fdt_ibm      ;;0x05
;	dd str_fdt_288m     ;;0x06
;	dd str_fdt_atapirmd ;;0x10

;str_fdt_360k     db '360K', 0
;str_fdt_12m      db '1.2M', 0
;str_fdt_720k     db '720K', 0 
;str_fdt_144m     db '1.44M', 0
;str_fdt_ibm      db 'Weird IBM', 0 
;str_fdt_288m     db '2.88M', 0
;str_fdt_atapirmd db 'ATAPI Removable Media Device', 0

str_loaded       db 'RY/UX Stage II Bootloader', 0Dh, 0Ah, 0

str_a20_enabled  db 'A20 line enabled', 0Dh, 0Ah, 0
str_kern_loading db 'loading kernel image', 0Dh, 0Ah, 0
str_flp_loading  db 'loading floppy driver', 0Dh, 0Ah, 0

str_err_getdp    db 'BtlGetDriveParams int 13h ah=8 failed', 0Dh, 0Ah, 0
str_err_loadmod  db 'BtlLoadModule failed', 0Dh, 0Ah, 0

hexstr           db '0123456789abcdef'
times 0x800-($-$$) db 0

