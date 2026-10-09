/* Intel 8086 Family User's Manual, Oct 1979, figure 2-63.
 * GNU assembler syntax; explicit LOC-86 placement values; see README.md. */
.intel_syntax noprefix
.code16
.text
mov ax, 0x2000
mov ds, ax
mov es, ax
mov ax, 0x3000
mov ss, ax
mov sp, 200
hlt /* Test sentinel outside the historical sequence. */
