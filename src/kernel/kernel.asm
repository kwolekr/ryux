;
; Copyright (c) 2009 Ryan Kwolek
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

; kernel.asm -
;    Main file of the RY/UX kernel.  Contains KrnMain among other initialization code.
;    Started on 1/23/09
;

;;my executable format:

;; (DWORD) signature    = 'ryux'
;; (DWORD) version      = 1
;; (DWORD) total length = 0x1000
;; (DWORD) preferred base addr = 0x10000

;; (DWORD) section name = 'code'
;; (DWORD) section start
;; (DWORD) section length
;; (DWORD) section prot flags

;Physical memory layout
; 0x0000-0x0400   IVT
; 0x1000-0x1180   RealMode stuff                    ;;not necessary after kernel load
; 0x2000-0x6000   Disk load buffer (for bootloader) ;;
; 0x3000-0x4000   Kernel stack                      
; 0x7c00-0x8000   Stage I Bootloader                ;;
; 0x8000-0x8800   Stage II Bootloader               ;;
; 0x10000-0x14000 Kernel
; 0x30000-0x31000 FDC driver
; 0x31000-0x32000 ATA driver
; 0x40000-0x60000 Physical memory bitmap

; 0x50000 - 0x60000: 24 bit DMA read/write area

; Bochs debugger:
; http://bochs.sourceforge.net/doc/docbook/user/internal-debugger.html
;

%include "src/ryux.inc"

struc biosinfo
	.bootdrive: resb 1  ;boot drive  
	.uselba:	resb 1  ;able to use lba?
	.getdp_cx:	resw 1  ;cx from getdriveparams
	.getdp_dx:	resw 1  ;dx from getdriveparams
	.nmmapents: resw 1  ;number of mem map entries
endstruc

%define biosstuff  1000h
%define memmap_tmp 1100h

[BITS 32]
[ORG 0x10000]
;[SECTION .header]
_header:
	dd 'ryux'
	dd 1
	dd 4000h ;_file_end - _header
	dd 10000h
	
	dd 'code'
	dd _code_section
	dd _code_section_end - _code_section
	dd SECT_PRES | PROT_EXEC | PROT_READ
	
	dd 'data'
	dd _data_section
	dd _data_section_end - _data_section
	dd SECT_PRES | PROT_READ | PROT_WRITE
	
	dd 'rdat'
	dd _readonly_data_section
	dd _readonly_data_section_end - _readonly_data_section
	dd SECT_PRES | PROT_READ
	
	dd 'impt'
	dd 0
	dd 0
	dd 0
	
	dd 'expt'
	dd _export_section
	dd _export_section_end - _export_section
	dd SECT_PRES | PROT_READ
_header_end:

;[SECTION .text]
_code_section:
KrnMain:
	sub esp, 64 ;;be sure to clear up stack
	
	push 10001110b
	push KrnSystemTickIsr
	push 20h
	call KrnInsertIDTEntry
	
	push 10001111b
	push ExcGPIsr
	push 0Dh
	call KrnInsertIDTEntry
	
	push 10001111b
	push ExcDFIsr
	push 08h
	call KrnInsertIDTEntry
	
	push 10001111b
	push ExcUDIsr
	push 06h
	call KrnInsertIDTEntry
	
	push 10001111b
	push ExcNMIIsr
	push 02h
	call KrnInsertIDTEntry
	
	lidt [idt_desc]	
	
	mov eax, cr4
	or eax, 600h ;;;;;;enables SSE stuff -- only do this if it's in cpuid!
	mov cr4, eax     ;;fine for now, though
	
	;;;;copy bios stuff over
	movzx ecx, word [biosstuff + biosinfo.nmmapents]
	mov dword [memmap_nentries], ecx
	
	mov esi, memmap_tmp
	mov edi, memmap_base
	lea ecx, [ecx * 4 + ecx]
	rep movsd
	
	;;;;;;;;;;;;;;;;;;;;;;;;;
	
	call KrnGetRTCTime
	
	call KrnGetCursorPos
	mov dword [screen_row], eax
	mov dword [screen_col], edx
	
	mov cl, 0Ah
	mov ch, 00h
	call _putc
	
	;esi = string, ch = color
	mov ch, 07h
	mov esi, str00
	call _puts
	
	movzx eax, byte [time_second]
	push eax
	movzx eax, byte [time_minute]
	push eax
	movzx eax, byte [time_hour]
	push eax
	movzx eax, byte [time_year]
	push eax
	movzx eax, byte [time_day]
	push eax
	movzx eax, byte [time_month]
	push eax
	push str_fmt_time
	call _printf
	add esp, 28
	
	push 100
	call KrnSetPITFreq
	
	mov ch, 06h
	mov esi, str02
	call _printstr

	;;;;;;;display cpu vendor
	xor eax, eax
	cpuid       ;;eax = highest standard cpuid fxn supported
	mov dword [ebp - 16], ebx
	mov dword [ebp - 12], edx
	mov dword [ebp - 8], ecx
	mov dword [ebp - 4], 0
	lea esi, [ebp - 16]
	mov ch, 0Fh
	call _puts
	
	;;;;;;;;;;display cpu string
	
	mov ch, 06h
	mov esi, str07
	call _printstr
	
	lea eax, [ebp - 48]
	push eax
	call KrnCpuidGetCPUString
	mov esi, eax
	mov ch, 0Fh
	call _puts
	
	;;;;;;;;;;;;;nop dword [eax + eax * 1 + 0]
	
	;;;;;;;;;;get processor features	
	mov eax, 1
	cpuid
	mov dword [cpuid1_ecx], ecx
	mov dword [cpuid1_edx], edx
	
	call KrnCpuidPrintFeatures
	call KrnCpuidRestrictFeatures
	
	;;;;;;;;calculate size of memory

	xchg bx, bx;;;;;
	movzx eax, word [1008h]
	push eax
	push 1100h
	call MemCalcMemMapSize
	
	add edx, eax
	
	shr edx, 10
	shr eax, 10

	push eax
	push edx
	push str03
	call _printf
	add esp, 12
	
	call printmemmap
	
	;call MemPhysInitBitmap
	xchg bx, bx
	mov edx, 10h
	.l1_top:
		mov ebx, 10h
		.l2_top:
			;mov eax, addr
			;call MemPhysIsMarked
			mov cl, '0'
			;test eax, eax
			;jz .not_set
			;	inc cl
			;.not_set:
			mov ch, 0Dh
			call _putc
			
			dec ebx
		jnz .l2_top
		mov cx, 000Ah
		call _putc
		dec edx
	jnz .l1_top
	
	;call KrnInitMemoryManager
	
	add esp, 64
	.1:
		hlt
	jmp .1
	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
KrnInitMemoryManager:
	call MemPhysTreeInit
	
	push 10001111b
	push ExcPFIsr
	push 0Eh
	call KrnInsertIDTEntry
	
	;mov eax, PAGE_DIRS
	;call KrnEnablePaging
	
	ret
	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
KrnSetPITFreq: ;;stack parameters: desired frequency | lowest = 19 Hz
	mov al, 36h ;;[00][11][011][0] 16-bit binary, operating mode 3, access mode: lobyte/hibyte, channel 0
	out 43h, al ;;;port 43h == PIT mode register 
	
	xor edx, edx
	mov eax, 1193180
	div dword [esp + 4]
	
	out 40h, al
	mov al, ah
	out 40h, al

	ret 4

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
KrnLoadDriverLL: ;;stack parameters: CHS, Device name

	;;.................load stuff
	
	mov eax, dword [esi]
	cmp esi, 'ryux'
	jne .KrnLoadDriver_LL_failure
	
	.KrnLoadDriver_LL_failure:
	xor eax, eax
	
	
	ret 8
	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
KrnInsertIDTEntry: ;;stack parameters: interrupt number, offset, type and attributes
	mov ecx, dword [esp + 4]
	lea ebx, [idt + ecx * 8]
	
	mov ecx, dword [esp + 8]
	and ecx, 0FFFFh
	mov word [ebx], cx
	
	mov ecx, dword [esp + 8]
	and ecx, 0FFFF0000h
	shr ecx, 16
	mov word [ebx + 6], cx
	
	mov word [ebx + 2], 8 

	and byte [ebx + 4], 0	
	mov ecx, dword [esp + 12]
	mov byte [ebx + 5], cl	
	
	ret 0Ch
	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
KrnRebootSystem:
	;lidt [bogus_idt_desc]
	.not_ready:
		in al, 64h
		and al, 2
	jnz .not_ready
	mov al, 0FEh
	out 64h, al
	.halt:
		hlt
	jmp .halt

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
KrnShutdownSystem:
	;mov eax, cr0
	;and eax, 7FFFFFFEh
	;mov cr0, eax
	cli
	mov ax, 0Fh
	out 70h, al  ;;cmos address register
	
	out 0EDh, ax ;;; for an I/O delay
	
	mov ax, 5
	out 71h, al  ;;cmos memory register

	mov word [467h], (.realmodeexec - 10000h)
	mov word [469h], 1000h
	call KrnRebootSystem
	
	[BITS 16]
	
	.realmodeexec:
	mov ax, 4201h
	int 15h
	
	.halt:
		hlt
	jmp .halt
	
	[BITS 32]
	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
KrnSystemTickIsr:
	cli
	push eax
	;xchg bx,bx
	;in al, 20h ;;spurious ISR check
	;test al, 80h
	;jz .isspurious
	
	mov eax, dword [systemtick]
	inc eax
	cmp eax, 200
	jne .not_a_second
		;pushad
		
		;mov ch, 06h
		;mov esi, str_hello
		;call _printstr
		
		;popad
		
		xor eax, eax
	.not_a_second:
	mov dword [systemtick], eax
	
	;.isspurious:
	
	mov al, 20h    ;;;;nonspecific EOI (specific = 60h!)
	out 20h, al    ;;;;send to the slave too for the other isrs > 7!
	
	pop eax	
	sti
	iret
	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
KrnGetRTCTime: ;;;void KrnGetRTCTime()
	;;70h == RTC address reg
	;;71h == RTC data reg
	.polling:
		mov al, 10  ;;status reg A
		out 70h, al
		in al, 71h
		test al, 80h ;;is it currently updating?
	jnz .polling
	
	mov al, 0  ;;seconds
	out 70h, al
	in al, 71h
	mov byte [time_second], al
	
	mov al, 2  ;;minutes
	out 70h, al
	in al, 71h
	mov byte [time_minute], al
	
	mov al, 4  ;;hours
	out 70h, al
	in al, 71h
	mov byte [time_hour], al
	
	mov al, 7  ;;day of month
	out 70h, al
	in al, 71h
	mov byte [time_day], al
	
	mov al, 8  ;;month
	out 70h, al
	in al, 71h
	mov byte [time_month], al
	
	mov al, 9  ;;year
	out 70h, al
	in al, 71h
	mov byte [time_year], al
	
	ret

%include "src/kernel/syscall.asm"
%include "src/kernel/screen.asm"
%include "src/kernel/cpu_features.asm"
%include "src/kernel/exceptions.asm"
%include "src/kernel/memory.asm"
%include "src/kernel/crt.asm"

_code_section_end:
align 16, db 0
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;[SECTION .data]
_data_section:

idt:
	times 8 * 64 db 0
idt_desc:
	dw (idt_desc - idt - 1)
	dd idt

systemtick  dd 0
uptime      dd 0

time_second db 0
time_minute db 0
time_hour   db 0
time_day    db 0
time_month  db 0
time_year   db 0

screen_row 	dd 0
screen_col  dd 0

cpuid1_ecx  dd 0
cpuid1_edx  dd 0



;;;;;physmem allocation


;;;;paged memory allocation
pagedir_num dd 0

_data_section_end:

align 16, db 0

_readonly_data_section:

	itoastr: db '0123456789abcdefghijklmnopqrstuvwxyz', 0
	str00:   db 'RY/UX Operating System, version 0.1 (c) Ryan Kwolek 2008, 2009, 2011', 0
	str02:   db 'Vendor: ', 0
	str07:   db 'CPU String: ', 0
	str03:	 db 'Detected %d kb of ram, %d usable', 0Ah, 0
	str04:	 db '--addr--|--size--|type', 0
	str05:	 db '%x|%x|%d', 0Ah, 0
	str06:	 db ' General Protection Fault!', 0Ah, ' EIP: %4x:%x', 0Ah, ' EFLAGS: 0x%x', 0Ah, ' Error: 0x%x', 0
	str01:   db 'Features: ', 0
	str08:   db 'ABORT: Double Fault!', 0
	str09:   db 'Non-maskable Interrupt!!!', 0
	str10:	 db ' Invalid opcode!', 0
	str_hello: db 'hello!', 0
	str_fmt_time db '%2x/%2x/%2x %2x:%2x:%2x', 0Ah, 0
	
_readonly_data_section_end:

align 16, db 0
	
_export_section:
	dd 2

	dd 1
	dd exstr1
	dd KrnInsertIDTEntry
	
	dd 2
	dd exstr2
	dd KrnLoadDriverLL
	
	;;export string pool
	exstr1:	db 'KrnInsertIDTEntry', 0
	exstr2:	db 'KrnLoadDriverLL', 0
_export_section_end:
;notes:
; selector = entryoffset | (ldt ? 4 : 0) | rpl;
;
;
;
	
times 0x4000-($-$$) db 0
_file_end:

;dd 'link'

;;;local exports
;dd 3
;dd KrnMain
;dd KrnLoadDriverLL
;dd KrnInsertIDTEntry
;db 'KrnMain', 0
;db 'KrnLoadDriverLL', 0
;db 'KrnInsertIDTEntry', 0

;;; local imports
;[SECTION .refs]

