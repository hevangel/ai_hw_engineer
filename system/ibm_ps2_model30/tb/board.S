.code16
.arch i8086
.global _start
_start:
    cli
    xor %ax,%ax
    mov %ax,%ds
    mov %ax,%es
    mov %ax,%ss
    mov $0x7c00,%sp
    mov $1,%bx
    # Stock 720K drive identification, independent of keyboard receive flags.
    mov $0x6a,%dx
    in %dx,%al
    test $1,%al
    jz fail
    # Native 16-bit lanes and the EU's exact odd-word split.
    movw $0xa55a,0x2000
    movb $0x33,0x2001
    cmpw $0x335a,0x2000
    jne fail
    movw $0x6789,0x2001
    cmpw $0x895a,0x2000
    jne fail
    cmpb $0x67,0x2002
    jne fail
    inc %bx
    # Serialized aligned word I/O: UART divisor low/high at 3F8/3F9.
    mov $0x3fb,%dx
    mov $0x80,%al
    out %al,%dx
    mov $0x3f8,%dx
    mov $0x1234,%ax
    out %ax,%dx
    in %dx,%ax
    cmp $0x1234,%ax
    jne fail
    mov $0x3fb,%dx
    mov $3,%al
    out %al,%dx
    inc %bx
    # 4 MHz DMA programming, both halves, reads, flip-flop and page latches.
    mov $0x0c,%dx
    out %al,%dx
    mov $4,%dx
    mov $0xabcd,%ax
    out %ax,%dx
    in %dx,%ax
    cmp $0xabcd,%ax
    jne fail
    mov $0x0c,%dx
    out %al,%dx
    mov $4,%dx
    mov $0x34,%al
    out %al,%dx
    mov $0x12,%al
    out %al,%dx
    in %dx,%al
    cmp $0x34,%al
    jne fail
    in %dx,%al
    cmp $0x12,%al
    jne fail
    mov $0x81,%dx
    mov $5,%al
    out %al,%dx
    in %dx,%al
    cmp $0xf5,%al
    jne fail
    inc %bx
    # ROM writes must not modify the original manufacturer ROM.
    mov $0xf000,%ax
    mov %ax,%es
    mov %es:0xfff0,%cx
    movw $0,%es:0xfff0
    cmp %es:0xfff0,%cx
    jne fail
    inc %bx
    # RAM region disable and real low-memory remapping.
    mov $0x4000,%ax
    mov %ax,%es
    movw $0x1234,%es:0
    mov $0x6b,%dx
    mov $2,%al
    out %al,%dx
    cmpw $0xffff,%es:0
    jne fail
    xor %al,%al
    out %al,%dx
    cmpw $0x1234,%es:0
    jne fail
    mov $0x2000,%ax
    mov %ax,%es
    movw $0x789a,%es:0
    mov $1,%al
    # Execute the remap check from unaffected ROM, then return after restoring.
    lcall $0xf000,$0x8000
    or %cx,%cx
    jne fail
    jmp remap_done
remap_check:
    out %al,%dx
    xor %cx,%cx
    cmpw $0x789a,0
    je 1f
    inc %cx
1:
    xor %al,%al
    out %al,%dx
    lret
remap_end:
remap_done:
    inc %bx
    # MCGA DAC RGB read/write and index/component auto-increment.
    mov $0x3c8,%dx
    mov $7,%al
    out %al,%dx
    inc %dx
    mov $0x11,%al
    out %al,%dx
    mov $0x22,%al
    out %al,%dx
    mov $0x33,%al
    out %al,%dx
    mov $0x3c7,%dx
    mov $7,%al
    out %al,%dx
    mov $0x3c9,%dx
    in %dx,%al
    cmp $0x11,%al
    jne fail
    in %dx,%al
    cmp $0x22,%al
    jne fail
    in %dx,%al
    cmp $0x33,%al
    jne fail
    inc %bx
    # IBM TR pp.1-51/1-55: 18h alone selects mode 6. Status is
    # 640-wide, double-scanned graphics (34h), not alpha/text (3Ch).
    mov $0x3d8,%dx
    mov $0x18,%al
    out %al,%dx
    mov $0x3d4,%dx
    mov $0x1810,%ax
    out %ax,%dx
    inc %dx
    in %dx,%al
    cmp $0x34,%al
    jne fail
    inc %bx
    # MCGA mode 13h maps linear A0000 and excludes B8000.
    mov $0x3d4,%dx
    mov $0x1910,%ax
    out %ax,%dx
    # Native 320-wide mode overrides the preceding legacy high-resolution bit.
    inc %dx
    in %dx,%al
    cmp $0x15,%al
    jne fail
    mov $0xa000,%ax
    mov %ax,%es
    movw $0x3456,%es:0x1234
    cmpw $0x3456,%es:0x1234
    jne fail
    mov $0xb800,%ax
    mov %ax,%es
    cmpw $0xffff,%es:0
    jne fail
    inc %bx
    # Register-controlled planar video disable removes its memory and I/O.
    mov $0x65,%dx
    mov $0x9b,%al
    out %al,%dx
    mov $0x3d4,%dx
    in %dx,%al
    cmp $0xff,%al
    jne fail
    mov $0x65,%dx
    mov $0x9f,%al
    out %al,%dx
    # Restore text mode before the subsequent font-plane load.
    mov $0x3d8,%dx
    mov $0x29,%al
    out %al,%dx
    mov $0x3d4,%dx
    mov $0x1810,%ax
    out %ax,%dx
    inc %bx
    # RTC RAM stays writable through native I/O without BIOS interception.
    mov $0xe9,%dx
    mov $0x87,%al
    out %al,%dx
    in %dx,%al
    cmp $0x87,%al
    jne fail
    inc %bx
    # Model 30 DIR echoes CCR, DMA-enable and the selected physical motor.
    mov $0x3f7,%dx
    mov $6,%al
    out %al,%dx
    mov $0x3f2,%dx
    mov $0x1c,%al
    out %al,%dx
    mov $0x3f7,%dx
    in %dx,%al
    and $0x0f,%al
    cmp $0x0e,%al
    jne fail
    mov $0x3f1,%dx
    in %dx,%al
    and $0x60,%al
    cmp $0x40,%al
    jne fail
    inc %bx
    # MCGA font self-load: sixteen scan-line planes, one explicit character.
    mov $0xa000,%ax
    mov %ax,%es
    xor %di,%di
    mov $16,%cx
    mov $0xa0,%dl
font_table:
    mov $3,%al
    stosb
    mov %dl,%al
    stosb
    inc %dl
    add $510,%di
    loop font_table
    mov $0x3d4,%dx
    mov $0x0014,%ax
    out %ax,%dx
    mov $0x0013,%ax
    out %ax,%dx
    mov $0xc012,%ax
    out %ax,%dx
    inc %dx
    mov $0xffff,%cx
font_wait:
    in %dx,%al
    test $0x80,%al
    jz font_done
    loop font_wait
    jmp fail
font_done:
    inc %bx
    # Model 30 gate-array receive/ack, reset, identity and scan-set protocol.
    mov $0xff,%al
    call keyboard_command
    call keyboard_response
    cmp $0xaa,%al
    jne fail
    mov $0xf2,%al
    call keyboard_command
    call keyboard_response
    cmp $0xab,%al
    jne fail
    call keyboard_response
    cmp $0x83,%al
    jne fail
    mov $0xf0,%al
    call keyboard_command
    mov $1,%al
    call keyboard_command
    # The BIOS LED-update sequence must preserve scan set 1.
    mov $0xf5,%al
    call keyboard_command
    mov $0xed,%al
    call keyboard_command
    mov $2,%al
    call keyboard_command
    mov $0xf4,%al
    call keyboard_command
    mov $0xf6,%al
    call keyboard_command
    mov $0xf0,%al
    call keyboard_command
    xor %al,%al
    call keyboard_command
    call keyboard_response
    cmp $1,%al
    jne fail
    inc %bx
    # UART loopback RX, modem status and RX interrupt identification.
    mov $0x3fc,%dx
    mov $0x1f,%al
    out %al,%dx
    mov $0x3f9,%dx
    mov $1,%al
    out %al,%dx
    mov $0x3f8,%dx
    mov $0xa5,%al
    out %al,%dx
    mov $0x3fa,%dx
    in %dx,%al
    cmp $4,%al
    jne fail
    mov $0x3f8,%dx
    in %dx,%al
    cmp $0xa5,%al
    jne fail
    mov $0x3fa,%dx
    in %dx,%al
    cmp $1,%al
    jne fail
    mov $0x3fe,%dx
    in %dx,%al
    and $0xf0,%al
    cmp $0xf0,%al
    jne fail
    movb $0x5a,0x400
success:
    hlt
    nop
fail:
    mov %bl,0x400
    hlt
    nop
keyboard_command:
    push %ax
    mov $0x69,%dx
    mov $0x10,%al
    out %al,%dx
    xor %al,%al
    out %al,%dx
    pop %ax
    mov $0x68,%dx
    out %al,%dx
    call keyboard_response
    cmp $0xfa,%al
    jne fail
    ret
keyboard_response:
    mov $0x6a,%dx
    mov $0xffff,%cx
keyboard_wait:
    in %dx,%al
    test $4,%al
    jnz keyboard_read
    loop keyboard_wait
    jmp fail
keyboard_read:
    mov $0x68,%dx
    in %dx,%al
    push %ax
    mov $0x66,%dx
    xor %al,%al
    out %al,%dx
    mov $0x40,%al
    out %al,%dx
    xor %al,%al
    out %al,%dx
    pop %ax
    ret
    .word remap_check,remap_end,success+1
