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
; screen.asm - 
;    Text mode video buffer functions
;


KrnSetCursorPos: ;;stack params: [esp + 4] = row, [esp + 8] = column
	mov al, 0fh
	mov dx, 3d4h
	out dx, al
	
	mov eax, dword [esp + 4]
	lea eax, [eax + eax * 4]
	shl eax, 4
	
	add eax, dword [esp + 8]
	
	inc dx
	out dx, al
	
	mov al, 0eh
	dec dx
	out dx, al
	
	shr al, 8
	inc dx
	out dx, al
	
	ret 8
	
KrnGetCursorPos:
	
	mov eax, 0eh
	mov dx, 3d4h
	out dx, al
	
	inc dx
	in al, dx  ;;;high
	mov ah, al
	
	mov al, 0fh
	dec dx
	out dx, al
	
	inc dx
	in al, dx ;;;low
	
	mov ecx, 80
	xor edx, edx
	div ecx
	
	;;;;return:
	;;;;eax = row
	;;;;edx = column
	
	ret

KrnScrollTextScreen:
	;db 0e9h
	;dd KrnScrollTextScreenSSE_p - KrnScrollTextScreen_p
	jmp KrnScrollTextScreen_p
	
	;mov eax, width
	;mul height
	
	mov ecx, eax
	
	;mov esi, srcbuf
	shr eax, 2
	add esi, eax
	
	;mov edi, destbuf
	sub eax, ecx
	add edi, eax
	
top:
	prefetchnta [esi - 128]
	
	movdqa xmm0, [esi - 0]
	movdqa xmm1, [esi - 16]
	movdqa xmm2, [esi - 32]
	movdqa xmm3, [esi - 48]
	movdqa xmm4, [esi - 64]
	movdqa xmm5, [esi - 80]
	movdqa xmm6, [esi - 96]
	movdqa xmm7, [esi - 112]
	
	pextrw eax, xmm0, 0
	pextrw ebx, xmm0, 1
	pextrw ecx, xmm0, 2
	pextrw edx, xmm0, 3
	mov [edi - 0], eax
	mov [edi - 3], ebx
	mov [edi - 6], ecx
	mov [edi - 9], edx
	pextrw eax, xmm1, 0
	pextrw ebx, xmm1, 1
	pextrw ecx, xmm1, 2
	pextrw edx, xmm1, 3
	mov [edi - 12], eax
	mov [edi - 15], ebx
	mov [edi - 18], ecx
	mov [edi - 21], edx
	pextrw eax, xmm2, 0
	pextrw ebx, xmm2, 1
	pextrw ecx, xmm2, 2
	pextrw edx, xmm2, 3
	mov [edi - 24], eax
	mov [edi - 27], ebx
	mov [edi - 30], ecx
	mov [edi - 33], edx
	pextrw eax, xmm3, 0
	pextrw ebx, xmm3, 1
	pextrw ecx, xmm3, 2
	pextrw edx, xmm3, 3
	mov [edi - 36], eax
	mov [edi - 39], ebx
	mov [edi - 42], ecx
	mov [edi - 45], edx
	pextrw eax, xmm4, 0
	pextrw ebx, xmm4, 1
	pextrw ecx, xmm4, 2
	pextrw edx, xmm4, 3
	mov [edi - 48], eax
	mov [edi - 51], ebx
	mov [edi - 54], ecx
	mov [edi - 57], edx
	pextrw eax, xmm5, 0
	pextrw ebx, xmm5, 1
	pextrw ecx, xmm5, 2
	pextrw edx, xmm5, 3
	mov [edi - 60], eax
	mov [edi - 63], ebx
	mov [edi - 66], ecx
	mov [edi - 69], edx
	pextrw eax, xmm6, 0
	pextrw ebx, xmm6, 1
	pextrw ecx, xmm6, 2
	pextrw edx, xmm6, 3
	mov [edi - 72], eax
	mov [edi - 75], ebx
	mov [edi - 78], ecx
	mov [edi - 81], edx
	pextrw eax, xmm7, 0
	pextrw ebx, xmm7, 1
	pextrw ecx, xmm7, 2
	pextrw edx, xmm7, 3
	mov [edi - 84], eax
	mov [edi - 87], ebx
	mov [edi - 90], ecx
	mov [edi - 93], edx

	sub esi, 128
	sub edi, 96
	
	;cmp esi, srcbuf
	jnz top

;;;sse does 30 reps vs movsd's 960
KrnScrollTextScreenSSE_p: ;;;;guarenteed register preservation
	push esi
	xor esi, esi
	
	.loop_top:
		prefetchnta [0b8000h + esi + 128]
		
		movaps xmm0, [0b8000h + esi + (160 + 0)]
		movaps xmm1, [0b8000h + esi + (160 + 16)]
		movaps xmm2, [0b8000h + esi + (160 + 32)]
		movaps xmm3, [0b8000h + esi + (160 + 48)]
		movaps xmm4, [0b8000h + esi + (160 + 64)]
		movaps xmm5, [0b8000h + esi + (160 + 80)]
		movaps xmm6, [0b8000h + esi + (160 + 96)]
		movaps xmm7, [0b8000h + esi + (160 + 112)]
		
		movaps [0b8000h + esi + 0], xmm0
		movaps [0b8000h + esi + 16], xmm1
		movaps [0b8000h + esi + 32], xmm2
		movaps [0b8000h + esi + 48], xmm3
		movaps [0b8000h + esi + 64], xmm4
		movaps [0b8000h + esi + 80], xmm5
		movaps [0b8000h + esi + 96], xmm6
		movaps [0b8000h + esi + 112], xmm7
		
		sfence
		add esi, 128 
		cmp esi, (80 * 24 * 2)
	jne .loop_top
	
	;;pxor xmm0, xmm0 ;;pxor breaks compat, need sse2
	xorps xmm0, xmm0
	movaps [0b8000h + (80 * 24 * 2) + 0], xmm0
	movaps [0b8000h + (80 * 24 * 2) + 16], xmm0
	movaps [0b8000h + (80 * 24 * 2) + 32], xmm0
	movaps [0b8000h + (80 * 24 * 2) + 48], xmm0
	movaps [0b8000h + (80 * 24 * 2) + 64], xmm0
	movaps [0b8000h + (80 * 24 * 2) + 80], xmm0
	movaps [0b8000h + (80 * 24 * 2) + 96], xmm0
	movaps [0b8000h + (80 * 24 * 2) + 112], xmm0
	movaps [0b8000h + (80 * 24 * 2) + 128], xmm0
	movaps [0b8000h + (80 * 24 * 2) + 144], xmm0
	
	pop esi
	ret
	
KrnScrollTextScreen_p:  ;;;;guarenteed register preservation
	push eax
	push ecx
	push esi
	push edi
	
	cld
	
	mov ecx, 24 * 80 * 2
	mov edi, 0b8000h
	mov esi, 0b8000h + 80 * 2
	rep movsd
	
	xor eax, eax
	mov ecx, 80 * 2
	mov edi, 0b8000h + 24 * 80 * 2
	rep stosd
	
	pop edi
	pop esi
	pop ecx
	pop eax
	
	ret
	
KrnSetTextAttributeRect:
 ;;;bl = attribute byte
 ;;;stack param: BYTERECT [left | top | right | bottom]
	movzx edx, byte [esp + 5]
	.loopy_top:
		movzx ecx, byte [esp + 4]
		.loopx_top:
			;;; (((dl * 80) + ecx) * 2)
			movzx eax, dl
			lea eax, [eax + eax * 4]
			shl eax, 4
			add eax, ecx
			add eax, eax
			mov byte [0b8000h + eax + 1], bl
			inc ecx 
			cmp cl, byte [esp + 6]
		jl .loopx_top
		inc edx
		cmp dl, byte [esp + 7]
	jl .loopy_top
	ret 4
	
		                                  ;;4      5      6       7
KrnDrawTextRect: ;;stack param: BYTERECT {left | top | right | bottom}
	;BAh = vertical double bar
	;CDh = horiz double bar
	;BBh = top right corner
	;C8h = bottom left corner
	;C9h = top left corner
	;BCh = bottom right corner

	movzx edi, byte [esp + 5]
	movzx eax, byte [esp + 4]
	
	lea edi, [edi + edi * 4] ;mul by 5
	shl edi, 4               ;mul by 16 (5 * 16 = 80)
	add edi, eax			 ;add column offset
	add edi, edi  			 ;double it all
	add edi, 0b8000h
	
	mov word [edi], 07C9h
	add edi, 2

	movzx eax, byte [esp + 4]
	movzx ebx, byte [esp + 7]
	dec ebx
	lea ebx, [ebx + ebx * 4]
	shl ebx, 4
	add ebx, eax
	add ebx, ebx
	
	mov al, byte [esp + 6]
	sub al, 2
	mov cl, byte [esp + 4]
	.top:
		mov word [edi], 07CDh
		mov word [edi + ebx], 07CDh
		
		add edi, 2	
		inc ecx
		cmp cl, al
	jne .top
	
	mov word [edi], 07BBh
	add edi, 2			
	
	add edi, 160
	movzx eax, byte [esp + 6]
	sub edi, eax
	sub edi, eax
	
	mov al, byte [esp + 7]
	sub al, 2
	mov cl, byte [esp + 5]
	movzx edx, byte [esp + 6]
	
	.top2:
		mov word [edi], 07BAh
		mov word [edi + edx * 2 - 2], 07BAh
		
		add edi, 160
		inc ecx
		cmp cl, al
	jne .top2
	
	mov word [edi], 07C8h
	mov word [edi + edx * 2 - 2], 07BCh
			
	ret 4
	
KrnTextClearLines: ;;;params: cl = lo bound, ch = hi bound
	;;;cl * 160 = cl * 5 * 32
	movzx eax, cl
	lea eax, [eax + eax * 4]
	shl eax, 5
	lea edi, [0b8000h + eax]
	
	sub ch, cl
	movzx eax, ch
	lea ecx, [eax + eax * 4]
	shl ecx, 3
	
	xor eax, eax
	
	rep stosd
	
	ret
	
