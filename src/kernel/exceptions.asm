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

;
; exceptions.asm - 
;    Interrupt handlers for exceptions (int 00h-20h)
;

ExcUDIsr:
	pusha
	
	mov dword [screen_row], 1
	and dword [screen_col], 0
	
	mov ch, 07h
	mov esi, str10
	call _printstr
	
	;;0  0 16 3
	push 03110000h
	call KrnDrawTextRect
	
	mov bl, 17h
	push 03110000h
	call KrnSetTextAttributeRect

	.lol:
		hlt
	jmp .lol
	popa
	iret ;interrupts here
	
ExcNMIIsr:
	push str09
	call _printstr
	cli
	.halt:
		hlt
	jmp .halt
	sti
	iret
	
ExcDFIsr:
	xchg bx, bx
	pop eax ;;; eax = error code
	iret

ExcGPIsr:		
	push ebp
	mov ebp, esp
	
	xchg bx, bx
	
	mov dword [screen_row], 1
	and dword [screen_col], 0
	
	mov ecx, 0501h
	call KrnTextClearLines
	
	;+4  = error
	;+8  = eip
	;+12 = cs
	;+16 = eflags
	
	push dword [ebp + 4]  ;error
	push dword [ebp + 16] ;eflags
	push dword [ebp + 8]  ;eip
	push dword [ebp + 12] ;cs
	push str06
	call _printf
	add esp, 20

	push 06500000h
	call KrnDrawTextRect
	
	mov bl, 17h
	push 06500000h
	call KrnSetTextAttributeRect

	;xchg bx, bx
	;call KrnShutdownSystem
	
	cli
	.isr13halt:
		hlt
	jmp .isr13halt
	add esp, 4
	;;;;;;remember to fix up stack better!
	
; 31         16   15         3   2   1   0
;+---+--  --+---+---+--  --+---+---+---+---+
;|   Reserved   |    Index     |  Tbl  | E |
;+---+--  --+---+---+--  --+---+---+---+---+
; Length  Name  Description  
;E  1 bit  External  When set, the exception originated externally to the processor.  
;Tbl  2 bits  IDT/GDT/LDT table  This is one of the following values: Value  Description  
;0b00  The Selector Index references a descriptor in the GDT.  
;0b01  The Selector Index references a descriptor in the IDT.  
;0b10  The Selector Index references a descriptor in the LDT.  
;0b11  The Selector Index references a descriptor in the IDT.  
 
;Index  13 bits  Selector Index  The index in the GDT, IDT or LDT.  

	;popad              ;  0x43     0x821f     0x08     0x10202
	;pop es
	;pop ds
	iret
ExcPFIsr:
	mov byte [0B8000h], 'P'
	mov byte [0B8001h], 15h
	mov byte [0B8002h], 'F'
	mov byte [0B8003h], 15h
	
	mov eax, cr2
	and eax, 0FFFFF000h
	;;eax = faulting addr
	
	add esp, 0Ch
	iret
	
