.code16
.arch i8086
.section .text
.global _start
_start:
    cli
    xor %ax,%ax
    mov %ax,%ds
    mov %ax,%ss
    mov $0x4000,%sp
    # Model 30 CCR bit 1 selects 250 kbit/s for the physical 720K media.
    mov $0x3f7,%dx
    mov $2,%al
    out %al,%dx
    xor %al,%al
    # Single transfer, memory -> FDC, channel 2: 36 CHRN bytes on physical head 1.
    out %al,$0x0d
    out %al,$0x08
    out %al,$0x0c
    mov $0x5000,%ax
    mov %ax,%es
    mov $0x1200,%di
    mov $ids,%si
    mov $36,%cx
    rep movsb
    mov $0x1200,%ax
    out %al,$0x04
    mov %ah,%al
    out %al,$0x04
    mov $35,%al
    out %al,$0x05
    xor %al,%al
    out %al,$0x05
    mov $5,%al
    out %al,$0x81
    mov $0x4a,%al
    out %al,$0x0b
    mov $2,%al
    out %al,$0x0a
    mov $0x3f2,%dx
    mov $0x2d,%al
    out %al,%dx
    mov $2000,%cx
1:  loop 1b
    mov $0x3f4,%dx
    mov $commands,%si
    mov $9,%cx
send:
    in %dx,%al
    test $0x80,%al
    jz send
    test $0x40,%al
    jnz failure
    inc %dx
    lodsb
    out %al,%dx
    dec %dx
    loop send
    mov $0x2200,%di
    mov $7,%cx
receive:
    in %dx,%al
    and $0xc0,%al
    cmp $0xc0,%al
    jne receive
    inc %dx
    in %dx,%al
    mov %al,(%di)
    inc %di
    dec %dx
    loop receive
    # IBM BIOS verify uses 8237 pseudo-transfers: DACK/TC, no RD/WR strobes.
    xor %al,%al
    out %al,$0x0c
    out %al,$0x04
    mov $0x30,%al
    out %al,$0x04
    mov $0xff,%al
    out %al,$0x05
    mov $0x11,%al
    out %al,$0x05
    mov $0x42,%al
    out %al,$0x0b
    mov $2,%al
    out %al,$0x0a
    mov $verify_commands,%si
    mov $9,%cx
send_read:
    in %dx,%al
    test $0x80,%al
    jz send_read
    test $0x40,%al
    jnz failure
    inc %dx
    lodsb
    out %al,%dx
    dec %dx
    loop send_read
    mov $0x2210,%di
    mov $7,%cx
receive_read:
    in %dx,%al
    and $0xc0,%al
    cmp $0xc0,%al
    jne receive_read
    inc %dx
    in %dx,%al
    mov %al,(%di)
    inc %di
    dec %dx
    loop receive_read
    # Actual I/O->RAM DMA into a different nonzero 64K page.
    xor %al,%al
    out %al,$0x0c
    out %al,$0x04
    mov $0x41,%al
    out %al,$0x04
    mov $0xff,%al
    out %al,$0x05
    mov $0x11,%al
    out %al,$0x05
    mov $6,%al
    out %al,$0x81
    mov $0x46,%al
    out %al,$0x0b
    mov $2,%al
    out %al,$0x0a
    mov $read_commands,%si
    mov $9,%cx
send_dma_read:
    in %dx,%al
    test $0x80,%al
    jz send_dma_read
    test $0x40,%al
    jnz failure
    inc %dx
    lodsb
    out %al,%dx
    dec %dx
    loop send_dma_read
    mov $0x2220,%di
    mov $7,%cx
receive_dma_read:
    in %dx,%al
    and $0xc0,%al
    cmp $0xc0,%al
    jne receive_dma_read
    inc %dx
    in %dx,%al
    mov %al,(%di)
    inc %di
    dec %dx
    loop receive_dma_read
    jmp success
failure:
    .byte 0x60
commands:
    .byte 3,0xcf,0,0x4d,5,2,9,0x50,0xe5
verify_commands:
    .byte 0xe6,1,0,0,1,2,9,0x2a,0xff
read_commands:
    .byte 0x66,5,0,1,1,2,9,0x2a,0xff
ids:
    .byte 0,1,1,2, 0,1,2,2, 0,1,3,2, 0,1,4,2
    .byte 0,1,5,2, 0,1,6,2, 0,1,7,2, 0,1,8,2, 0,1,9,2
success:
    hlt
