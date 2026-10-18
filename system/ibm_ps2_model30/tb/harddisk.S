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
    movb $1,0x400
    # Recalibrate and read the 14-byte SSB through programmed I/O.
    mov $recalibrate,%si
    call ccb
    call finished
    call sense
    cmpb $26,0x220c
    jne failure
    cmpb $0x41,0x2200
    jne failure
    # Real CPU creates a 1,024-byte source in nonzero DMA page 5, odd address.
    mov $0x5000,%ax
    mov %ax,%es
    mov $0x1201,%di
    mov $1024,%cx
    xor %ax,%ax
1:  stosb
    inc %al
    loop 1b
    # Channel 3, single memory-to-I/O, crosses head and cylinder boundary.
    xor %al,%al
    out %al,$0x0d
    out %al,$0x08
    out %al,$0x0c
    mov $0x1201,%ax
    out %al,$6
    mov %ah,%al
    out %al,$6
    mov $0xff,%al
    out %al,$7
    mov $3,%al
    out %al,$7
    mov $5,%al
    out %al,$0x82
    mov $0x4b,%al
    out %al,$0x0b
    mov $3,%al
    out %al,$0x0a
    mov $0x322,%dx
    mov $1,%al
    out %al,%dx
    movb $2,0x400
    mov $write_two,%si
    call ccb
    call ready
    call finished
    # Read both sectors to page 6, again exercising both RAM byte lanes.
    xor %al,%al
    out %al,$0x0c
    mov $0x2301,%ax
    out %al,$6
    mov %ah,%al
    out %al,$6
    mov $0xff,%al
    out %al,$7
    mov $3,%al
    out %al,$7
    mov $6,%al
    out %al,$0x82
    mov $0x47,%al
    out %al,$0x0b
    mov $3,%al
    out %al,$0x0a
    movb $3,0x400
    mov $read_two,%si
    call ccb
    call ready
    call finished
    movb $4,0x400
    mov $verify_two,%si
    call ccb
    call finished
    # Invalid command must report bit 6 and recover for a subsequent command.
    mov $invalid,%si
    call ccb
    call wait_idle
    mov $0x324,%dx
    in %dx,%al
    cmp $0x40,%al
    jne failure
    mov $read_id,%si
    call ccb
    call finished
    call sense
    cmpb $1,0x2203
    jne failure
    cmpb $1,0x2205
    jne failure
    # Native PIC IRQ5 acknowledgement, including CCB acceptance/completion.
    movw $interrupt,0x34
    movw $0,0x36
    mov $0x13,%al
    out %al,$0x20
    mov $8,%al
    out %al,$0x21
    mov $1,%al
    out %al,$0x21
    mov $0xdf,%al
    out %al,$0x21
    mov $0x322,%dx
    mov $2,%al
    out %al,%dx
    movb $0,0x401
    sti
    mov $seek,%si
    call ccb
2:  cmpb $2,0x401
    jb 2b
    cli
    movb $0x5a,0x400
    hlt
next:
    nop
failure:
    .byte 0x60
ccb:
    mov $0x324,%dx
    mov $0x80,%al
    out %al,%dx
    mov $0x320,%dx
    mov $6,%cx
3:  lodsb
    out %al,%dx
    loop 3b
    ret
ready:
    mov $0x324,%dx
    mov $0x10,%al
    out %al,%dx
    ret
wait_idle:
    mov $0x322,%dx
4:  in %dx,%al
    test $4,%al
    jnz 4b
    ret
finished:
    call wait_idle
    mov $0x324,%dx
    in %dx,%al
    test %al,%al
    jnz failure
    ret
sense:
    push %es
    xor %ax,%ax
    mov %ax,%es
    mov $0x324,%dx
    mov $0x20,%al
    out %al,%dx
    mov $0x320,%dx
    mov $0x2200,%di
    mov $14,%cx
5:  in %dx,%al
    stosb
    loop 5b
    pop %es
    ret
interrupt:
    push %ax
    push %dx
    mov $0x324,%dx
    in %dx,%al
    incb 0x401
    mov $0x20,%al
    out %al,$0x20
    pop %dx
    pop %ax
    iret
recalibrate: .byte 0x80,0,0,1,2,1
write_two:   .byte 0x95,0x30,0,17,2,2
read_two:    .byte 0x15,0x30,0,17,2,2
verify_two:  .byte 0x25,0x30,0,17,2,2
invalid:     .byte 0x60,0,0,1,2,1
read_id:     .byte 0x55,0,1,1,2,1
seek:        .byte 0xe0,0,2,1,2,1
    .word next
