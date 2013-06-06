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
; syscall.asm - 
;    Syscall setup, registration and handling
;


KrnSetupSystemCalls:	
	mov eax, 1
	cpuid
	test edx, 20h ;;msrs supported?
	jz .sep_not_supported
		test edx, 800h ;;syscall supported?
		jz .sep_not_supported
			xor eax, eax
			cpuid
			cmp ecx, 'DMAc' ;;AuthenticAMD
			je .setup_amd
				;;;;Intel's SYSENTER/SYSEXIT
			
				xor edx, edx
			
				mov ecx, 174h
				mov eax, 8
				wrmsr ;;target cs/ss
				
				inc ecx
				mov eax, 0 ;;;;;;;;;;;;;; temporary
				wrmsr ;;target esp
				
				inc ecx
				mov eax, KrnSysEnter
				wrmsr ;;target eip
				
				ret
			.setup_amd:
				;;;;AMD's SYSCALL/SYSRET
			
				mov edx, 00080008h  ;;target cs/ss
				mov eax, KrnSysCall ;;target eip
				mov ecx, 0c0000081h
				wrmsr
				
				ret
	.sep_not_supported:
	
		push 10001110b         ;;;;;;FIXME
		push KrnSysInterrupt
		push 2eh
		call KrnInsertIDTEntry
	
	ret
	
KrnSysCall:
	xor eax, eax
	sysret
	
KrnSysEnter:
	xor eax, eax
	sysexit
	
KrnSysInterrupt:
	xor eax, eax
	iret
	
