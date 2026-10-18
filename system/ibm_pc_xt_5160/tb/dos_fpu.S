.code16
.global _start
_start:
    fninit
    filds six
    fimuls seven
    fistpl result
    fwait
    cmpw $42,result
    jne failed
    filds square
    fsqrt
    fistpl result
    fwait
    cmpw $13,result
    jne failed
    mov $success,%dx
    mov $9,%ah
    int $0x21
    mov $0x4c00,%ax
    int $0x21
failed:
    mov $failure,%dx
    mov $9,%ah
    int $0x21
    mov $0x4c01,%ax
    int $0x21
six:.word 6
seven:.word 7
square:.word 169
result:.long 0
success:.ascii "8087 PASS: 6*7=42; SQRT(169)=13\r\n$"
failure:.ascii "8087 FAIL\r\n$"
