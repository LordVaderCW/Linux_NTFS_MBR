; XPSL NTFS stage1
;
; One-sector real-mode loader for the current synthetic NTFS test image.
; It derives $MFT from the BPB, reads root MFT record 5, finds XPSLDR in the
; resident root INDEX_ROOT, reads that file record, copies resident $DATA to
; 0000:8000, and jumps to it.

bits 16
org 0x7C00

LOAD_ADDR       equ 0x8000
BUF             equ 0x9000
REC_SECTORS     equ 2
ROOT_RECNO      equ 5
ATTR_INDEX_ROOT equ 0x90
ATTR_DATA       equ 0x80

start:
        jmp     short boot
        nop

oem_id: db 'NTFS    '
bytes_per_sector:    dw 512
sectors_per_cluster: db 8
reserved:            dw 0
zero0:               db 0, 0, 0
unused0:             dw 0
media:               db 0xF8
zero1:               dw 0
spt:                 dw 63
heads:               dw 255
hidden_sectors:      dd 2048
unused1:             dd 0
unused2:             dd 0
total_sectors:       dq 32768
mft_lcn:             dq 4
mft_mirror_lcn:      dq 8
clusters_per_frs:    db 0xF6
rsv0:                db 0, 0, 0
clusters_per_index:  db 1
rsv1:                db 0, 0, 0
serial:              dq 0x5850534C54455354
checksum:            dd 0

boot:
        cli
        xor     ax, ax
        mov     ds, ax
        mov     es, ax
        mov     ss, ax
        mov     sp, 0x7C00
        sti
        cld

        mov     [drive], dl
        mov     al, 'X'
        call    putc

        call    calc_mft_lba

        mov     ax, ROOT_RECNO
        call    read_mft_record
        jc      die_disk
        cmp     dword [BUF], 'FILE'
        jne     die_fmt
        mov     al, 'C'
        call    putc

        call    find_xpsldr_in_root
        jc      die_fmt
        mov     al, 'D'
        call    putc

        mov     ax, [file_recno]
        call    read_mft_record
        jc      die_disk
        mov     al, 'E'
        call    putc
        cmp     dword [BUF], 'FILE'
        jne     die_fmt
        mov     al, 'F'
        call    putc

        call    load_resident_data
        jc      die_fmt
        mov     al, 'G'
        call    putc

        mov     dl, [drive]
        jmp     0:LOAD_ADDR

die_disk:
        mov     al, 'D'
        call    putc
        jmp     halt_msg
die_fmt:
        mov     al, 'N'
        call    putc
halt_msg:
.halt:
        jmp     .halt

calc_mft_lba:
        xor     eax, eax
        mov     al, [sectors_per_cluster]
        mov     ebx, [mft_lcn]
        mul     ebx
        add     eax, [hidden_sectors]
        mov     [mft_lba], eax
        ret

; AX = MFT record number. Reads 1024 bytes to BUF.
read_mft_record:
        push    ax
        xor     eax, eax
        pop     ax
        shl     eax, 1
        add     eax, [mft_lba]
        mov     [dap_lba], eax
        xor     eax, eax
        mov     [dap_lba + 4], eax
        mov     word [dap_count], REC_SECTORS
        mov     word [dap_off], BUF
        mov     si, dap
        mov     ah, 0x42
        mov     dl, [drive]
        int     0x13
        ret

find_xpsldr_in_root:
        mov     bx, [BUF + 0x14]       ; first attribute offset
.attr:
        cmp     dword [BUF + bx], 0xFFFFFFFF
        je      .fail
        cmp     dword [BUF + bx], ATTR_INDEX_ROOT
        je      .index
        add     bx, [BUF + bx + 4]
        jmp     .attr
.index:
        mov     si, bx
        add     si, [BUF + bx + 0x14]  ; resident value
        add     si, BUF
        mov     di, si
        add     di, 16                 ; INDEX_HEADER
        add     di, [di]               ; first index entry
.entry:
        cmp     word [di + 8], 0
        je      .fail
        test    word [di + 12], 2      ; INDEX_ENTRY_END
        jnz     .fail
        cmp     byte [di + 0x50], 6
        jne     .next
        push    si
        lea     si, [di + 0x52]
        mov     bx, name_u16
        mov     cx, 6
.cmp:
        lodsw
        cmp     ax, [bx]
        jne     .no
        add     bx, 2
        loop    .cmp
        pop     si
        mov     ax, [di]               ; low word of file reference
        mov     [file_recno], ax
        clc
        ret
.no:
        pop     si
.next:
        add     di, [di + 8]
        jmp     .entry
.fail:
        stc
        ret

load_resident_data:
        mov     bx, [BUF + 0x14]
.attr:
        cmp     dword [BUF + bx], 0xFFFFFFFF
        je      .fail
        cmp     dword [BUF + bx], ATTR_DATA
        je      .data
        add     bx, [BUF + bx + 4]
        jmp     .attr
.data:
        cmp     byte [BUF + bx + 8], 0
        jne     .fail
        mov     cx, [BUF + bx + 0x10]  ; resident value length
        mov     si, bx
        add     si, [BUF + bx + 0x14]  ; resident value offset
        add     si, BUF
        mov     di, LOAD_ADDR
        rep     movsb
        clc
        ret
.fail:
        stc
        ret

puts:
        lodsb
        test    al, al
        jz      .done
        call    putc
        jmp     puts
.done:
        ret

putc:
        push    bx
        mov     ah, 0x0E
        mov     bx, 0x0007
        int     0x10
        pop     bx
        ret

drive      db 0
mft_lba    dd 0
file_recno dw 0

dap:
        db 16
        db 0
dap_count:
        dw REC_SECTORS
dap_off:
        dw BUF
        dw 0
dap_lba:
        dq 0

name_u16 dw 'X', 'P', 'S', 'L', 'D', 'R'
times 510 - ($ - $$) db 0
dw 0xAA55
