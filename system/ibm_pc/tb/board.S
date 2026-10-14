.code16
.arch i8086
.section .text
.global _start
_start:
    cli
    xor %ax,%ax
    mov %ax,%ds
    mov $0x1234,%ax
    mov %ax,0x2001
    mov %ax,0x2010
    xor %ax,%ax
    mov 0x2001,%ax
    cmp $0x1234,%ax
    jne failure
    mov $0xfe00,%ax
    mov %ax,%ds
    movb $0,0
    xor %ax,%ax
    mov %ax,%ds
    mov $0x13,%al
    out %al,$0x20
    mov $8,%al
    out %al,$0x21
    mov $9,%al
    out %al,$0x21
    mov $0xff,%al
    out %al,$0x31
    in $0x21,%al
    cmp $0xff,%al
    jne failure
    mov $0x99,%al
    out %al,$0x63
    mov $0x80,%al
    out %al,$0x61
    in $0x60,%al
    mov %al,0x2100
    mov $0x40,%al
    out %al,$0x61
wait_key:
    in $0x60,%al
    cmp $0x1e,%al
    jne wait_key
    mov %al,0x2101
    mov $0xc0,%al
    out %al,$0x61
    mov $0x40,%al
    out %al,$0x61
    in $0x60,%al
    mov %al,0x2102
    # The DOR selects physical drive B even when FDC command US names unit 0.
    mov $0x3f2,%dx
    mov $0x2d,%al
    out %al,%dx
    mov $2000,%cx
1:  loop 1b
    mov $0x3f4,%dx
    .macro fdc_byte byte
2:  in %dx,%al
    test $0x80,%al
    jz 2b
    test $0x40,%al
    jnz failure
    inc %dx
    mov $\byte,%al
    out %al,%dx
    dec %dx
    .endm
    fdc_byte 3
    fdc_byte 0xf1
    fdc_byte 0
    fdc_byte 0x0f
    fdc_byte 0
    fdc_byte 1
    mov $2000,%cx
3:  loop 3b
    jmp success
failure:
    .byte 0x60
success:
    hlt
