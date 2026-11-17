/*
 * Boot program of the IBM PC AT 5170 diskette test (assembled by
 * scripts/make_test_diskette.py with GNU as and ld; original code, no
 * copyrighted content). Two sectors: the boot sector (LBA 0) and the
 * diskette's second reserved sector (LBA 1).
 *
 * The BIOS's bootstrap loader (INT 19h) reads the boot sector to
 * 0000:7C00h and jumps there. Using only BIOS services the program:
 *   1. reads its second sector to 0000:7E00h (INT 13h) and continues there;
 *   2. prints an identifying line (INT 10h teletype);
 *   3. reads the test file (file_lba, file_sectors) with INT 13h, one read
 *      per cylinder remainder: a read that starts on head 0 continues on
 *      head 1 (multi-sector, across the head boundary; the controller's
 *      multi-track mode), and successive reads step across every cylinder
 *      the file occupies; each read lands in the 64 KiB-aligned buffer at
 *      1000:0000 and is summed (16-bit: rotate left 1, add word);
 *   4. compares the sum with file_sum and prints READ OK or READ BAD;
 *   5. writes a pattern sector at write_lba, reads it back into another
 *      buffer and compares (WRITE OK / WRITE BAD);
 *   6. prints PASS or FAIL and halts with interrupts disabled.
 * The script fills the BIOS parameter block (offsets 3-61) and the test
 * parameters at offset 62.
 */
    .code16
    /* 80286 instructions only: as then relaxes a far conditional jump into
       a short jump around a near JMP instead of the 386 form 0F 8x. */
    .arch i286
    .intel_syntax noprefix
    .text
    /* working variables, below the program in RAM (0000:0500) */
    .equ drive, 0x500
    .equ failed, 0x501
    .equ status, 0x502
    .equ func, 0x503
    .equ tries, 0x504
    .equ lba, 0x506
    .equ left, 0x508
    .equ count, 0x50a
    .equ sum, 0x50c
    .equ cur, 0x50e

    .globl _start
_start:
    jmp short main
    nop
    /* 3: OEM name and BIOS parameter block, filled in by the script. */
    .fill 59, 1, 0
    /* 62: test parameters, patched by the script. */
file_lba:     .word 0
file_sectors: .word 0
file_sum:     .word 0
write_lba:    .word 0
spt:          .word 15
heads:        .word 2

main:
    /* far jump to 0000:norm so CS is 0 whichever CS:IP the loader used */
    .byte 0xea
    .word norm, 0
norm:
    cli
    xor ax, ax
    mov ds, ax
    mov ss, ax
    mov sp, 0x7c00
    sti
    mov [drive], dl
    mov byte ptr [failed], 0
    /* load the second sector (LBA 1: cylinder 0, head 0, sector 2) */
    mov byte ptr [tries], 3
0:  mov ax, 0x0201
    mov cx, 0x0002
    xor dh, dh
    mov dl, [drive]
    xor bx, bx
    mov es, bx
    mov bx, 0x7e00
    int 0x13
    jnc stage2
    xor ax, ax
    mov dl, [drive]
    int 0x13
    dec byte ptr [tries]
    jnz 0b
    cli
1:  hlt
    jmp 1b

    .org 510
    .byte 0x55, 0xaa

    /* ---- second sector, at 7E00h */
stage2:
    mov si, offset msg_hello
    call puts

    /* ---- read the file and sum it */
    mov ax, [file_lba]
    mov [lba], ax
    mov ax, [file_sectors]
    mov [left], ax
    mov word ptr [sum], 0
read_loop:
    cmp word ptr [left], 0
    je read_done
    /* count = min(left, sectors to the end of this cylinder) */
    mov ax, [spt]
    mul word ptr [heads]          /* AX = sectors per cylinder */
    mov cx, ax
    mov ax, [lba]
    xor dx, dx
    div cx                        /* DX = lba mod (spt*heads) */
    sub cx, dx
    cmp cx, [left]
    jbe 1f
    mov cx, [left]
1:  mov [count], cx
    mov ax, 0x1000
    mov es, ax
    xor bx, bx
    mov ax, [lba]
    mov ch, 2                     /* function 2: read */
    call disk_io
    jc fail_io
    /* sum count*256 words of 1000:0000 */
    push ds
    mov ax, 0x1000
    mov ds, ax
    xor si, si
    mov ax, cs:[count]
    mov cx, 256
    mul cx
    mov cx, ax
    mov dx, cs:[sum]
2:  lodsw
    rol dx, 1
    add dx, ax
    loop 2b
    pop ds
    mov [sum], dx
    mov ax, [count]
    add [lba], ax
    sub [left], ax
    jmp read_loop
read_done:
    mov si, offset msg_read
    call puts
    mov ax, [sum]
    cmp ax, [file_sum]
    call verdict

    /* ---- write a pattern sector and read it back */
    xor ax, ax
    mov es, ax
    mov di, 0x0600
    mov cx, 512
    mov al, 0x5a
3:  stosb
    add al, 0x3b
    loop 3b
    mov word ptr [count], 1
    mov bx, 0x0600
    mov ax, [write_lba]
    mov ch, 3                     /* function 3: write */
    call disk_io
    jc fail_io
    mov bx, 0x0a00
    mov ax, [write_lba]
    mov ch, 2
    call disk_io
    jc fail_io
    mov si, offset msg_write
    call puts
    mov si, 0x0600
    mov di, 0x0a00
    mov cx, 256
    cld
    repe cmpsw
    call verdict
    mov si, offset msg_pass
    cmp byte ptr [failed], 0
    je 4f
    mov si, offset msg_fail
4:  call puts
halt:
    cli
5:  hlt
    jmp 5b

fail_io:
    /* AH = BIOS status */
    mov [status], ah
    mov si, offset msg_io
    call puts
    mov al, [status]
    call puthex
    mov si, offset msg_fail
    call puts
    jmp halt

/* Print OK if ZF is set, else BAD and note the failure. */
verdict:
    mov si, offset msg_ok
    je puts
    mov byte ptr [failed], 1
    mov si, offset msg_bad
    /* fall through */
puts:
    lodsb
    or al, al
    jz 8f
    mov ah, 0x0e
    mov bx, 0x0007
    int 0x10
    jmp puts
8:  ret

/* INT 13h function CH (2 or 3) of [count] sectors at LBA AX to ES:BX,
 * with up to three attempts and a reset between them. CF and AH as INT 13h. */
disk_io:
    mov [func], ch
    mov [cur], ax
    mov byte ptr [tries], 3
6:  mov ax, [cur]
    xor dx, dx
    div word ptr [spt]            /* AX = lba / spt, DX = lba mod spt */
    mov cl, dl
    inc cl                        /* sector */
    xor dx, dx
    div word ptr [heads]          /* AX = cylinder, DX = head */
    mov ch, al                    /* cylinder (< 256) */
    mov dh, dl
    mov dl, [drive]
    mov ah, [func]
    mov al, [count]
    int 0x13
    jnc 7f
    dec byte ptr [tries]
    jz 7f
    push ax
    xor ax, ax
    mov dl, [drive]
    int 0x13
    pop ax
    jmp 6b
7:  ret

puthex:
    push ax
    shr al, 4
    call nibble
    pop ax
    and al, 0x0f
nibble:
    add al, '0'
    cmp al, '9'
    jbe 9f
    add al, 7
9:  mov ah, 0x0e
    mov bx, 0x0007
    int 0x10
    ret

msg_hello: .asciz "AT DISKETTE BOOT TEST\r\n"
msg_read:  .asciz "READ "
msg_write: .asciz "WRITE "
msg_ok:    .asciz "OK\r\n"
msg_bad:   .asciz "BAD\r\n"
msg_io:    .asciz "INT 13H ERROR "
msg_pass:  .asciz "PASS\r\n"
msg_fail:  .asciz "\r\nFAIL\r\n"

    .org 1024
