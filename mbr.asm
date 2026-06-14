; Linux NTFS MBR Bootloader
; Clean-room BIOS MBR chainloader.
;
; This stage does not parse NTFS. It finds the single active partition,
; loads that partition's boot sector at 0000:7C00, validates 0xAA55,
; and jumps to it. NTFS-aware Linux loading belongs in the partition
; boot record or a later stage.
;
; Assembly: nasm -f bin -o mbr.bin mbr.asm

bits 16
org 0x7C00

LOAD_ADDR       equ 0x7C00
RELOC_ADDR      equ 0x0600
PART_TABLE      equ RELOC_ADDR + 0x1BE
PART_ENTRY_SIZE equ 16
BOOT_SIGNATURE  equ 0xAA55
READ_RETRIES    equ 5

start:
        cli
        xor     ax, ax
        mov     ds, ax
        mov     es, ax
        mov     ss, ax
        mov     sp, LOAD_ADDR
        sti
        cld

        mov     [boot_drive], dl

        mov     si, LOAD_ADDR
        mov     di, RELOC_ADDR
        mov     cx, 256
        rep     movsw

        jmp     0:relocated

relocated equ relocated_here - start + RELOC_ADDR

relocated_here:
        mov     dl, [boot_drive - start + RELOC_ADDR]
        mov     bp, PART_TABLE
        mov     cx, 4
        xor     bx, bx

.scan_active:
        cmp     byte [bp], 0x80
        je      .found_active
        cmp     byte [bp], 0x00
        jne     invalid_partition
        add     bp, PART_ENTRY_SIZE
        loop    .scan_active
        jmp     missing_os

.found_active:
        mov     si, bp
        inc     bx
        cmp     bx, 1
        ja      invalid_partition
        add     bp, PART_ENTRY_SIZE
        loop    .scan_active

        mov     bp, si
        call    read_pbr
        jc      load_error

        cmp     word [LOAD_ADDR + 510], BOOT_SIGNATURE
        jne     missing_os

        mov     dl, [boot_drive - start + RELOC_ADDR]
        mov     si, bp
        push    word 0
        push    word LOAD_ADDR
        retf

invalid_partition:
        mov     si, msg_invalid - start + RELOC_ADDR
        jmp     print_halt

load_error:
        mov     si, msg_load_error - start + RELOC_ADDR
        jmp     print_halt

missing_os:
        mov     si, msg_missing - start + RELOC_ADDR

print_halt:
        call    print_string
        cli
.halt:
        hlt
        jmp     .halt

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

read_pbr:
        pusha
        mov     byte [retry_count - start + RELOC_ADDR], READ_RETRIES

.try_extensions:
        mov     dl, [boot_drive - start + RELOC_ADDR]
        mov     ah, 0x41
        mov     bx, 0x55AA
        int     0x13
        jc      .chs_read
        cmp     bx, 0xAA55
        jne     .chs_read
        test    cx, 1
        jz      .chs_read

.lba_retry:
        mov     si, dap - start + RELOC_ADDR
        mov     ah, 0x42
        mov     dl, [boot_drive - start + RELOC_ADDR]
        mov     eax, [bp + 8]
        mov     [dap_lba - start + RELOC_ADDR], eax
        xor     eax, eax
        mov     [dap_lba + 4 - start + RELOC_ADDR], eax
        int     0x13
        jnc     .success
        call    reset_disk
        dec     byte [retry_count - start + RELOC_ADDR]
        jnz     .lba_retry
        stc
        jmp     .done

.chs_read:
        mov     byte [retry_count - start + RELOC_ADDR], READ_RETRIES

.chs_retry:
        mov     ax, 0x0201
        mov     bx, LOAD_ADDR
        mov     cx, [bp + 2]
        mov     dh, [bp + 1]
        mov     dl, [boot_drive - start + RELOC_ADDR]
        int     0x13
        jnc     .success
        call    reset_disk
        dec     byte [retry_count - start + RELOC_ADDR]
        jnz     .chs_retry
        stc
        jmp     .done

.success:
        clc
.done:
        popa
        ret

reset_disk:
        xor     ah, ah
        mov     dl, [boot_drive - start + RELOC_ADDR]
        int     0x13
        ret

boot_drive  db 0
retry_count db 0

dap:
        db 16
        db 0
        dw 1
        dw LOAD_ADDR
        dw 0
dap_lba:
        dq 0

msg_invalid    db 'Invalid partition table', 0
msg_load_error db 'Error loading operating system', 0
msg_missing    db 'Missing operating system', 0

times 446 - ($ - $$) db 0

partition_table:
times 64 db 0

dw BOOT_SIGNATURE
