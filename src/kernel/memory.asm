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
; memory.asm - 
;    Memory management subsystem
;

struc memmap
	.baseaddr	 resd 1
	.baseaddr_hi resd 1
	.length		 resd 1
	.length_hi	 resd 1
	.type	     resd 1
endstruc

%define physmem_bitmap 40000h

;[SECTION .data]
highest_usable_addr dd 0
memmap_nentries     dd 0
memmap_base:
	times 20 * 32 db 0

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


;[SECTION .code]

KrnEnablePaging: ;;;void KrnEnablePaging()
	;mov cr3, page_directory
	
	;mov eax, cr4
	;or eax, 0x00000010 ;enable 4mb pages
	;mov cr4, eax
	
	mov eax, cr0
	or eax, 80000000h  ;enable paging
	mov cr0, eax
	ret

MemPhysInitBitmap: ;;;void MemPhysInitBitmap()
	;;; 4GB = 4 * 1024^3, a page == 4 * 1024. therfore 1024^2 pages total.
	;;; 8 bits per byte, so 1024^2 / 8 = number of bytes for the memory bitmap.
	
	; get last available block:
	;for (i = 0; i != nentries; i++) {
	;   if (entry[i].type == 1)
	;		lastfree = i;
	;}
	
	mov ebx, memmap_base
	mov ecx, dword [memmap_nentries]
	.looptop:
		cmp dword [ebx + memmap.type], 1
		jne .not_avail
			mov eax, dword [ebx + memmap.baseaddr]
			add eax, dword [ebx + memmap.length]
		.not_avail:
		add ebx, 20
		dec ecx
	jnz .looptop
	mov dword [highest_usable_addr], eax
	
	sub eax, physmem_bitmap
	mov ecx, eax
	mov edi, physmem_bitmap
	call _clearmem128
	
	xor edx, edx
	mov ebx, memmap_base
	mov ecx, dword [memmap_nentries]
	.looptop2:
		cmp dword [ebx + memmap.type], 1
		je .not_reserved
			mov eax, dword [ebx + memmap.baseaddr]
			mov ecx, dword [ebx + memmap.length]
			call MemPhysMarkAddrRange
		.not_reserved:
		
		mov ecx, dword [ebx + memmap.baseaddr]
		sub ecx, edx
		jz .no_entry_gap
			mov eax, edx
			call MemPhysMarkAddrRange
		.no_entry_gap:
		
		mov edx, dword [ebx + memmap.baseaddr]
		add ebx, 20
		dec ecx
	jnz .looptop2
	
	;reserved and unlisted are to be marked
	;int lastaddrboundry = 0;
	;for (i = 0; i != nentries; i++) {
	;	if (entry[i].type != 1)	{
	;		for (j = (entry[i].addr >> 12);
	;            j != ((entry[i].addr + entry[i].len) >> 12);
    ;		   	 j++)
	;			mark(j);
	;	}
	; let's say memlen = 0 and the first entry starts at entry[i].addr.
	; we want to mark at 0 for 9000h-0h pages
	; then there's a section of memory, 9000h-a000h that's fine
    ; then there's a section of memory, c000h-whatever that's fine	
	;	int runlen = entry[i].addr - lastaddrboundry;
	;   if (runlen) {
	;		for (j = lastaddrboundary; j != entry[i].addr; j++)
	;       	mark(j);
	;   }
	
	xor eax, eax			;;0x0000-0x1000 IVT
	call MemPhysMarkPageUsed

	mov eax, 1				;;0x1000-0x2000 bios/memory map parameter area
	call MemPhysMarkPageUsed
	
	mov eax, 3				;;0x3000-0x4000 physical kernel stack
	call MemPhysMarkPageUsed
	
	mov eax, 10h			;;0x10000-0x14000 kernel
	call MemPhysMarkPageUsed
	mov eax, 11h
	call MemPhysMarkPageUsed
	mov eax, 12h
	call MemPhysMarkPageUsed
	mov eax, 13h
	call MemPhysMarkPageUsed
	
	mov eax, 30h			 ;;0x30000-0x31000 fdc driver
	call MemPhysMarkPageUsed
	
	ret
	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
MemPhysMarkPageUsed: ;;;void MemPhysMarkPageUsed(eax:addr);
	;;;; index = (address / 4096)
	;;;; bitmap[index / 32] |= (1 << (index & 31));
	;;;; SSE accelerate this later on!
	mov ecx, eax
	
	and ecx, 1Fh
	mov ebx, 1
	shl ebx, cl 
	
	shr eax, 5 
	or dword [physmem_bitmap + eax * 4], ebx
	
	ret
	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
MemPhysMarkAddrRange: ;;;void MemPhysMarkAddrRange(eax:baseaddr, ecx:length)
	;ebx will be my bitmap base
	;edx will be my subword len
	;esi is my whatever register
	;edi is if it's necessary to align the length
	;eax is the index
	
	push ebp
	mov ebp, esp
	sub esp, 8
	
	push ebx
	push edx
	push esi
	push edi
	
	xor edi, edi
	test ecx, 0xFFF
	jz .no_partial_block
		inc edi
	.no_partial_block:
	shr ecx, 12
	shr eax, 12
	
	mov ebx, eax
	and ebx, 31
	mov edx, 32
	sub edx, ebx
	
	cmp ecx, edx
	jge .len_big_enough
		mov edx, ecx
	.len_big_enough:
	sub ecx, edx
	
	mov esi, 1
	add edx, edi
	;shl esi, dl ;invalid operand
	dec esi
	;shl esi, bl ;invalid operand
	shr eax, 5
	or dword [physmem_bitmap + eax * 4], esi
	
	inc eax
	mov esi, ecx
	shr esi, 5
	add esi, eax

	.fill_loop_top:
		cmp eax, esi
		je .fill_loop_done
		
		mov dword [physmem_bitmap + eax * 4], 0xFFFFFFFF
		inc eax
		
		jmp .fill_loop_top
	.fill_loop_done:
	
	and ecx, 31
	jz .no_remaining_bits
		mov esi, 1
		shl esi, cl
		dec esi
		or dword [physmem_bitmap + eax * 4], esi
	.no_remaining_bits:
	
	pop edi
	pop esi
	pop edx
	pop ebx
	
	ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
MemPhysIsMarked: ;;;;int MemPhysIsMarked(eax:addr)
	push ebx
	
	mov ecx, eax
	and ecx, 31
	mov ebx, 1
	shl ebx, cl
	
	shr eax, 5
	mov eax, dword [physmem_bitmap + eax * 4]
	
	and eax, ebx
	pop ebx
	ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
MemPhysAlloc: ;;;;; stack param: number of pages

	ret 4

MemPhysFree:
	ret
	
MemAddPageDirectory:
	mov ecx, dword [pagedir_num]
	
	and ebx, 0FFFFF000h
	
	;;TODO: Finish this
	
	inc ecx
	mov dword [pagedir_num], ecx
	ret
	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
MemCalcMemMapSize: ;;;stack params: 
;;ptr to phys mem containing the records, number of records
;;;returns eax: good mem, edx: bad mem
	xor eax, eax
	xor edx, edx
	
	mov ebx, dword [esp + 04h]
	mov ecx, dword [esp + 08h]
	
	push esi
	
	.MemCalcMemMap_top:	
		
		mov esi, dword [ebx + memmap.type]
		cmp esi, 1
		je .goodmem
		cmp esi, 3
		je .goodmem
			add edx, dword [ebx + memmap.length]
			jmp .overgoodmem
		.goodmem:
			add eax, dword [ebx + memmap.length]
		.overgoodmem:
		
		add ebx, 20
		dec ecx
	jnz .MemCalcMemMap_top
	
	pop esi
	ret 8

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;	
printmemmap:
	mov ch, 07h
	mov esi, str04
	call _puts
	
	;mov ebx, 1100h
	;movzx ecx, word [1008h]
	mov ebx, memmap_base
	mov ecx, dword [memmap_nentries]
	.printmemmap_top:
		push ecx
		push ebx
		
		push dword [ebx + memmap.type]
		push dword [ebx + memmap.length]
		push dword [ebx + memmap.baseaddr]
		push str05
		call _printf
		add esp, 16
		
		pop ebx
		pop ecx
		
		add ebx, 20
		dec ecx
	jnz .printmemmap_top

	ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
MemPhysTreeInit:
	;;N.B.
	;; The physical memory allocation tree has been dropped in favor of a bitmap

	push 1000h
	push 1000h ;;;bios stuff table
	call MemPhysTreeAdd ;;;;
	
	push 4000h
	push 10000h ;;;kernel
	call MemPhysTreeAdd ;;;;
	
	push 1000h
	push 30000h ;;;fdc driver
	call MemPhysTreeAdd	;;;;

	push 2000h
	push 20000h ;;;main thread stack
	call MemPhysTreeAdd ;;;;
	
	ret

MemPhysTreeAdd: ;;parameters: LPTNODE startnode, LPTNODE newnode
	mov eax, dword [esp + 4]
	mov edx, dword [esp + 8]
	.looptop:
		mov eax, dword [edx] ;;len
		test eax, eax
		jz .loopdone
		mov ecx, dword [ebx]
		cmp dword [eax], ecx
		jbe .lowerorequal
			lea edx, [eax + 8] ;;lchild
			jmp .looptop
		.lowerorequal:
			lea edx, [eax + 12] ;;rchild
			jmp .looptop
	.loopdone:
	mov dword [edx], ebx
	ret 8
	
