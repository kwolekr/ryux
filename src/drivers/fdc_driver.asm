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
; fdc_driver.asm - 
;    Driver for standard PS2 and AT floppy disk controllers
;    Started on 8/10/09
;

;#define STATUS_REG_A            0x0000 /*PS2 SYSTEMS*/
;#define STATUS_REG_B            0x0001 /*PS2 SYSTEMS*/
;#define DIGITAL_OUTPUT_REG      0x0002
;#define MAIN_STATUS_REG         0x0004
;#define DATA_RATE_SELECT_REG    0x0004 /*PS2 SYSTEMS*/
;#define DATA_REGISTER           0x0005
;#define DIGITAL_INPUT_REG       0x0007 /*AT SYSTEMS*/
;#define CONFIG_CONTROL_REG      0x0007 /*AT SYSTEMS*/
;#define PRIMARY_RESULT_STATUS   0x0000
;#define SECONDARY_RESULT_STATUS 0x0000

 ;enum FloppyRegisters {
 ;   STATUS_REGISTER_A        = 0x3F0, // read-only
 ;   STATUS_REGISTER_B        = 0x3F1, // read-only
 ;   DIGITAL_OUTPUT_REGISTER  = 0x3F2,
 ;   TAPE_DRIVE_REGISTER      = 0x3F3,
 ;   MAIN_STATUS_REGISTER     = 0x3F4, // read-only
 ;   DATA_RATE_SELECT_REGISTER= 0x3F4, // write-only
 ;   DATA_FIFO                = 0x3F5,
 ;   DIGITAL_INPUT_REGISTER   = 0x3F7, // read-only
 ;   CONFIGURATION_CONTROL_REGISTER = 0x3F7, //write only
 ;};
 
 ; enum FloppyCommands {
 ;   READ_TRACK = 2,
 ;   SPECIFY = 3,
 ;   SENSE_DRIVE_STATUS = 4,
 ;   WRITE_DATA = 5,
 ;   READ_DATA = 6,
 ;   RECALIBRATE = 7,
 ;   SENSE_INTERRUPT = 8,
 ;   WRITE_DELETED_DATA = 9,
 ;   READ_ID = 10,
 ;   READ_DELETED_DATA = 12,
 ;   FORMAT_TRACK = 13,
 ;   SEEK = 15,
 ;   VERSION = 16,
 ;   SCAN_EQUAL = 17,
 ;   PERPENDICULAR_MODE = 18,
 ;   CONFIGURE = 19,
 ;   VERIFY = 22,
 ;   SCAN_LOW_OR_EQUAL = 25,
 ;   SCAN_HIGH_OR_EQUAL = 29,
 ;};

; Useful links:
;	http://bos.asmhackers.net/docs/floppy/docs/floppy_tutorial.txt
;   http://koders.com/c/fid051291340B94EC7F5D1A38EF6843466C0B07627B.aspx?s=fdc

%include "src/ryux.inc"

[BITS 32]
[ORG 0x30000]
_header:
	dd 'ryux'
	dd 1
	dd _file_end - _header
	dd 30000h
	
	dd 'code'
	dd _code_section
	dd _code_section_end - _code_section
	dd SECT_PRES | PROT_EXEC | PROT_READ
	
	dd 'data'
	dd _data_section
	dd _data_section_end - _data_section
	dd SECT_PRES | PROT_READ | PROT_WRITE
	
	dd 'rdat'
	dd 0
	dd 0
	dd 0
	
	dd 'impt'
	dd _import_section
	dd _import_section_end - _import_section
	dd SECT_PRES | PROT_READ | PROT_WRITE
	
	dd 'expt'
	dd 0 ;_export_section
	dd 0 ;_export_section_end - _export_section
	dd 0
	
	
_header_end:
	
_code_section:
FlpInit:	
	mov esi, 0fefc7h   ;;;copy parameter table
	mov edi, fd_params
	movsd
	movsd
	movsw
	movsb

	push 10001110b
	push FlpIrqIsr
	push 26h
	call dword [KrnInsertIDTEntry]
	
	mov dx, 03F2h
	mov al, 0
	out dx, al ;;;reset the floppy disk controller
	mov al, 0Ch
	out dx, al
	
	call FlpWaitForInterrupt
	
	call FlpInitDMA
	
	ret
	
FlpInitDMA:
	mov al, 6   ;mask channel 2
	out 0Ah, al
	
	mov al, 0FFh
	out 0D8h, al ;reset flipflop
	
	xor al, al 
	out 4, al   ;set address at 6000h
	mov al, 60h
	out 4, al
	
	mov al, 0FFh
	out 0D8h, al
	
	out 5, al
	mov al, 23h ;set length for 0x23FF
	out 5, al
	
	xor al, al
	out 80h, al
	
	mov al, 2   ;unmask channel 2
	out 0Ah, al
	
	ret
	
FlpInitDMARead:
	mov al, 6
	out 0Ah, al
	
	mov al, 56h
	out 0Bh, al
	
	mov al, 2
	out 0Ah, al

	ret
	
FlpInitDMAWrite:
	mov al, 6
	out 0Ah, al

	mov al, 5Ah
	out 0Bh, al
	
	mov al, 2
	out 0Ah, al

	ret

FlpIrqIsr:
	;pushad
	cli
	mov dword [flpint], 1
	add esp, 0Ch
	sti
	;popad
	iret

FlpWaitForInterrupt:
	cmp dword [flpint], 0
	je FlpWaitForInterrupt	
	and dword [flpint], 0
	ret
	
FlpRead:

	call FlpInitDMARead
	
	ret

FlpWrite:
	
	call FlpInitDMAWrite
	
	ret

_code_section_end:

align 16, db 0
	
_data_section:

fd_params:
	steprate_headunload db 0
	headload_ndma	    db 0
	motor_delay_off     db 0 ; clock tick intervals
	bytes_per_sector    db 0	
	sectors_per_track   db 0
	gap_length          db 0
	data_length         db 0 ; only used when bytes_per_sector = 0
	format_gap_length   db 0
	filler              db 0
	head_settle_time    db 0 ; millisecond intervals
	motor_start_time    db 0 ; 1/8th second intervals
end_fd_params:

flpint dd 0 

_data_section_end:

align 16, db 0

_import_section:

	dd 1
	
	dd imstr
	dd 1
	dd _kernel_imports

	_kernel_imports:
		dd 1
		dd imstr0
		KrnInsertIDTEntry dd 0

	;;import stringpool
	imstr:  dd 'kernel', 0
	imstr0: db 'KrnInsertIDTEntry', 0

_import_section_end:

align 16, db 0

_export_section:

_export_section_end:

times 0x1000-($-$$) db 0
_file_end:

