.code16
.global _start
_start:
    cli
    xor %ax,%ax
    mov %ax,%ds
    fninit
    movw $6,0x2100
    movw $7,0x2102
    fld1
    filds 0x2100
    fimuls 0x2102
    fmulp %st,%st(1)
    fistpl 0x2000
    fwait
    hlt
