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
; crt.asm - 
;    Kernel-mode C Runtime Library that implements a subset of the C standard.
;


_strlen: ;;;int _strlen(esi:string)
	mov eax, esi
	._strlen_top:
		cmp byte [eax], 0
		je ._strlen_done
		inc eax
		jmp ._strlen_top
	._strlen_done:
	sub eax, esi
	ret
	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
_strcpy: ;;;void _strcpy(esi:src, edi:dest)
		mov al, byte [esi]
		mov byte [edi], al
		inc esi
		inc edi
		test al, al
	jnz _strcpy
	ret
	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
_strcmp: ;;;int _strcmp(esi:s1, edi:s2)
		mov al, byte [esi]	
		sub al, byte [edi]
		jne .ldone
		
		cmp byte [esi], 0
		je .ldone
		
		inc esi
		inc edi
		jmp _strcmp
	.ldone:
	ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
_memcpy8: ;;;void _memcpy8(esi:src, edi:dest, ecx:len)
	test ecx, ecx
	jz ._memcpy8_done
		mov al, byte [esi]
		mov byte [edi], al
		
		inc esi
		inc edi
		dec ecx
		jmp _memcpy8
	._memcpy8_done:
	ret
	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
_memcpy: ;;;void _memcpy8(esi:src, edi:dest, ecx:len)
	mov eax, ecx
	shr ecx, 2
	rep movsd
	mov ecx, eax
	and ecx, 3
	rep movsb
	ret
	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
_memcpy128: ;;;void _memcpy8(esi:src, edi:dest, ecx:len)
	mov eax, ecx
	shr ecx, 4
	test ecx, ecx
	jz .cpy128_done
	.cpy128_top:
		movss xmm0, [esi]
		movss [edi], xmm0
		add esi, 16
		add edi, 16
		dec ecx
	jmp .cpy128_top
	.cpy128_done:
	
	and eax, 0Fh
	test eax, eax
	jz .cpyrest_done
	.cpyrest_top:
		mov cl, byte [esi]
		mov byte [edi], cl
		inc esi
		inc edi
		dec eax
		jnz .cpyrest_top
	.cpyrest_done:
	ret
	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
_memset128: ;;;eax = value, edi = dest, ecx = count
	;movd xmm0, eax
	;movlhps xmm0, xmm0
	mov ah, al
	shl eax, 8
	mov al, ah
	shl eax, 8
	mov al, ah
	pinsrd xmm0, eax, 0
	pinsrd xmm0, eax, 1
	pinsrd xmm0, eax, 2
	pinsrd xmm0, eax, 3
	
	push ecx
	shr ecx, 4
	test ecx, ecx
	jz .set16_done
	.set16_loop:
		movaps [edi], xmm0
		add edi, 16
		dec ecx
		jnz .set16_loop
	.set16_done:
	
	pop ecx
	and ecx, 0Fh
	test ecx, ecx
	jz .setrest_done
	.setrest_loop:
		mov byte [edi], al
		inc edi
		dec ecx
		jnz .setrest_loop
	.setrest_done:
	ret
	
_clearmem128:
	xorps xmm0, xmm0
	shr ecx, 4
	test ecx, ecx
	jz .set16_done
	.set16_loop:
		movaps [edi], xmm0
		add edi, 16
		dec ecx
		jnz .set16_loop
	.set16_done:
	ret
	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
_atoi:  ;;;;;;esi = input str, eax = return value  (assume base = 10)
	 ;;;;;;;NEEDS TESTING

	xor eax, eax ;;;eax = return value
	xor edx, edx
	xor ecx, ecx
	xor ebx, ebx ;;;ebx = accumulator
	
	not ecx
	repne scasb
	not ecx      
	dec ecx  ;;;ecx = strlen  
	
	inc edi  ;;;edi = multiplier
	
	._atoi_top:
		mov al, byte [esi + ecx]
		sub eax, 30h
		mul edi
		
		add ebx, eax
		
		lea edi, [edi + edi * 4]  ;;multiply by 5
		add edi, edi              ;;multiply by 2.. VOILA!
		
		dec ecx	
		test ecx, ecx
	jnb ._atoi_top
	ret
	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
_itoa: ;;;;;edi = str, eax = value, ecx = base
	push edi
	
	._itoa_top:	
		xor edx, edx
		div ecx
		mov bl, byte [itoastr + edx]
		mov byte [edi], bl
		inc edi
		test eax, eax
	jnz ._itoa_top
	
	mov byte [edi], al
	pop eax
	dec edi

	._itoa_strrev_top:
		mov bl, byte [eax]
		xchg byte [edi], bl
		mov byte [eax], bl
		inc eax
		dec edi
		cmp eax, edi
	jl ._itoa_strrev_top
	ret
	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
_hitoa: ;;;edi = output, ebx = input
	xor ecx, ecx
	
	._hitoa_top:
		mov eax, 0x0F
		shl eax, cl
		shl eax, cl
		
		mov edx, ebx
		and edx, eax
		
		shr edx, cl 
		shr edx, cl
		
		mov al, byte [itoastr + edx]
		mov byte [edi + ecx], al
		
		inc ecx
		cmp ecx, 8
	jne ._hitoa_top
	
	ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
_printf: ;;;void _cdecl _printf(fmt, ...)
	.fmt:      equ 8
	
	.curparam: equ 20
	.minlen:   equ 24
	
	push ebp
	mov ebp, esp
	sub esp, 24

	and dword [ebp - .curparam], 0
	mov ebx, dword [ebp + .fmt]
	
	.loop_top:
		mov al, byte [ebx]
		test al, al
		jz near .loop_done
		
		cmp al, '%'
		jne near .not_marker
			mov dword [ebp - .minlen], 8
			inc ebx
			mov al, byte [ebx]
			
			sub al, '0'
			cmp al, '9' - '0'
			jg .not_numeric
				movzx eax, al
				mov dword [ebp - .minlen], eax
				inc ebx
				mov al, byte [ebx]
			.not_numeric:
			mov al, byte [ebx]
			
			sub al, 'c'
			cmp al, 'x' - 'c'
			jg near .loop_cont
			
			movzx eax, al
			movzx eax, byte [.jmp_table + eax]

			jmp dword [.jmp_table2 + eax * 4] 
				.default:
					jmp .loop_cont
					
				.case_c:
					mov ecx, dword [ebp - .curparam]
					mov cl, byte [ebp + ecx * 4 + 0Ch]
					mov ch, 07h
					call _putc
					
					inc dword [ebp - .curparam]
					jmp .loop_cont
					
				.case_d:
				.case_i:
					push ebx
					
					mov eax, dword [ebp - .curparam]
					mov eax, dword [ebp + eax * 4 + 0Ch]
					mov ecx, 10
					lea edi, [ebp - 16]
					call _itoa
					
					pop ebx
					
					mov ch, 07h
					lea esi, [ebp - 16]
					call _printstr
					
					inc dword [ebp - .curparam]
					jmp .loop_cont
					
				.case_o:
				
					push ebx
					
					mov eax, dword [ebp - .curparam]
					mov eax, dword [ebp + eax * 4 + 0Ch]
					mov ecx, 8
					lea edi, [ebp - 16]
					call _itoa
					
					pop ebx
					
					mov ch, 07h
					lea esi, [ebp - 16]
					call _printstr
					
					inc dword [ebp - .curparam]
					jmp .loop_cont
					
				.case_s:
					mov ch, 07h
					
					mov esi, dword [ebp - .curparam]
					mov esi, dword [ebp + esi * 4 + 0Ch]
					call _printstr
					
					inc dword [ebp - .curparam]
					jmp .loop_cont
					
				.case_x:		
					push ebx
					;;;xchg bx,bx;;;;
					mov ebx, dword [ebp - .curparam]
					mov ebx, dword [ebp + ebx * 4 + 0Ch]
					mov ecx, dword [ebp - .minlen] ;8
					.hitoa_top:
						mov eax, 0x0F
						
						push ecx
						
						dec ecx
						shl ecx, 2    ; create mask 
						shl eax, cl   ; for nibble to
						mov edx, ebx  ; print out
						and edx, eax  ;
						
						shr edx, cl
						mov ch, 07h
						mov cl, byte [itoastr + edx]
						call _putc	
						
						pop ecx
						
						dec ecx
					jnz .hitoa_top
					
					pop ebx
					inc dword [ebp - .curparam]
					jmp .loop_cont
		.not_marker:
			mov cl, al
			mov ch, 07h
			call _putc ;eax and edx thrashed
		
		.loop_cont:
		
		inc ebx
		jmp .loop_top
	.loop_done:
	
	mov esp, ebp
	pop ebp
	ret
	
	.jmp_table:
		db 1 ;c
		db 2 ;d
		db 0 ;e
		db 0 ;f
		db 0 ;g
		db 0 ;h
		db 2 ;i
		db 0 ;j
		db 0 ;k
		db 0 ;l
		db 0 ;m
		db 0 ;n
		db 3 ;o
		db 0 ;p
		db 0 ;q
		db 0 ;r
		db 4 ;s
		db 0 ;t
		db 0 ;u
		db 0 ;v
		db 0 ;w
		db 5 ;x
	.jmp_table2:
		dd .default
		dd .case_c
		dd .case_d
		dd .case_o
		dd .case_s ;; 88 vs... 42 :D
		dd .case_x
	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
_putc: ;;;;;;;cl = character, ch = color
	cmp cl, 0Ah
	je ._putc_new_line
		mov eax, dword [screen_row]
		;mov edx, 80
		;mul edx
		lea eax, [eax + eax * 4]
		shl eax, 4
		add eax, dword [screen_col]
		mov word [0B8000h + eax * 2], cx
		mov eax, dword [screen_col]      
		inc eax
		cmp eax, 80
		jb ._putc_over
	._putc_new_line:
		mov eax, dword [screen_row]
		inc eax
		cmp eax, 25
		jne .no_scroll
			call KrnScrollTextScreenSSE_p
			dec eax
		.no_scroll:
		mov dword [screen_row], eax
		xor eax, eax
	._putc_over:
		mov dword [screen_col], eax
	ret
	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
_puts: ;;;;;;esi = string, ch = color
		mov cl, byte [esi]
		call _putc
		inc esi
		cmp byte [esi], 0
	jne _puts	
	mov cl, 0Ah
	call _putc
	ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
_printstr: ;;;;;;esi = string, ch = color
		mov cl, byte [esi]
		call _putc
		inc esi
		cmp byte [esi], 0
	jne _printstr	
	ret
	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
_clear:
	mov ecx, 1000
	xor eax, eax
	mov edi, 0B8000h
	rep stosd
	ret

