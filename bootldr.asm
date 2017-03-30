;
; MBL - Minimal Boot Loader for 80C188EB project board
;
; Copyright (c) 2005-2017, Arto Merilainen (arto.merilainen@gmail.com)
; All rights reserved.
;
; Redistribution and use in source and binary forms, with or without
; modification, are permitted provided that the following conditions are met
;
; 1. Redistributions of source code must retain the above copyright notice,
;    this list of conditions and the following disclaimer.
; 2. Redistributions in binary form must reproduce the above copyright notice,
;    this list of conditions and the following disclaimer in the documentation
;    and/or other materials provided with the distribution.
;
; THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
; AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
; IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
; ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
; LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
; CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
; SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
; INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
; CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
; ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
; POSSIBILITY OF SUCH DAMAGE.

;
; This bootloader makes minimal initialization to the hardware, loads an
; application from UART to RAM and starts executing it.
;
; The initializations include:
; * UCS signal is configured to enable EEPROM when there is an access to area
;   0xFF800-0xFFFFF
; * LCS signal is configured to enable RAM when there is an access to area
;   0x00000-0x20000
; * Interrupt vector is initialized to point to an "iret" instruction at
;   0xFFFFF.
; * Stack pointers are initialized to end of RAM (0x1FFFF)
; * UART0 is initialized (9600bps, 8 databits, 1 stopbits)
; * 4 least significant lines in P1 are configured as outputs
;

; Beginning of EEPROM.
	org 0xF800

;
; Initialize rest of the memory chip selection signals and interrupt vectors.
;
; This routine gets called from END of this file. The boot vector for 80C188EB
; if 0xFFFF0.
;

begin:	; Setup end of EEPROM
	mov dx, 0xFFA6
	mov ax, 0x000E
	out dx, al

	; Setup start of RAM
	mov dx, 0xFFA0
	mov ax, 0x0000
	out dx, al

	; Setup end of RAM
	mov dx, 0xFFA2
	mov ax, 0x200A
	out dx, al

	;
	; Initialize all interrupts to be handled by an iret.
	; Check end of this file.
	;
	mov ax, 0
	mov es, ax
	mov di, 0
	mov cx, 256
.setint:
	mov ax, 0xFFFF
	stosw
	mov ax, 0xF000
	stosw
	loop .setint

	; Set up the stack
	mov ax, 0x1000
	mov ss, ax
	mov sp, 0xFFFF

	; Start executing the application loader
	jmp start

;
; Few UART helper functions
;

; Initialize the serial line
serial_init:
	push dx
	push ax
	mov ax, 0x8067
	mov dx, 0xFF60
	out dx, ax
	mov ax, 0x0021
	mov dx, 0xFF64
	out dx, ax
	pop ax
	pop dx
	ret

; Send the character at AL to UART0
serial_putch:
	push dx
	push ax
	mov dx, 0xFF66
.w	in  al,dx
	test al,8
	jz .w
	pop ax
	mov dx, 0xFF6A
	out dx, al
	pop dx
	ret


; Read a single char from UART0. Result is returned in AL
serial_getc:
	push dx
.w	mov dx, 0xFF66
	in al, dx
	test al,40h
	jz .w
	mov dx, 0xFF68
	in al, dx
	pop dx
	ret

;
; The start of "application". All required initializations are done and this
; could be any application (which you can fit into 2KB :-))
;
start:
	;
	; Turn LED0 on to indicate that the CPU is alive
	;

	mov dx, 0xFF56
	mov al, 1110b
	out dx, al
	mov dx, 0xFF54
	mov al, 0xF0
	out dx, al

	; Initialize the serial port
	call serial_init

	; Inform that the application is ready
	mov al, '>'
	call serial_putch

	;
	; Load 2KB from the serial port
	;

	; Set up loop register to 2KB
	mov cx, 0x0800
	; Set target segment register
	mov ax, 0x0000
	mov es, ax
	; Set the offset within the segment (0x800)
	mov di, 0x0800

	; Load the application
.read	call serial_getc
	stosb
	loop .read

	; Start executing the application
	jmp 0x0000:0x0800

;
; Make the binary 2KB to allow easy programming to the EEPROM.
; Note that we need 16 bytes free at end of the EEPROM for
; storing the CPU reset routine.
;

Main_Size	equ	$ - begin
times (0x7F0 - Main_Size) db 0

;
; The code execution starts from here: 80C188EB starts code execution
; from 0xffff0
;

boot:	cli

	; Setup end of EEPROM
	mov dx, 0xFFA4
	mov ax, 0xFF80
	out dx, al

	; Start execution at beginning of this file
	jmp begin

Boot_Size		equ $ - boot
times (0x0F - Boot_Size) db 0

;
; The dummy interrupt handler
;

iret_int:
	 iret
