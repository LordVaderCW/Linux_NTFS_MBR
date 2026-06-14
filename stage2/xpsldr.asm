; XPSLDR - XP Subsystem For Linux loader shim
;
; Initial contract:
;   Loaded at 0000:8000 by the NTFS boot stage.
;   Entered in 16-bit real mode with BIOS services available.
;
; This first version proves that a named NTFS file can be loaded and executed.

bits 16
org 0x8000

start:
        cli
        xor     ax, ax
        mov     ds, ax
        mov     es, ax
        mov     ss, ax
        mov     sp, 0x7C00
        sti
        cld

        mov     si, message
        call    print_string

.hang:
        jmp     .hang

print_string:
        lodsb
        test    al, al
        jz      .done
        mov     ah, 0x0E
        mov     bx, 0x0007
        int     0x10
        jmp     print_string
.done:
        ret

message db 'XPSLDR loaded from NTFS', 13, 10, 0
