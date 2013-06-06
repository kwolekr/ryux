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
; cpu_features.asm - 
;    cpuid related functions
;

KrnCpuidGetCPUString: ;;[esp + 4] = buffer, return = addr of string without whitespace
	;;CALLING FUNCTION MUST VERIFY BUFFER LENGTH >= 48!
	mov edi, dword [esp + 4]
	
	mov eax, 80000002h
	cpuid
	mov [edi + 00], eax
	mov [edi + 04], ebx
	mov [edi + 08], ecx
	mov [edi + 12], edx
	
	mov eax, 80000003h
	cpuid
	mov [edi + 16], eax
	mov [edi + 20], ebx
	mov [edi + 24], ecx
	mov [edi + 28], edx
	
	mov eax, 80000004h
	cpuid 
	mov [edi + 32], eax
	mov [edi + 36], ebx
	mov [edi + 40], ecx
	mov [edi + 44], edx
	
	mov eax, edi
	.looptop:
		mov cl, byte [eax]
		cmp cl, 20h
		jne .outofloop
			test cl, cl
			jz .outofloop
				inc eax
				jmp .looptop
	.outofloop:
	
	ret 4
	
KrnCpuidPrintFeatures:
	mov esi, str01
	mov ch, 06h
	call _printstr
	
	mov edx, dword [cpuid1_edx]
	mov ch, 0Fh
	xor ebx, ebx
	.loop_top:
		bt edx, ebx
		jnc .not_present
			push ebx
			push edx
			
			mov esi, [strcpuid1_edx + ebx * 4]
			call _printstr
			
			mov ecx, 0F20h
			call _putc
			
			pop edx
			pop ebx
		.not_present:
		inc ebx
		cmp ebx, 32
	jne .loop_top
	
	mov ecx, 0F0Ah
	call _putc
	
	mov edx, dword [cpuid1_ecx]
	xor ebx, ebx
	.loop_top2:
		bt edx, ebx
		jnc .not_present2
			push ebx
			push edx
			
			mov esi, [strcpuid1_ecx + ebx * 4]
			call _printstr
			
			mov ecx, 0F20h
			call _putc
			
			pop edx
			pop ebx
		.not_present2:
		inc ebx
		cmp ebx, 32
	jne .loop_top2
	
	
	mov ecx, 0F0Ah
	call _putc
	ret
	
KrnCpuidRestrictFeatures:
	mov edx, dword [cpuid1_edx]
	and edx, 2000000h ;;sse available?
	jz .sse_not_supported
		mov dword [KrnScrollTextScreen], 90909090h
		mov byte [KrnScrollTextScreen + 4], 90h
	.sse_not_supported:
	
	ret

	fe_reserved: db "reserved", 0
	;edx:
	fe_fpu:  db "FPU", 0
	fe_vme:  db "VME", 0
	fe_de:   db "DE", 0
	fe_pse:  db "PSE", 0
	fe_tsc:  db "TSC", 0
	fe_msr:  db "MSR", 0
	fe_pae:  db "PAE", 0
	fe_mce:  db "MCE", 0
	fe_cx8:  db "CX8", 0
	fe_apic: db "APIC", 0
	;""
	fe_syse: db "SEP", 0
	fe_mtrr: db "MTRR", 0
	fe_pge:  db "PGE", 0
	fe_mca:  db "MCA", 0
	fe_cmov: db "CMOV", 0
	fe_pat:  db "PAT", 0
	fe_pse6: db "PSE36", 0
	fe_psn:  db "PSN", 0
	fe_cfl:  db "CFLUSH", 0
	;""
	fe_ds:   db "DS", 0
	fe_acpi: db "ACPI", 0
	fe_mmx:  db "MMX", 0
	fe_fxsr: db "FXSR", 0
	fe_sse:  db "SSE", 0
	fe_sse2: db "SSE2", 0
	fe_ss:   db "SS", 0
	fe_htt:  db "HTT", 0
	fe_tm:   db "TM", 0
	;""
	fe_pbe:  db "PBE", 0
	
	;ecx:

	fe_sse3: db "SSE3", 0
	fe_muld: db "PCLMULDQ", 0
	fe_dtes: db "DTES64", 0
	fe_moni: db "MONITOR", 0
	fe_dscl: db "DS-CPL", 0
	fe_vmx:  db "VMX", 0
	fe_smx:  db "SMX", 0
	fe_est:  db "EST", 0
	fe_tm2:  db "TM2", 0
	fe_s3e3: db "SSSE3", 0
	fe_cnxt: db "CNXT-ID", 0
	;""
	;""
	fe_cx16: db "CX16", 0
	fe_xtpr: db "xTPR", 0
	fe_pdcm: db "PDCM", 0
	;""
	;""
	fe_dca:  db "DCA", 0
	fe_se41: db "SSE4.1", 0
	fe_se42: db "SSE4.2", 0
	fe_x2ap: db "x2APIC", 0
	fe_movb: db "MOVBE", 0
	fe_popc: db "POPCNT", 0
	;""
	fe_aes:  db "AES", 0
	fe_xsav: db "XSAVE", 0
	fe_osxs: db "OSXSAVE", 0
	fe_avx:  db "AVX", 0
	;""
	;""
	;""
	
	align 4, db 0
	
	strcpuid1_edx:
		dd fe_fpu
		dd fe_vme
		dd fe_de
		dd fe_pse
		dd fe_tsc
		dd fe_msr
		dd fe_pae
		dd fe_mce
		dd fe_cx8
		dd fe_apic
		dd fe_reserved
		dd fe_syse
		dd fe_mtrr
		dd fe_pge
		dd fe_mca
		dd fe_cmov
		dd fe_pat
		dd fe_pse6
		dd fe_psn
		dd fe_cfl
		dd fe_reserved
		dd fe_ds
		dd fe_acpi
		dd fe_mmx
		dd fe_fxsr
		dd fe_sse
		dd fe_sse2
		dd fe_ss
		dd fe_htt
		dd fe_tm
		dd fe_reserved
		dd fe_pbe
	
	strcpuid1_ecx:
		dd fe_sse3
		dd fe_muld
		dd fe_dtes
		dd fe_moni
		dd fe_dscl
		dd fe_vmx
		dd fe_smx
		dd fe_est	
		dd fe_tm2
		dd fe_s3e3
		dd fe_cnxt
		dd fe_reserved
		dd fe_reserved
		dd fe_cx16
		dd fe_xtpr
		dd fe_pdcm
		dd fe_reserved
		dd fe_reserved
		dd fe_dca
		dd fe_se41
		dd fe_se42
		dd fe_x2ap
		dd fe_movb
		dd fe_popc
		dd fe_reserved
		dd fe_aes
		dd fe_xsav
		dd fe_osxs
		dd fe_avx
		dd fe_reserved
		dd fe_reserved
		dd fe_reserved

