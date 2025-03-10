;
; File:
;                          entry.asm
; Description:
;                      System call entry code
;
;                       Copyright (c) 1998
;                       Pasquale J. Villani
;                       All Rights Reserved
;
; This file is part of DOS-C.
;
; DOS-C is free software; you can redistribute it and/or
; modify it under the terms of the GNU General Public License
; as published by the Free Software Foundation; either version
; 2, or (at your option) any later version.
;
; DOS-C is distributed in the hope that it will be useful, but
; WITHOUT ANY WARRANTY; without even the implied warranty of
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See
; the GNU General Public License for more details.
;
; You should have received a copy of the GNU General Public
; License along with DOS-C; see the file COPYING.  If not,
; write to the Free Software Foundation, 675 Mass Ave,
; Cambridge, MA 02139, USA.
;
; $Id: entry.asm 1701 2012-01-16 22:06:21Z perditionc $
;

                %include "segs.inc"
                %include "stacks.inc"
                %include "nec98cfg.inc"

segment HMA_TEXT
                extern   _int21_syscall
                extern   _int21_service
                extern   _int2526_handler
%ifdef NEC98
                extern   _int29_main
                extern   _intdc_main
                extern   _in_processing_stopkey
                extern   _clear_attr
                extern   _put_attr
                extern   _cursor_view
                extern   _fd98_retract_hd_pending
                extern   _nec98_flush_bios_keybuf
%endif
                extern   _error_tos
                extern   _char_api_tos
                extern   _disk_api_tos
                extern   _user_r
                extern   _ErrorMode
                extern   _InDOS
                extern   _cu_psp
                extern   _MachineId
                extern   critical_sp

                extern   int21regs_seg
                extern   int21regs_off

                extern   _Int21AX

                extern  _DGROUP_

                global  reloc_call_cpm_entry
                global  reloc_call_int20_handler
                global  reloc_call_int21_handler
                global  reloc_call_low_int25_handler
                global  reloc_call_low_int26_handler
                global  reloc_call_int27_handler
%ifdef NEC98
                global  reloc_call_int29_handler
                global  reloc_call_intdc_handler
                global  reloc_call_unhandled_int_handler
%endif

;
; MS-DOS CP/M style entry point
;
;       VOID FAR
;       cpm_entry(iregs UserRegs)
;
; For CP/M compatibility allow a program to invoke any DOS API function
; between 0 and 24h by doing a near call to psp:0005h which embeds a far call
; to absolute address 0:00C0h (int vector 30h & 31h) or FFFF:00D0 (hma).
; 0:00C0h contains the jmp instruction to reloc_call_cpm_entry which should
; be duplicated in hma to ensure correct operation with either state of A20 line.
; Note: int 31h is also used for DPMI but only in protected mode.
; Upon entry the stack has a near return offset (desired return address offset)
; and far return seg:offset (desired return segment of PSP, and useless offset
; which if used will return to the data, not code, at offset 0ah after far call
; in psp). We convert it to a normal call and correct the stack to appear same
; as if invoked via an int 21h call including proper return address.
;
reloc_call_cpm_entry:
                ; Stack is:
                ;       return offset
                ;       psp seg
                ;       000ah
                ;
                add     sp, byte 2      ; remove unneeded far return offset 0ah
                pushf                   ; start setting up int 21h stack
                ;
                ; now stack is
                ;       return offset
                ;       psp seg
                ;       flags
                ;
                push    bp
                mov     bp,sp           ; set up reference frame
                ;
                ; reference frame stack is
                ;       return offset           bp + 6
                ;       psp seg                 bp + 4
                ;       flags                   bp + 2
                ;       bp              <---    bp
                ;
                push    ax
                mov     ax,[2+bp]        ; get the flags
                xchg    ax,[6+bp]        ; swap with return address
                mov     [2+bp],ax
                pop     ax              ; restore working registers
                pop     bp
                ;
                ; Done. Stack is
                ;       flags
                ;       psp seg (alias .COM cs)
                ;       return offset
                ;
                cmp     cl,024h         ; restrict calls to functions 0-24h
                ja      cpm_error
                mov     ah,cl           ; get the call # from cl to ah
                jmp     reloc_call_int21_handler    ; do the system call
cpm_error:      mov     al,0
                iret                    ; cleanup stack and return to caller

;
; interrupt zero divide handler:
; print a message 'Interrupt divide by zero'
; Terminate the current process
;
;       VOID INRPT far
;       int20_handler(iregs UserRegs)
;

print_hex:      mov     cl, 12
hex_loop:
                mov     ax, dx                             
                shr     ax, cl
                and     al, 0fh
                cmp     al, 10
                sbb     al, 69h
                das
%ifdef NEC98
                int     29h
%else
;IBMPC
                mov     bx, 0070h
                mov     ah, 0eh
                int     10h
%endif
                sub     cl, 4
                jae     hex_loop
                ret

%ifdef NEC98
%ifndef UNHANDLED_INT_HANDLER_IN_IOSYS
print_hex8:     mov cl, 4
                jmp short hex_loop

print_str:      mov al, [cs: si]
                test al, al
                jz .ret
                int 29h
                inc si
                jmp short print_str
.ret:
                ret

unhandled_int_message1:
                db 0dh,0ah
                db 'PANIC - Unhandled INT ', 0
unhandled_int_messagev:
                db '??'
unhandled_int_message2:
                db 'h. Stack:', 0dh, 0ah, 0

reloc_call_unhandled_int_handler:
                mov si, unhandled_int_message1
                call print_str
                push bp
                mov bp, sp
                push ds
                lds si, [bp + 2]
                mov dx, [si - 2]
                pop ds
                pop bp
                mov si, unhandled_int_messagev
                cmp dl, 0cdh		; int xxh?
                jne .l2
                xchg dl, dh
                call print_hex8
                mov si, unhandled_int_message2
.l2:
                jmp short zero_message_loop
%endif ; !UNHANDLED_INT_HANDLER_IN_IOSYS
%endif ; NEC98

divide_by_zero_message db 0dh,0ah,'Interrupt divide by zero, stack:',0dh,0ah,0

                global reloc_call_int0_handler
reloc_call_int0_handler:
                
                mov si,divide_by_zero_message

zero_message_loop:
                mov al, [cs:si]
                test al,al
                je   zero_done

                inc si
%ifdef NEC98
                int 29h
%else
;IBMPC
                mov bx, 0070h
                mov ah, 0eh
                
                int  10h
%endif
                
                jmp short zero_message_loop
                
zero_done:
                mov bp, sp              
                xor si, si         ; print 13 words of stack for debugging LUDIV etc.
stack_loop:             
                mov dx, [bp+si]
                call print_hex
                mov al, ' '
%ifdef NEC98
                int 29h
%else
;IBMPC
                int 10h
%endif
                inc si
                inc si
                cmp si, byte 13*2
                jb stack_loop
%ifdef NEC98
                mov al, 0dh
                int 29h
                mov al, 0ah
                int 29h
%else
;IBMPC
                mov al, 0dh
                int 10h
                mov al, 0ah
                int 10h
%endif
                                                                                                
                mov ax,04c7fh       ; terminate with errorlevel 127                                                
                int 21h
                sti
thats_it:       hlt
                jmp short thats_it  ; it might be command.com that nukes

%ifndef INT6_HANDLER_IN_IOSYS
invalid_opcode_message db 0dh,0ah,'Invalid Opcode at ',0

                global reloc_call_int6_handler
reloc_call_int6_handler:
%ifdef NEC98
                ; check whether STOP key is pressed(invoked by keyboard handler)
                push bp
                mov bp, sp
                push bx
                push ds
                lds bx, [bp + 2]          ; fetch return address
                cmp word [bx - 2], 06cdh  ; called with "int 06h"?
                jne .really_invalid_op
                ; STOP key handler (invoked by keyboard handler)
                ; when STOP key is pressed:
                ;  - retract heads of all HDD (SASI/SCSI)
                ;  - reset color of output character
                ;  - flush keybuff and send Ctrl-C to console
                ; or SHIFT + STOP is pressed:
                ;  - reset color of output character
                ;  - flush keybuff and send Ctrl-S to console
                push es
                xor bx, bx
                mov es, bx
                mov bl, 60h
                mov ds, bx
                cmp byte [_in_processing_stopkey], 0
                jne .press_stop_exit_injob
                mov byte [_in_processing_stopkey], 1
                mov bl, 13h
                test byte [es:053ah], 1               ; shift key pressed?
                jnz .press_stop_l2
                mov byte [_fd98_retract_hd_pending], 1
                push ax
                mov al, [_clear_attr]
                mov [_put_attr], al
                mov ax, 1101h
                mov [_cursor_view], al
                int 18h
                ; call _update_cursor_view
                pop ax
                mov bl, 03h
  .press_stop_l2:
                call far _nec98_flush_bios_keybuf
                mov byte [00c0h], bl                  ; push Ctrl-C/Ctrl-S to conin_buf
                mov byte [0103h], 1
                mov word [0104h], 00c0h
  .press_stop_exit:
                mov byte [_in_processing_stopkey], 0
  .press_stop_exit_injob:
                pop es
                pop ds
                pop bx
                pop bp
                iret
  .really_invalid_op:
                pop ds
                pop bx
                pop bp
%endif
                mov si,invalid_opcode_message
                jmp zero_message_loop        
%endif ; !INT6_HANDLER_IN_IOSYS

%ifdef IBMPC
                global reloc_call_int19_handler
reloc_call_int19_handler:
; from Japheth's public domain code (JEMFBHLP.ASM)
; restores int 10,13,15,19,1b and then calls the original int 19.
                cld
                xor ax,ax
                mov es,ax
                mov al,70h
                mov ds,ax
                mov si,100h
                mov cx,5
                cli
nextitem:       lodsb
                mov di,ax
%if XCPU >= 186
                shl di,2
%else
                shl di,1
                shl di,1
%endif
                movsw
                movsw
                loop nextitem
                int 19h
%endif

;
; Terminate the current process
;
;       VOID INRPT far
;       int20_handler(iregs UserRegs)
;
reloc_call_int20_handler:
                mov     ah,0            ; terminate through int 21h


;
; MS-DOS system call entry point
;
;       VOID INRPT far
;       int21_handler(iregs UserRegs)
;
reloc_call_int21_handler:
                cmp     ah,25h
                je      int21_func25
                cmp     ah,35h
                je      int21_func35
                ;
                ; Create the stack frame for C call.  This is done to
                ; preserve machine state and provide a C structure for
                ; access to registers.
                ;
                ; Since this is an interrupt routine, CS, IP and flags were
                ; pushed onto the stack by the processor, completing the
                ; stack frame.
                ;
                ; NB: stack frame is MS-DOS dependent and not compatible
                ; with compiler interrupt stack frames.
                ;
                sti
                PUSH$ALL
                mov bp,sp
                ;
                ; Create kernel reference frame.
                ;
                ; NB: At this point, SS != DS and won't be set that way
                ; until later when which stack to run on is determined.
                ;
int21_reentry:
                Protect386Registers
                mov     dx,[cs:_DGROUP_]
                mov     ds,dx

                cmp     ah,33h
                je      int21_user
                cmp     ah,50h
                je      int21_user
                cmp     ah,51h
                je      int21_user
                cmp     ah,62h
                jne     int21_1

int21_user:     
                call    dos_crit_sect

                push    ss
                push    bp
                call    _int21_syscall
                pop     cx
                pop     cx
                jmp     short int21_ret

int21_func25:
                push    es
                push    bx
                xor     bx,bx
                mov     es,bx
                mov     bl,al
                shl     bx,1
                shl     bx,1
                mov     [es:bx],dx
                mov     [es:bx+2],ds
                pop     bx
                pop     es
                iret

int21_func35:
                xor     bx,bx
                mov     es,bx
                mov     bl,al
                shl     bx,1
                shl     bx,1
                les     bx,[es:bx]
                iret

;
; normal entry, use one of our 4 stacks
; 
; DX=DGROUP
; CX=STACK
; SI=userSS
; BX=userSP


int21_1:
                mov si,ss   ; save user stack, to be retored later


                ;
                ; Now DS is set, let's save our stack for rentry (???TE)
                ;
                ; I don't know who needs that, but ... (TE)
                ;
                mov     word [_user_r+2],ss
                mov     word [_user_r],bp                         ; store and init

                ;
                ; Decide which stack to run on.
                ;
                ; Unlike previous versions of DOS-C, we need to do this here
                ; to guarantee the user stack for critical error handling.
                ; We need to do the int 24h from this stack location.
                ;
                ; There are actually four stacks to run on. The first is the
                ; user stack which is determined by system call number in
                ; AH.  The next is the error stack determined by _ErrorMode.
                ; Then there's the character stack also determined by system
                ; call number.  Finally, all others run on the disk stack.
                ; They are evaluated in that order.

                cmp     byte [_ErrorMode],0
                je      int21_2

int21_onerrorstack:                
                mov     cx,_error_tos


                cli
                mov     ss,dx
                mov     sp,cx
                sti
                
                push    si  ; user SS:SP
                push    bp
                
                call    _int21_service
                jmp     short int21_exit_nodec

                
int21_2:        inc     byte [_InDOS]
                mov     cx,_char_api_tos
                or      ah,ah   
                jz      int21_3
                cmp     ah,0ch
                jbe     int21_normalentry

int21_3:
                call    dos_crit_sect
                mov     cx,_disk_api_tos

int21_normalentry:

                cli
                mov     ss,dx
                mov     sp,cx
                sti

                ;
                ; Push the far pointer to the register frame for
                ; int21_syscall and remainder of kernel.
                ;
                
                push    si  ; user SS:SP
                push    bp
                call    _int21_service

int21_exit:     dec     byte [_InDOS]

                ;
                ; Recover registers from system call.  Registers and flags
                ; were modified by the system call.
                ;

                
int21_exit_nodec:
                pop bp      ; get back user stack
                pop si

                global  _int21_iret
_int21_iret:
                cli
                mov     ss,si
                RestoreSP

int21_ret:
                Restore386Registers
                POP$ALL

                ;
                ; ... and return.
                ;
                iret
;
;   end Dos Critical Section 0 thur 7
;
;
dos_crit_sect:
                mov     [_Int21AX],ax       ; needed!
                push    ax                  ; This must be here!!!
                mov     ah,82h              ; re-enrty sake before disk stack
                int     2ah                 ; Calling Server Hook!
                pop     ax
                ret

;
; Terminate the current process
;
;       VOID INRPT far
;       int27_handler(iregs UserRegs)
;
reloc_call_int27_handler:
                ;
                ; First convert the memory to paragraphs
                ;
                add     dx,byte 0fh     ; round up
                rcr     dx,1
                shr     dx,1
                shr     dx,1
                shr     dx,1
                ;
                ; ... then use the standard system call
                ;
                mov     ax,3100h
                jmp     reloc_call_int21_handler  ; terminate through int 21h

;
;

reloc_call_low_int26_handler:
                sti
                pushf
                push    ax
                mov     ax,026h
                jmp     short int2526
reloc_call_low_int25_handler:
                sti
                pushf
                push    ax
                mov     ax,025h
int2526:                
                push    cx
                push    dx
                push    bx
                push    sp
                push    bp
                push    si
                push    di
                push    ds
                push    es

                mov     cx, sp     ; save stack frame
                mov     dx, ss

                cld
                mov     bx, [cs:_DGROUP_]
                mov     ds, bx

                ; setup our local stack
                cli
                mov     ss,bx
                mov     sp,_disk_api_tos
                sti

                Protect386Registers
        
                push    dx
                push    cx                      ; save user stack

                push    dx                      ; SS:SP -> user stack
                push    cx
                push    ax                      ; was set on entry = 25,26
                call    _int2526_handler
                add     sp, byte 6

                pop     cx
                pop     dx                      ; restore user stack

                Restore386Registers

                ; restore foreground stack here
                cli
                mov     ss, dx
                mov     sp, cx

                pop     es
                pop     ds
                pop     di
                pop     si
                pop     bp
                pop     bx      ; pop off sp value
                pop     bx
                pop     dx
                pop     cx
                pop     ax
                popf
                retf            ; Bug-compatiblity with MS-DOS.
                                ; This function is supposed to leave the original
                                ; flag image on the stack.

%ifdef NEC98
;
; int 29h entry point
;
;       VOID INRPT far
;       int29_handler(iregs UserRegs)
;

 %ifdef USE_PRIVATE_INT29_STACK
                extern int29_stack_bottom
                global int29_stack_org      ; just for debugging
                global int29_stack_count    ; ditto

                align 2
int29_stack_org:
                dd 0
int29_stack_count:
                db 0
 %endif
 %ifdef USE_PRIVATE_INTDC_STACK
                extern intdc_stack_bottom
                global intdc_stack_org      ; just for debugging
                global intdc_stack_count    ; ditto

  %ifndef USE_PRIVATE_INT29_STACK
                align 2
  %endif
intdc_stack_count:
                db 0
intdc_stack_org:
                dd 0
 %endif

reloc_call_int29_handler:
 %ifdef USE_PRIVATE_INT29_STACK
                cli
                sub byte [cs: int29_stack_count], 1
                jnc .stk_set
                mov word [cs: int29_stack_org], sp
                mov word [cs: int29_stack_org + 2], ss
                mov sp, PSP ; 0060h
                mov ss, sp
                mov sp, int29_stack_bottom
    .stk_set:
 %endif
                cld
                sti
                Protect386Registers
                push bx
                push cx
                push dx
                push ds
                push es
                push ax
                mov ds, [cs: _DGROUP_]
                call _int29_main
                pop ax
                pop es
                pop ds
                pop dx
                pop cx
                pop bx
                Restore386Registers
 %ifdef USE_PRIVATE_INT29_STACK
                cli
                add byte [cs: int29_stack_count], 1
                jnc .re_stk
                mov ss, word [cs: int29_stack_org + 2]
                mov sp, word [cs: int29_stack_org]
    .re_stk:
                ;sti
 %endif
                iret

;
; int dch entry point
;
;       VOID INRPT far
;       intdc_handler(iregs UserRegs)
;
reloc_call_intdc_handler:
 %ifdef USE_PRIVATE_INTDC_STACK
                cli
                sub byte [cs: intdc_stack_count], 1
                jnc .stk_set
                mov word [cs: intdc_stack_org + 2], ss
                mov word [cs: intdc_stack_org], sp
                mov sp, PSP ; 0060h
                mov ss, sp
                mov sp, intdc_stack_bottom
    .stk_set:
 %endif
                cld
                sti
                PUSH$ALL
                mov bp,sp
                Protect386Registers
                mov ds, [cs: _DGROUP_]
                push    ss
                push    bp
                call    _intdc_main
                pop ax
                pop ax
                Restore386Registers
                POP$ALL
 %ifdef USE_PRIVATE_INTDC_STACK
                cli
                add byte [cs: intdc_stack_count], 1
                jnc .re_stk
                mov ss, word [cs: intdc_stack_org + 2]
                mov sp, word [cs: intdc_stack_org]
    .re_stk:
                ;sti
 %endif
                iret
%endif


CONTINUE        equ     00h
RETRY           equ     01h
ABORT           equ     02h
FAIL            equ     03h

OK_IGNORE       equ     20h
OK_RETRY        equ     10h
OK_FAIL         equ     08h

PSP_PARENT      equ     16h
PSP_USERSP      equ     2eh
PSP_USERSS      equ     30h



;
; COUNT
; CriticalError(COUNT nFlag, COUNT nDrive, COUNT nError, struct dhdr FAR *lpDevice);
;
                global  _CriticalError
_CriticalError:
                ;
                ; Skip critical error routine if handler is active
                ;
                cmp     byte [_ErrorMode],0
                je      CritErr05               ; Jump if equal

                mov     ax,FAIL
                retn
                ;
                ; Do local error processing
                ;
CritErr05:
                ;
                ; C Entry
                ;
                push    bp
                mov     bp,sp
                push    si
                push    di
                ;
                ; Get parameters
                ;
                mov     ah,byte [bp+4]      ; nFlags
                mov     al,byte [bp+6]      ; nDrive
                mov     di,word [bp+8]      ; nError
                ;
                ;       make cx:si point to dev header
                ;       after registers restored use bp:si
                ;
                mov     si,word [bp+10]     ; lpDevice Offset
                mov     cx,word [bp+12]     ; lpDevice segment
                ;
                ; Now save real ss:sp and retry info in internal stack
                ;
                cli
                mov     es,[_cu_psp]
                push    word [es:PSP_USERSS]
                push    word [es:PSP_USERSP]
                push    word [_MachineId]
                push    word [int21regs_seg]
                push    word [int21regs_off]
                push    word [_user_r+2]
                push    word [_user_r]
                mov     [critical_sp],sp
                ;
                ; do some clean up because user may never return
                ;
                inc     byte [_ErrorMode]
                dec     byte [_InDOS]
                ;
                ; switch to user's stack
                ;
                mov     ss,[es:PSP_USERSS]
                mov     bp,[es:PSP_USERSP]
                RestoreSP
                Restore386Registers
                mov     bp,cx        
                ;
                ; and call critical error handler
                ;
                int     24h                     ; DOS Critical error handler

                ;
                ; recover context
                ;
                cld
                cli
                mov     bp, [cs:_DGROUP_]
                mov     ds,bp
                mov     ss,bp
                mov     sp,[critical_sp]
                pop     word [_user_r]
                pop     word [_user_r+2]
                pop     word [int21regs_off]
                pop     word [int21regs_seg]
                pop     word [_MachineId]
                mov     es,[_cu_psp]
                pop     word [es:PSP_USERSP]
                pop     word [es:PSP_USERSS]
                mov     bp, sp
                mov     ah, byte [bp+4+4]       ; restore old AH from nFlags
                sti                             ; Enable interrupts
                ;
                ; clear flags
                ;
                mov     byte [_ErrorMode],0
                inc     byte [_InDOS]
                ;
                ; Check for ignore and force fail if not ok
                cmp     al,CONTINUE
                jne     CritErr10               ; not ignore, keep testing
                test    ah,OK_IGNORE
                jnz     CritErr10
                mov     al,FAIL
                ;
                ; Check for retry and force fail if not ok
                ;
CritErr10:
                cmp     al,RETRY
                jne     CritErr20               ; not retry, keep testing
                test    ah,OK_RETRY
                jnz     CritErr20
                mov     al,FAIL
                ;
                ; You know the drill, but now it's different.
                ; check for fail and force abort if not ok
                ;
CritErr20:
                cmp     al,FAIL
                jne     CritErr30               ; not fail, do exit processing
                test    ah,OK_FAIL
                jnz     CritErr30
                mov     al,ABORT
                ;
                ; OK, if it's abort we do extra processing.  Otherwise just
                ; exit.
                ;
CritErr30:
                cmp     al,ABORT
                je      CritErrAbort            ; process abort

CritErrExit:
                xor     ah,ah                   ; clear out top for return
                pop     di
                pop     si
                pop     bp
                ret

                ;
                ; Abort processing.
                ;
CritErrAbort:
                mov     ax,[_cu_psp]
                mov     es,ax
                cmp     ax,[es:PSP_PARENT]
                mov     al,FAIL
                jz      CritErrExit
                cli
                mov     bp,word [_user_r+2]   ;Get frame
                mov     ss,bp
                mov     bp,word [_user_r]
                mov     sp,bp
                mov     byte [_ErrorMode],1        ; flag abort
                mov     ax,4C00h
                mov     [bp+reg_ax],ax
                sti
                jmp     int21_reentry              ; restart the system call
