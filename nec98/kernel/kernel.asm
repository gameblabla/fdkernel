;
; File:
;                          kernel.asm
; Description:
;                       kernel start-up code
;
;                    Copyright (c) 1995, 1996
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
; $Id: kernel.asm 1705 2012-02-07 08:10:33Z perditionc $
;

                %include "segs.inc"
                %include "stacks.inc"
                %include "ludivmul.inc"

%define IN_KERNEL_ASM
                %include "nec98cfg.inc"

segment PSP

                extern  _ReqPktPtr
%ifdef NEC98
%ifdef WATCOM
                extern  init_crt:wrt TGROUP
%else
                extern  init_crt:wrt IGROUP
%endif
%endif

STACK_SIZE      equ     384/2           ; stack allocated in words

;************************************************************       
; KERNEL BEGINS HERE, i.e. this is byte 0 of KERNEL.SYS
;************************************************************       

%ifidn __OUTPUT_FORMAT__, obj
..start:
%endif
entry:  
                jmp short realentry

;************************************************************       
; KERNEL CONFIGURATION AREA
; this is copied up on the very beginning
; it's a good idea to keep this in sync with KConfig.h
;************************************************************       
                global _LowKernelConfig                                        
_LowKernelConfig:
                db 'CONFIG'             ; constant
                dw configend-configstart; size of config area
                                        ; to be checked !!!

configstart:

%ifdef NEC98
DLASortByDriveNo            db 0        ; sort disks by drive order (see initdisk.c)
InitDiskShowDriveAssignment db 1        ;
SkipConfigSeconds           db 2        ;
ForceLBA                    db 1        ;
GlobalEnableLBAsupport      db 0        ;
BootHarddiskSeconds         db 0        ;
%else
DLASortByDriveNo            db 0        ; sort disks by drive order
InitDiskShowDriveAssignment db 1        ;
SkipConfigSeconds           db 2        ;
ForceLBA                    db 0        ;
GlobalEnableLBAsupport      db 1        ;
BootHarddiskSeconds         db 0        ;
%endif

; The following VERSION resource must be keep in sync with VERSION.H
Version_OemID               db 0xFD     ; OEM_ID
Version_Major               db 2
Version_Revision            dw 42       ; REVISION_SEQ
Version_Release             dw 1        ; 0=release build, >0=svn#

configend:

;************************************************************       
; KERNEL CONFIGURATION AREA END
;************************************************************       


;************************************************************       
; KERNEL real entry (at ~60:20)
;                               
; moves the INIT part of kernel.sys to high memory (~9000:0)
; then jumps there
; to aid debugging, some '123' messages are output
; this area is discardable and used as temporary PSP for the
; init sequence
;************************************************************       

                cpu 8086                ; (keep initial entry compatible)

%ifdef IBMPC
; IBMPC
realentry:                              ; execution continues here

                push ax
                push bx
                pushf              
                mov ax, 0e31h           ; '1' Tracecode - kernel entered
                mov bx, 00f0h                                        
                int 010h
                popf
                pop bx
                pop ax

                jmp     IGROUP:kernel_start
beyond_entry:   times   256-(beyond_entry-entry) db 0
                                        ; scratch area for data (DOS_PSP)
%endif
%ifdef NEC98
; NEC98
realentry:                              ; execution continues here

                jmp     IGROUP:kernel_start
                resb    0020h - ($ - entry)
                global  _product_no
_product_no     dw  0                   ; 0020h 製品番号
                global	_inside_revision
_inside_revision    db  0               ; 0022h 内部リビジョン

                resb    0031h - ($ - entry)
                global  _promem_under16
_promem_under16 db  0                   ; 0031h プロテクトメモリサイズ(16M以下/128K単位)
                ;resb    0032h - ($ - entry)
                global  _text_vram_segment
_text_vram_segment  dw 0a000h           ; 0032h segment of Text RAM

                resb    0068h - ($ - entry)
                global  _auxspeed
_auxspeed       db  0, 0                ; 0068h copy of MEMSW1,2: aux (com0) configuration

                resb    006ch - ($ - entry)
                global  _daua_list
_daua_list      db  80h                 ; A: (SASI/IDE HD)
                                        ; db 90h ; B: (FD)
                                        ; db 91h ; C: (FD)

                resb    008ah - ($ - entry)
                global  _kanjigraph_mode
_kanjigraph_mode    db  1               ; 008ah 漢字orグラフモード
                global  _kanjigraph_char
_kanjigraph_char    db ' '              ; 008bh 漢字orグラフモード時の左下文字
                global	_shiftfunc_char
_shiftfunc_char db  ' '                 ; 008ch 通常orシフトファンクション表示時の左下文字

                resb    00a4h - ($ - entry)
                global _in_processing_stopkey
_in_processing_stopkey  db  0           ; 00a4h semaphore for STOP key (in int6 handler)

                resb    0110h - ($ - entry)
                global  _cursor_y
_cursor_y       db  0                   ; 0110h カーソル位置Y
                global  _function_flag
_function_flag  db  0                   ; 0111h ファンクション表示状態
                global  _scroll_bottom
_scroll_bottom  db  25 - 1              ; 0112h スクロール範囲下限
                global  _crt_line
_crt_line       db  1                   ; 0113h 画面ライン数
                global  _clear_attr
_clear_attr     db  0e1h                ; 0114h 消去アトリビュート
                global  _kanji2_wait
_kanji2_wait    db  0                   ; 0115h 漢字下位バイト待ち
                global  _kanji1_code
_kanji1_code    db  0                   ; 0116h 漢字上位バイトコード

                resb    0119h - ($ - entry)
                global  _clear_char
_clear_char     db  ' '                 ; 0119h 消去キャラクタ

                resb    011bh - ($ - entry)
                global  _cursor_view
_cursor_view    db  1                   ; 011bh カーソル表示状態
                global  _cursor_x
_cursor_x       db  0                   ; 011ch カーソル位置X
                global  _put_attr
_put_attr       db  0e1h                ; 011dh 表示アトリビュート
                global  _scroll_top
_scroll_top     db  0                   ; 011eh スクロール範囲上限
                global  _scroll_wait
_scroll_wait    dw  1                   ; 011fh スクロールウエイト

                resb    0126h - ($ - entry)
                global  _save_cursor_y
_save_cursor_y  db  0                   ; 0126h セーブカーソル位置Y
                global  _save_cursor_x
_save_cursor_x  db  0                   ; 0127h セーブカーソル位置X

                resb    012bh - ($ - entry)
                global  _save_cursor_attr
_save_cursor_attr   db  0e1h            ; 012bh セーブカーソルアトリビュート

                ;resb    012ch - ($ - entry)
                global  _esc_seq_cursor_pos
_esc_seq_cursor_pos db  1bh, '[24;80R'  ; 012ch - 0133h scratchpad for esc[6n ret

                resb    0136h - ($ - entry)
                global  _disk_last_access_unit
_disk_last_access_unit db 0             ; 0136h - last accessed disk unit number

;               resb    256 - ($ - entry)


%if 1
                resb    07ffh - ($ - entry)
                global  _fd98_retract_hd_pending
_fd98_retract_hd_pending db 0           ; a temporary solution: not compatible with MS-DOS

%endif

; some codes and data in IO.SYS area
;--------
%ifdef INCLUDE_CONKEY60
		align	2
		global	conkey60_begin
		global	conkey60_end
conkey60_begin:
                %include "conkey60.asm"
conkey60_end:
%endif ; INCLUDE_CONKEY60

%ifdef INCLUDE_CONSEG60
		align	2
		global	conseg60_begin
		global	conseg60_end
conseg60_begin:
                %include "conseg60.asm"
conseg60_end:
%endif ; INCLUDE_CONSEG60
;--------


; reserved area for RSDRV
;--------
                resb    17e0h - ($ - entry)

                resb    17eeh - ($ - entry)
                global _aux1speed, _aux2speed
_aux1speed      db  0, 0                ; 17EE aux1 (com1) configuration
_aux2speed      db  0, 0                ; 17F0 aux2 (com2) configuration

                resb    1802h - ($ - entry)
                global _rsdrv_seg
_rsdrv_seg      dw  0                   ; 1802 segment of RSDRV.SYS

                resb    1820h - ($ - entry)
;--------


; some codes and data in IO.SYS area
;--------
%define INCLUDE_SUPSEG60
		align	2
		global	supseg60_begin
		global	supseg60_end
supseg60_begin:
                %include "supseg60.asm"
supseg60_end:
;--------

%ifdef DUMMY_CON_IN_IOSYS
; dummy con driver (workaround for some FEP driver(s) - yes, ATOK6 it is)
; On genuine (NEC's and EPSON's) MS-DOSes, CON device is placed at:
;   0060:2660  NEC MS-DOS 2.11
;   0060:3400  MS-DOS 3.3, 5.0, 6.2 (and up to Win98SE)

                ; anywhere at seg 60h ... temporary here
                resb    2400h - ($ - entry)
_dummy_con_dev  equ     $
                dw      _dummy_prn_dev, seg _dummy_prn_dev
                dw      8013h             ; chardev (stdin, stdout, int29h)
                dw      _dummy_strategy
                dw      _dummy_con_intr
                db      'CON     '
_dummy_prn_dev  equ     $
                dw      0ffffh, 0ffffh
                dw      8000h
                dw      _dummy_strategy
                dw      _dummy_prn_intr
                db      'PRN     '

_dummy_strategy:
                extern GenStrategy
                jmp far GenStrategy
_dummy_con_intr:
                extern ConIntr
                jmp far ConIntr
_dummy_prn_intr:
                extern NulIntr
                jmp far _nul_intr
%endif ; DUMMY_CON_IN_IOSYS

%ifdef USE_PRIVATE_INT29_STACK		; (see entry.asm)
                ; private stack for int29
                global int29_stack_bottom
                align 2
                times 16 db 'Stack for int29.'          ; 16x16 = 256bytes
int29_stack_bottom:
%endif
%ifdef USE_PRIVATE_INTDC_STACK		; (see entry.asm)
                ; private stack for intdc
                global intdc_stack_bottom
                align 2
                times 16 db 'Stack for intDC.'          ; 16x16 = 256bytes
intdc_stack_bottom:
%endif

con_putmsg:
                mov al, [cs: si]
                cmp al, 0
                je .brk
                int 29h
                inc si
                jmp short con_putmsg
.brk:
                ret

con_puthex8:
                mov cl, 4
                jmp short con_puthexlp
con_puthex16:   ; from print_hex in entry.asm
                mov cl, 12
con_puthexlp:
                mov ax, dx
                shr ax, cl
                and al, 0fh
                cmp al, 10
                sbb al, 69h
                das
                int 29h
                sub cl, 4
                jae con_puthexlp
                ret



%ifdef INT6_HANDLER_IN_IOSYS
;----------------------------------------------
                extern _nec98_flush_bios_keybuf
                global _int6_handler
_int6_handler:
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
                mov si, iosys_invalid_opcode_message
con_put_and_dump:
                call con_putmsg

                mov bp, sp
                xor si, si      ; print 13 words of stack for debugging LUDIV etc.
.putstk:
                mov dx, [bp+si]
                call con_puthex16
                mov al, ' '
                int 29h
                inc si
                inc si
                cmp si, byte 13*2
                jb .putstk
                mov al, 0dh
                int 29h
                mov al, 0ah
                int 29h
                mov ax,04c7fh       ; terminate with errorlevel 127
                int 21h
                sti
.sys_halt:
                hlt
                jmp short .sys_halt ; it might be command.com that nukes

iosys_invalid_opcode_message db 0dh,0ah,'Invalid Opcode at ',0

%endif ; INT6_HANDLER_IN_IOSYS
;----------------------------------------------

                align 2

                global _int5_handler
_int5_handler:
                iret
                align 2

                global _unhandled_int_handler_iosys
_unhandled_int_handler_iosys:
%ifdef UNHANDLED_INT_HANDLER_IN_IOSYS
                mov si, .msg1
                call con_putmsg
                push bp
                mov bp, sp
                push ds
                lds si, [bp + 2]
                mov dx, [si - 2]
                pop ds
                pop bp
                mov si, .msgv
                cmp dl, 0cdh		; int xxh?
                jne .l2
                xchg dl, dh
                call con_puthex8
                mov si, .msg2
.l2:
                jmp short con_put_and_dump
.msg1:
                db 0dh,0ah
                db 'PANIC - Unhandled INT ', 0
.msgv:
                db '??'
.msg2:
                db 'h. Stack:', 0dh, 0ah, 0

%else
                jmp far _unhandled_int_handler
%endif

                resb    2d00h - ($ - entry)
                resb    100h            ; psp
                resb    24              ; sizeof(iregs) (int 21h stack)
%endif

segment INIT_TEXT

                extern  _FreeDOSmain
                extern  _query_cpu
                
                ;
                ; kernel start-up
                ;
kernel_start:

%ifdef NEC98
                cld
                call    init_crt
%endif
%ifdef IBMPC
                push bx
                pushf              
                mov ax, 0e32h           ; '2' Tracecode - kernel entered
                mov bx, 00f0h                                        
                int 010h
                popf
                pop bx
%endif

                mov     ax,I_GROUP
                cli
                mov     ss,ax
                mov     sp,init_tos
%ifdef NEC98
                sub ax, ax
                mov ds, ax
                mov al, [0501h]
                and al, 7
                inc al
                mov cl, 7 + 6
                shl ax, cl
%endif
%ifdef IBMPC
                int     12h             ; move init text+data to higher memory
                mov     cl,6
                shl     ax,cl           ; convert kb to para
%endif
                mov     dx,15 + INITSIZE
                mov     cl,4
                shr     dx,cl
                sub     ax,dx
                mov     es,ax
                mov     dx,INITTEXTSIZE ; para aligned
                shr     dx,cl
                add     ax,dx
                mov     ss,ax           ; set SS to init data segment
                sti                     ; now enable them
                mov     ax,cs
                mov     dx,__HMATextEnd ; para aligned
                shr     dx,cl
%ifdef WATCOM
                add     ax,dx
%endif
                mov     ds,ax
                mov     si,-2 + INITSIZE; word aligned
                lea     cx,[si+2]
                mov     di,si
                shr     cx,1
                std                     ; if there's overlap only std is safe
                rep     movsw

                                        ; move HMA_TEXT to higher memory
                sub     ax,dx
                mov     ds,ax           ; ds = HMA_TEXT
                mov     ax,es
                sub     ax,dx
                mov     es,ax           ; es = new HMA_TEXT

                mov     si,-2 + __InitTextStart wrt HMA_TEXT
                lea     cx,[si+2]
                mov     di,si
                shr     cx,1
                rep     movsw
                
                cld
%ifndef WATCOM                          ; for WATCOM: CS equal for HMA and INIT
                add     ax,dx
                mov     es,ax           ; otherwise CS -> init_text
%endif
                push    es
                mov     ax,cont
                push    ax
                retf
cont:           ; Now set up call frame
                mov     ds,[cs:_INIT_DGROUP]
                mov     bp,sp           ; and set up stack frame for c

%ifdef NEC98
                mov     byte [_BootDrive], 0 ; always A: on PC-98
%endif
%ifdef IBMPC
                push bx
                pushf              
                mov ax, 0e33h           ; '3' Tracecode - kernel entered
                mov bx, 00f0h                                        
                int 010h
                popf
                pop bx

                mov     byte [_BootDrive],bl ; tell where we came from
%endif

;!!             int     11h
;!!             mov     cl,6
;!!             shr     al,cl
;!!             inc     al
;!!                mov     byte [_NumFloppies],al ; and how many

                call _query_cpu
                mov     [_CPULevel], al
%if XCPU != 86
 %if XCPU < 186 || (XCPU % 100) != 86 || (XCPU / 100) > 9
  %fatal Unknown CPU level defined
 %endif
                cmp     al, 0
                ja      .cpu_queried
                ; check 8086/88 or NEC V30/V20
                push    ax
                mov     ax, 0100h
                db      0d5h, 10h              ; AAD 16
                cmp     ax, 0010h
                pop     ax
                je      .cpu_queried
                mov     al, 1                  ; treat V30 as 186
.cpu_queried:
                cmp     al, (XCPU / 100)
                jb      cpu_abort       ; if CPU not supported -->

                cpu XCPU
%endif
                
                mov     ax,ss
                mov     ds,ax
                mov     es,ax
                jmp     _FreeDOSmain

%if XCPU != 86
        cpu 8086

cpu_abort:
%ifdef NEC98
; NEC98
; todo: display message about CPU...
        mov ah, 17h            ; raise BEEP
        int 18h
.wait:
        sti
        nop
        hlt
        nop
        jmp short .wait                ; none available, loop -->
%endif ; NEC98
%ifdef IBMPC
; IBMPC
        mov ah, 0Fh
        int 10h                 ; get video mode, bh = active page

        call .first

%define LOADNAME "FreeDOS"
        db 13,10                ; (to emit a blank line after the tracecodes)
        db 13,10
        db LOADNAME, " load error: An 80", '0'+(XCPU / 100)
        db   "86 processor or higher is required by this build.",13,10
        db "To use ", LOADNAME, " on this processor please"
        db  " obtain a compatible build.",13,10
        db 13,10
        db "Press any key to reboot.",13,10
        db 0

.display:
        mov ah, 0Eh
        mov bl, 07h             ; page in bh, bl = colour for some modes
        int 10h                 ; write character (may change bp!)

.first:
        cs lodsb                ; get character
        test al, al             ; zero ?
        jnz .display            ; no, display and get next character -->

        xor ax, ax
        xor dx, dx
        int 13h                 ; reset floppy disks
        xor ax, ax
        mov dl, 80h
        int 13h                 ; reset hard disks

                                ; this "test ax, imm16" opcode is used to
        db 0A9h                 ;  skip "sti" \ "hlt" during first iteration
.wait:
        sti
        hlt                     ; idle while waiting for keystroke
        mov ah, 01h
        int 16h                 ; get keystroke
        jz .wait                ; none available, loop -->

        mov ah, 00h
        int 16h                 ; remove keystroke from buffer

        int 19h                 ; reboot
        jmp short $             ; (in case it returns, which it shouldn't)

        cpu XCPU
%endif ; IBMPC
%endif        ; XCPU != 86


segment INIT_TEXT_END


;************************************************************       
; KERNEL CODE AREA END
; the NUL device
;************************************************************       

segment CONST

                ;
                ; NUL device strategy
                ;
                global  _nul_strtgy
_nul_strtgy:
                extern GenStrategy
                jmp LGROUP: GenStrategy

                ;
                ; NUL device interrupt
                ;
                global  _nul_intr
_nul_intr:
                push    es
                push    bx
                mov bx, LGROUP
                mov es, bx
                les bx, [es:_ReqPktPtr]
                cmp     byte [es:bx+2],4    ;if read, set 0 read
                jne     no_nul_read
                mov     word [es:bx+12h],0
no_nul_read:
                or      word [es:bx+3],100h ;set "done" flag
                pop     bx
                pop     es
                retf

segment _LOWTEXT

;todo NEC98
%ifdef IBMPC
                ; low interrupt vectors 10h,13h,15h,19h,1Bh
                ; these need to be at 0070:0100 (see RBIL memory.lst)
                global _intvec_table
_intvec_table:  db 10h
                dd 0
                db 13h
                dd 0
                db 15h
                dd 0
                db 19h
                dd 0
                db 1Bh
                dd 0

                ; floppy parameter table
                global _int1e_table
_int1e_table:   times 0eh db 0

%endif ; IBMPC

;************************************************************       
; KERNEL FIXED DATA AREA 
;************************************************************       


segment _FIXED_DATA

; Because of the following bytes of data, THIS MODULE MUST BE THE FIRST
; IN THE LINK SEQUENCE.  THE BYTE AT DS:0004 determines the SDA format in
; use.  A 0 indicates MS-DOS 3.X style, a 1 indicates MS-DOS 4.0-6.X style.
                global  DATASTART
DATASTART:
                global  _DATASTART
_DATASTART:
dos_data        db      0
                dw      kernel_start
                db      0               ; padding
                dw      1               ; Hardcoded MS-DOS 4.0+ style

                times (0eh - ($ - DATASTART)) db 0
                global  _NetBios
_NetBios        dw      0               ; NetBios Number

                times (26h - 0ch - ($ - DATASTART)) db 0

; Globally referenced variables - WARNING: DO NOT CHANGE ORDER
; BECAUSE THEY ARE DOCUMENTED AS UNDOCUMENTED (?) AND HAVE
; MANY MULTIPLEX PROGRAMS AND TSRs ACCESSING THEM
                global  _NetRetry
_NetRetry       dw      3               ;-000c network retry count
                global  _NetDelay
_NetDelay       dw      1               ;-000a network delay count
                global  _DskBuffer
_DskBuffer      dd      -1              ;-0008 current dos disk buffer
                global  _inputptr
_inputptr       dw      0               ;-0004 Unread con input
                global  _first_mcb
_first_mcb      dw      0               ;-0002 Start of user memory
                global  _DPBp
                global  MARK0026H
; A reference seems to indicate that this should start at offset 26h.
MARK0026H       equ     $
_DPBp           dd      0               ; 0000 First drive Parameter Block
                global  _sfthead
_sfthead        dd      0               ; 0004 System File Table head
                global  _clock
_clock          dd      0               ; 0008 CLOCK$ device
                global  _syscon
_syscon         dw      _con_dev,LGROUP ; 000c console device
                global  _maxsecsize
_maxsecsize     dw      1024            ; 0010 maximum bytes/sector of any block device
                dd      0               ; 0012 pointer to buffers info structure
                global  _CDSp
_CDSp           dd      0               ; 0016 Current Directory Structure
                global  _FCBp
_FCBp           dd      0               ; 001a FCB table pointer
                global  _nprotfcb
_nprotfcb       dw      0               ; 001e number of protected fcbs
                global  _nblkdev
_nblkdev        db      0               ; 0020 number of block devices
                global  _lastdrive
_lastdrive      db      0               ; 0021 value of last drive
                global  _nul_dev
_nul_dev:           ; 0022 device chain root
                extern  _con_dev
                dw      _con_dev, LGROUP
                                        ; next is con_dev at init time.  
                dw      8004h           ; attributes = char device, NUL bit set
                dw      _nul_strtgy
                dw      _nul_intr
                db      'NUL     '
                global  _njoined
_njoined        db      0               ; 0034 number of joined devices
                dw      0               ; 0035 DOS 4 pointer to special names (always zero in DOS 5)
                global  _setverPtr
_setverPtr      dw      0,0             ; 0037 setver list
                dw      0               ; 003B cs offset for fix a20
                dw      0               ; 003D psp of last umb exec
                global _LoL_nbuffers
_LoL_nbuffers   dw      1               ; 003F number of buffers
                dw      1               ; 0041 size of pre-read buffer
                global  _BootDrive
_BootDrive      db      1               ; 0043 drive we booted from   

                global  _CPULevel
_CPULevel       db      0               ; 0044 cpu type (MSDOS >0 indicates dword moves ok, ie 386+)
                                        ; unless compatibility issues arise FD uses
                                        ; 0=808x, 1=18x, 2=286, 3=386+
                                        ; see cpu.asm, use >= as may add checks for 486 ...

                dw      0               ; 0045 Extended memory in KBytes
buf_info:               
                global  _firstbuf
_firstbuf       dd      0               ; 0047 disk buffer chain
                dw      0               ; 004B Number of dirty buffers
                dd      0               ; 004D pre-read buffer
                dw      0               ; 0051 number of look-ahead buffers
                global  _bufloc
_bufloc         db      0               ; 0053 00=conv 01=HMA
                global  _deblock_buf
_deblock_buf    dd      0               ; 0054 deblock buffer
                times 3 db 0            ; 0058 unknown
                dw      0               ; 005B unknown
                db      0, 0FFh, 0      ; 005D unknown
                global _VgaSet
_VgaSet         db      0               ; 0060 unknown
                dw      0               ; 0061 unknown
                global  _uppermem_link
_uppermem_link  db      0               ; 0063 upper memory link flag
_min_pars       dw      0               ; 0064 minimum paragraphs of memory 
                                        ;      required by program being EXECed
                global  _uppermem_root
_uppermem_root  dw      0ffffh          ; 0066 dmd_upper_root (usually 9fff)
_last_para      dw      0               ; 0068 para of last mem search
SysVarEnd:

;; FreeDOS specific entries
;; all variables below this point are subject to relocation.
;; programs should not rely on any values below this point!!!

                global  _os_setver_minor
_os_setver_minor        db      0
                global  _os_setver_major
_os_setver_major        db      5
                global  _os_minor
_os_minor       db      0
                global  _os_major              
_os_major       db      5
_rev_number     db      0
                global  _version_flags         
_version_flags  db      0

                global  os_release
                extern  _os_release
os_release      dw      _os_release

%IFDEF WIN31SUPPORT
                global  _winStartupInfo, _winInstanced
_winInstanced    dw 0 ; set to 1 on WinInit broadcast, 0 on WinExit broadcast
_winStartupInfo:
                dw 0 ; structure version (same as windows version)
                dd 0 ; next startup info structure, 0:0h marks end
                dd 0 ; far pointer to name virtual device file or 0:0h
                dd 0 ; far pointer, reference data for virtual device driver
                dw instance_table,seg instance_table ; array of instance data
instance_table: ; should include stacks, Win may auto determine SDA region
                ; we simply include whole DOS data segment
                dw 0, seg _DATASTART ; [SEG:OFF] address of region's base
                dw markEndInstanceData wrt seg _DATASTART ; size in bytes
                dd 0 ; 0 marks end of table
                dw 0 ; and 0 length for end of instance_table entry
                global  _winPatchTable
_winPatchTable: ; returns offsets to various internal variables
                dw 0x0006      ; DOS version, major# in low byte, eg. 6.00
                dw save_DS     ; where DS stored during int21h dispatch
                dw save_BX     ; where BX stored during int21h dispatch
                dw _InDOS      ; offset of InDOS flag
                dw _MachineId  ; offset to variable containing MachineID
                dw _CritPatch  ; offset of to array of offsets to patch
                               ; NOTE: this points to a null terminated
                               ; array of offsets of critical section bytes
                               ; to patch, for now we can just point this
                               ; to an empty table
                               ; ie we just point to a 0 word to mark end
                dw _uppermem_root ; seg of last arena header in conv memory
                                  ; this matches MS DOS's location, but 
                                  ; do we have the same meaning?
%ENDIF ; WIN31SUPPORT

;;  The first 5 sft entries appear to have to be at DS:00cc
                times (0cch - ($ - DATASTART)) db 0
                global _firstsftt
_firstsftt:             
                dd -1                   ; link to next
                dw 5                    ; count 
        
; Some references seem to indicate that this data should start at 01fbh in
; order to maintain 100% MS-DOS compatibility.
                times (01fbh - ($ - DATASTART)) db 0

                global  MARK01FBH
MARK01FBH       equ     $
                global  _local_buffer   ; local_buffer is 256 bytes long
                                        ; so it overflows into kb_buf!!
        ; only when kb_buf is used, local_buffer is limited to 128 bytes.
_local_buffer:  times 128 db 0
                global  _kb_buf
_kb_buf db      128,0                   ; initialise buffer to empty
                times 128+1 db 0   ; room for 128 byte readline + LF
;
; Variables that follow are documented as part of the DOS 4.0-6.X swappable
; data area in Ralf Browns Interrupt List #56
;
; this byte is used for ^P support
                global  _PrinterEcho
_PrinterEcho    db      0               ;-34 -  0 = no printer echo, ~0 echo
                global  _verify_ena
_verify_ena     db      0               ; ~0, write with verify

; this byte is used for TABs (shared by all char device writes??)
                global _scr_pos
_scr_pos        db      0               ; Current Cursor Column
                global  _switchar
_switchar       db      '/'             ;-31 - switch char
                global  _mem_access_mode
_mem_access_mode db     0               ;-30 -  memory allocation strategy
                global  sharing_flag
sharing_flag    db      0               ; 00 = sharing module not loaded
                                        ; 01 = sharing module loaded, but
                                        ;      open/close for block devices
                                        ;      disabled
                                        ; FF = sharing module loaded,
                                        ;      open/close for block devices
                                        ;      enabled (not implemented)
                global  _net_set_count
_net_set_count   db      1               ;-28 -  count the name below was set
                global  _net_name
_net_name       db      '               ' ;-27 - 15 Character Network Name
                db      00                ; Terminating 0 byte


;
;       Variables contained the the "STATE_DATA" segment contain
;       information about the STATE of the current DOS Process. These
;       variables must be preserved regardless of the state of the INDOS
;       flag.
;
;       All variables that appear in "STATE_DATA" **MUST** be declared
;       in this file as the offsets from the INTERNAL_DATA variable are
;       critical to the DOS applications that modify this data area.
;
;
                global  _ErrorMode, _InDOS
                global  _CritErrLocus, _CritErrCode
                global  _CritErrAction, _CritErrClass
                global  _CritErrDev, _CritErrDrive
                global  _dta
                global  _cu_psp, _default_drive
                global  _break_ena
                global  _return_code
                global  _internal_data

                global  _CritPatch
; ensure offset of critical patch table remains fixed, some programs hard code offset
                times (0315h - ($ - DATASTART)) db 0
_CritPatch      dw      0               ;-11 zero list of patched critical
                dw      0               ;    section variables
                dw      0               ;    DOS puts 0d0ch here but some
                dw      0               ;    progs really write to that addr.
                dw      0               ;-03 - critical patch list terminator
                db      90h             ;-01 - unused, NOP pad byte
_internal_data:              ; <-- Address returned by INT21/5D06
_ErrorMode      db      0               ; 00 - Critical Error Flag
_InDOS          db      0               ; 01 - Indos Flag
_CritErrDrive   db      0               ; 02 - Drive on write protect error
_CritErrLocus   db      0               ; 03 - Error Locus
_CritErrCode    dw      0               ; 04 - DOS format error Code
_CritErrAction  db      0               ; 06 - Error Action Code
_CritErrClass   db      0               ; 07 - Error Class
_CritErrDev     dd      0               ; 08 - Failing Device Address
_dta            dd      0               ; 0C - current DTA
_cu_psp         dw      0               ; 10 - Current PSP
break_sp        dw      0               ; 12 - used in int 23
_return_code    dw      0               ; 14 - return code from process
_default_drive  db      0               ; 16 - Current Drive
_break_ena      db      0               ; 17 - Break Flag (default OFF)
                db      0               ; 18 - flag, code page switching
                db      0               ; 19 - flag, copy of 18 on int 24h abort

                global  _swap_always, _swap_indos
_swap_always:

                global  _Int21AX
_Int21AX        dw      0               ; 1A - AX from last Int 21

                global  owning_psp, _MachineId
owning_psp      dw      0               ; 1C - owning psp
_MachineId      dw      0               ; 1E - remote machine ID
                dw      0               ; 20 - First usable mcb
                dw      0               ; 22 - Best usable mcb
                dw      0               ; 24 - Last usable mcb
                dw      0               ; 26 - memory size in paragraphs
                dw      0               ; 28 - unknown
                db      0               ; 2A - unknown
                db      0               ; 2B - unknown
                db      0               ; 2C - unknown
                global  _break_flg
_break_flg      db      0               ; 2D - Program aborted by ^C
                db      0               ; 2E - unknown
                db      0               ; 2F - not referenced
                global  _DayOfMonth
_DayOfMonth     db      1               ; 30 - day of month
                global  _Month
_Month          db      1               ; 31 - month
                global  _YearsSince1980
_YearsSince1980 dw      0               ; 32 - year since 1980
daysSince1980   dw      0FFFFh          ; 34 - number of days since epoch
                                        ; force rebuild on first clock read
                global  _DayOfWeek
_DayOfWeek      db      2               ; 36 - day of week
_console_swap   db      0               ; 37 console swapped during read from dev
                global  _dosidle_flag        
_dosidle_flag   db      1               ; 38 - safe to call int28 if nonzero
_abort_progress db      0               ; 39 - abort in progress
                global  _CharReqHdr
_CharReqHdr:
                global  _ClkReqHdr
_ClkReqHdr      times 30 db 0      ; 3A - Device driver request header
                dd      0               ; 58 - pointer to driver entry
                global  _MediaReqHdr
_MediaReqHdr    times 22 db 0      ; 5C - Device driver request header
                global  _IoReqHdr
_IoReqHdr       times 30 db 0      ; 72 - Device driver request header
                times 6 db 0       ; 90 - unknown
                global  _ClkRecord
_ClkRecord      times 6 db 0       ; 96 - CLOCK$ transfer record
                global _SingleIOBuffer
_SingleIOBuffer dw      0          ; 9C - I/O buffer for single-byte I/O
                global  __PriPathBuffer
__PriPathBuffer times 80h db 0     ; 9E - buffer for file name
                global  __SecPathBuffer
__SecPathBuffer times 80h db 0     ;11E - buffer for file name
                global  _sda_tmp_dm
_sda_tmp_dm     times 21 db 0      ;19E - 21 byte srch state
                global  _SearchDir
_SearchDir      times 32 db 0      ;1B3 - 32 byte dir entry
                global  _TempCDS
_TempCDS        times 88 db 0      ;1D3 - TemporaryCDS buffer
                global  _DirEntBuffer
_DirEntBuffer   times 32 db 0      ;22B - space enough for 1 dir entry
                global  _wAttr
_wAttr          dw      0               ;24B - extended FCB file attribute


                global  _SAttr
_SAttr          db      0           ;24D - Attribute Mask for Dir Search
                global  _OpenMode
_OpenMode       db      0           ;24E - File Open Attribute

                times 3 db 0
                global  _Server_Call
_Server_Call    db      0           ;252 - Server call Func 5D sub 0
                db      0
                ; Pad to 05CCh
                times (25ch - ($ - _internal_data)) db 0

                global  _tsr            ; used by break and critical error
_tsr            db      0               ;25C -  handlers during termination
                db      0               ;25D - padding
                global  term_psp
term_psp        dw  0                   ;25E - 0??
                global  int24_esbp
int24_esbp      times 2 dw 0       ;260 - pointer to criticalerr DPB
                global  _user_r, int21regs_off, int21regs_seg
_user_r:
int21regs_off   dw      0               ;264 - pointer to int21h stack frame
int21regs_seg   dw      0
                global  critical_sp
critical_sp     dw      0               ;268 - critical error internal stack
                global  current_ddsc
current_ddsc    times 2 dw 0

                ; Pad to 059ah
                times (27ah - ($ - _internal_data)) db 0
                global  current_device
current_device  times 2 dw 0       ;27A - 0??
                global  _lpCurSft
_lpCurSft       times 2 dw 0       ;27e - Current SFT
                global  _current_ldt
_current_ldt     times 2 dw 0       ;282 - Current CDS
                global  _sda_lpFcb
_sda_lpFcb      times 2 dw 0       ;286 - pointer to callers FCB
                global  _current_sft_idx
_current_sft_idx    dw      0               ;28A - SFT index for next open
                                        ; used by MS NET

                ; Pad to 05b2h
                times (292h - ($ - _internal_data)) db 0
                dw      __PriPathBuffer  ; 292 - "sda_WFP_START" offset in DOS DS of first filename argument
                dw      __SecPathBuffer  ; 294 - "sda_REN_WFP" offset in DOS DS of second filename argument

                ; Pad to 05ceh
                times (2aeh - ($ - _internal_data)) db 0
                global  _current_filepos
_current_filepos times 2 dw 0       ;2AE - current offset in file

                ; Pad to 05eah
                times (2cah - ($ - _internal_data)) db 0
                ;global _save_BX
                ;global _save_DS
save_BX                 dw      0       ;2CA - unused by FreeDOS, for Win3.x
save_DS                 dw      0       ;      compatibility, match MS's positions
                        dw      0
                global  _prev_user_r
                global  prev_int21regs_off
                global  prev_int21regs_seg
_prev_user_r:
prev_int21regs_off      dw      0       ;2D0 - pointer to prev int 21 frame
prev_int21regs_seg      dw      0

                ; Pad to 05fdh
                times (2ddh - ($ - _internal_data)) db 0
                global  _ext_open_action
                global  _ext_open_attrib
                global  _ext_open_mode
_ext_open_action dw 0                   ;2DD - extended open action
_ext_open_attrib dw 0                   ;2DF - extended open attrib
_ext_open_mode   dw 0                   ;2E1 - extended open mode

                ; Pad to 0620h
                times (300h - ($ - _internal_data)) db 0

                global apistk_bottom
apistk_bottom:
                ; use bottom of error stack as scratch buffer
                ;  - only used during int 21 call
                global  _sda_tmp_dm_ren
_sda_tmp_dm_ren:times 21 db 0x90   ;300 - 21 byte srch state for rename
                global  _SearchDir_ren
_SearchDir_ren: times 32 db 0x90   ;315 - 32 byte dir entry for rename

                ; stacks are made to initialize to no-ops so that high-water
                ; testing can be performed
                times STACK_SIZE*2-($-apistk_bottom) db 0x90
                ;300 - Error Processing Stack
                global  _error_tos
_error_tos:
                times STACK_SIZE dw 0x9090 ;480 - Disk Function Stack
                global  _disk_api_tos
_disk_api_tos:
                times STACK_SIZE dw 0x9090 ;600 - Char Function Stack
                global  _char_api_tos
_char_api_tos:
apistk_top:
                db      0               ; 780 ???
_VolChange      db      0               ;781 - volume change
_VirtOpen       db      0               ;782 - virtual open flag

                ; controlled variables end at offset 78Ch so pad to end
                times (78ch - ($ - _internal_data)) db 0

                ; bottom of SDA, for PC/MS-DOS (non FAT32)
                global _swap_indos_msdos_compatible
_swap_indos_msdos_compatible:

;
; end of controlled variables
;

segment _BSS
;!!                global  _NumFloppies
;!!_NumFloppies resw    1
;!!intr_dos_stk resw    1
;!!intr_dos_seg resw    1


; mark front and end of bss area to clear
segment IB_B
    global __ib_start
__ib_start:
segment IB_E
    global __ib_end
__ib_end:
        ;; do not clear the other init BSS variables + STACK: too late.

; kernel startup stack
                global  init_tos
%ifdef NEC98
                resw 512 * 2 ; todo: check it
%else
                resw 512
%endif
init_tos:
; the last paragraph of conventional memory might become an MCB
                resb 16
                global __init_end
__init_end:
init_end:        

segment _DATA
; blockdev private stack
                global  blk_stk_top
                times 256 dw 0
blk_stk_top:

; clockdev private stack
                global  clk_stk_top
                times 128 dw 0
clk_stk_top:

; int2fh private stack
                global  int2f_stk_top
                times 128 dw 0
int2f_stk_top:

; Dynamic data:
; member of the DOS DATA GROUP
; and marks definitive end of all used data in kernel data segment
;

segment _DATAEND

_swap_indos:
; we don't know precisely what needs to be swapped before this, so set it here.
; this is just after FIXED_DATA+BSS+DATA and before (D)CONST+BSS
; probably, the clock and block stacks and disktransferbuffer should go past
; _swap_indos but only if int2a ah=80/81 (critical section start/end)
; are called upon entry and exit of the device drivers

                times 96 dw 0x9090 ; Process 0 Stack
                global  _p_0_tos
_p_0_tos:

segment DYN_DATA

        global _Dyn
_Dyn:
        DynAllocated dw 0

markEndInstanceData:  ; mark end of DOS data seg we say needs instancing

        
segment ID_B
    global __INIT_DATA_START
__INIT_DATA_START:
segment ID_E
    global __INIT_DATA_END
__INIT_DATA_END:


segment INIT_TEXT_START
                global  __InitTextStart
__InitTextStart:                    ; and c version

segment INIT_TEXT_END
                global  __InitTextEnd
__InitTextEnd:                      ; and c version

;
; start end end of HMA area

segment HMA_TEXT_START
                global __HMATextAvailable
__HMATextAvailable:
                global  __HMATextStart
__HMATextStart:   
 
; 
; the HMA area is filled with 1eh+3(=sizeof VDISK) = 33 byte dummy data,
; so nothing will ever be below 0xffff:0031
;
segment HMA_TEXT
begin_hma:              
                times 10h db 0   ; filler [ffff:0..ffff:10]
                times 20h db 0
                db 0

; to minimize relocations
                global _DGROUP_
_DGROUP_        dw DGROUP

%ifdef WATCOM
;               32 bit multiplication + division
global __U4M
__U4M:
                LMULU
global __U4D
__U4D:
                LDIVMODU
%endif

%ifdef gcc
%macro ULONG_HELPERS 1
global %1udivsi3
%1udivsi3:      call %1ldivmodu
                ret 8
 global %1umodsi3
%1umodsi3:      call %1ldivmodu
                mov dx, cx
                mov ax, bx
                ret 8
 %1ldivmodu:     LDIVMODU
 global %1ashlsi3
%1ashlsi3:      LSHLU
 global %1lshrsi3
%1lshrsi3:      LSHRU
%endmacro
                ULONG_HELPERS ___
%endif
                 times 0xd0 - ($-begin_hma) db 0
                ; reserve space for far jump to cp/m routine
                times 5 db 0

;End of HMA segment                
segment HMA_TEXT_END
                global  __HMATextEnd
__HMATextEnd:                   ; and c version



; The default stack (_TEXT:0) will overwrite the data area, so I create a dummy
; stack here to ease debugging. -- ror4

segment _STACK  class(STACK) nobits stack


    

segment CONST
%ifdef NEC98
retract_hd:
                push dx
                xor ax, ax
                mov ds, ax
                mov dl, byte [055dh]	; DISK_EQUIP  bit0~3 SASI/IDE HDs #0~3
                mov dh, byte [0482h]	; DISK_EQUIPS bit0~6 SCSI HDs #0~6
                and dx, 7f0fh
                mov al, 80h		; SASI/IDE base DA/UA
                call .rh_sub
                mov al, 0A0h		; SCSI base DA/UA
                mov dl, dh
                call .rh_sub
                pop dx
                jmp short retract_hd_exit
.rh_sub:
                shr dl, 1
                jnc .rh_sub_next
                push ax
                mov ah, 2fh		; retract HD, no retry
                int 1bh
                pop ax
.rh_sub_next:
                inc al
                test dl, dl
                jnz .rh_sub
                ret
%endif
        ; dummy interrupt return handlers

                global _int22_handler
                global _int28_handler
                global _int2a_handler
                global _empty_handler
_int28_handler:
%ifdef NEC98
                push ax
                push ds
                mov ax, 60h
                mov ds, ax
                xchg [_fd98_retract_hd_pending], ah
                cmp ah, 0
                jne retract_hd
retract_hd_exit:
                pop ds
                pop ax
%endif
_int22_handler:         
;_int28_handler:
_int2a_handler:
_empty_handler:
                iret
    

global _initforceEnableA20
initforceEnableA20:
                call near forceEnableA20
                retf   

    global __HMARelocationTableStart
__HMARelocationTableStart:   

                global  _int2f_handler
                extern  reloc_call_int2f_handler
_int2f_handler: jmp 0:reloc_call_int2f_handler
                call near forceEnableA20

                global  _int20_handler
                extern  reloc_call_int20_handler
_int20_handler: jmp 0:reloc_call_int20_handler
                call near forceEnableA20

                global  _int21_handler
                extern  reloc_call_int21_handler
_int21_handler: jmp 0:reloc_call_int21_handler
                call near forceEnableA20


                global  _low_int25_handler
                extern  reloc_call_low_int25_handler
_low_int25_handler: jmp 0:reloc_call_low_int25_handler
                call near forceEnableA20

                global  _low_int26_handler
                extern  reloc_call_low_int26_handler
_low_int26_handler: jmp 0:reloc_call_low_int26_handler
                call near forceEnableA20

                global  _int27_handler
                extern  reloc_call_int27_handler
_int27_handler: jmp 0:reloc_call_int27_handler
                call near forceEnableA20

                global  _int0_handler
                extern  reloc_call_int0_handler
_int0_handler:  jmp 0:reloc_call_int0_handler
                call near forceEnableA20

%ifndef INT6_HANDLER_IN_IOSYS
                global  _int6_handler
                extern  reloc_call_int6_handler
_int6_handler:  jmp 0:reloc_call_int6_handler
                call near forceEnableA20
%endif

%ifdef IBMPC
                global  _int19_handler
                extern  reloc_call_int19_handler
_int19_handler: jmp 0:reloc_call_int19_handler
                call near forceEnableA20
%endif

                global  _cpm_entry
                extern  reloc_call_cpm_entry
_cpm_entry:     jmp 0:reloc_call_cpm_entry
                call near forceEnableA20

                global  _reloc_call_blk_driver
                extern  _blk_driver
_reloc_call_blk_driver:
                jmp 0:_blk_driver
                call near forceEnableA20

                global  _reloc_call_clk_driver
                extern  _clk_driver
_reloc_call_clk_driver:
                jmp 0:_clk_driver
                call near forceEnableA20

                global  _CharMapSrvc ; in _DATA (see AARD)
                extern  _reloc_call_CharMapSrvc
_CharMapSrvc:   jmp 0:_reloc_call_CharMapSrvc
                call near forceEnableA20

                global _init_call_p_0
                extern reloc_call_p_0
_init_call_p_0: jmp  0:reloc_call_p_0
                call near forceEnableA20

%ifdef NEC98
                global  _int29_handler
                extern  reloc_call_int29_handler
_int29_handler: jmp 0:reloc_call_int29_handler
                call near forceEnableA20

                global  _intdc_handler
                extern  reloc_call_intdc_handler
_intdc_handler: jmp 0:reloc_call_intdc_handler
                call near forceEnableA20
 %ifndef UNHANDLED_INT_HANDLER_IN_IOSYS
                global  _unhandled_int_handler
                extern  reloc_call_unhandled_int_handler
_unhandled_int_handler: jmp 0:reloc_call_unhandled_int_handler
                call near forceEnableA20
 %endif
%endif ; NEC98

   global __HMARelocationTableEnd
__HMARelocationTableEnd:    

;
; if we were lucky, we found all entries from the outside to the kernel.
; if not, BUMS
;
;
; this routine makes the HMA area available. PERIOD.
; must conserve ALL registers
; will be only ever called, if HMA (DOS=HIGH) is enabled.
; for obvious reasons it should be located at the relocation table
;
    global _XMSDriverAddress
_XMSDriverAddress:  
                    dw 0            ; XMS driver, if detected
                    dw 0

    global _ENABLEA20
_ENABLEA20:
    mov ah,5
UsingXMSdriver:    
    push bx
    push cx       ; note: some HIMEM.SYS (bundled with Win9x, and NEC MS-DOS 6.2)
                  ;       will be set cx to zero at just first subfunc 5 call.
                  ;       (NEC DOS 5.0 and all EPSONs will not)
    call far [cs:_XMSDriverAddress]
    pop cx
    pop  bx
    retf

    global _DISABLEA20
_DISABLEA20:
    mov ah,6
    jmp short UsingXMSdriver

dslowmem  dw 0
eshighmem dw 0ffffh

    global forceEnableA20
forceEnableA20:

    push ds
    push es
    push ax
    
forceEnableA20retry:    
    mov  ds, [cs:dslowmem]
    mov  es, [cs:eshighmem]
    
    mov ax, [ds:00000h]    
    cmp ax, [es:00010h]    
    jne forceEnableA20success

    mov ax, [ds:00002h]    
    cmp ax, [es:00012h]    
    jne forceEnableA20success

    mov ax, [ds:00004h]    
    cmp ax, [es:00014h]    
    jne forceEnableA20success

    mov ax, [ds:00006h]    
    cmp ax, [es:00016h]    
    jne forceEnableA20success

;
;   ok, we have to enable A20 )at least seems so
;

    call DGROUP:_ENABLEA20
    
    jmp short forceEnableA20retry
    
    
    
forceEnableA20success:    
    pop ax
    pop es
    pop ds
    ret
                
;
; global f*cking compatibility issues:
;
; very old brain dead software (PKLITE, copyright 1990)
; forces us to execute with A20 disabled
;

global _ExecUserDisableA20

_ExecUserDisableA20:

    cmp word [cs:_XMSDriverAddress], byte 0
    jne NeedToDisable
    cmp word [cs:_XMSDriverAddress+2], byte 0
    je noNeedToDisable
NeedToDisable:        
    push ax 
    call DGROUP:_DISABLEA20
    pop ax
noNeedToDisable:
    iret        


;
; Default Int 24h handler -- always returns fail
; so we have not to relocate it (now)
;
FAIL            equ     03h

                global  _int24_handler
_int24_handler: mov     al,FAIL
                iret

;
; this makes some things easier
;

segment _LOWTEXT
                global _TEXT_DGROUP
_TEXT_DGROUP dw DGROUP

segment INIT_TEXT
                global _INIT_DGROUP
_INIT_DGROUP dw DGROUP

%ifdef gcc
                ULONG_HELPERS _init_
%endif
