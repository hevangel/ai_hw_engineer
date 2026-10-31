# BOUND and XLAT extension

Specification written before RTL. Intel 210498-005 section 4.2, section 5.2
and Appendix B (BOUND B-22, XLAT B-115) define these operations. The primary
manual is linked in the chip README.

62 /r BOUND compares the signed word register selected by ModR/M.reg against
two contiguous signed words at the effective address, lower then upper. Both
endpoints are inclusive. In-range execution preserves registers and flags.
An out-of-range value delivers real-mode vector 5, with the saved CS:IP naming
the first byte of the instruction, including prefixes, and no retirement of
the faulting instruction. Invalid register second operands retain the current
development invalid-encoding stop until general #UD delivery is implemented.
Four-byte operand accesses starting above FFFC retain the current limit
diagnostic. They must not fetch a partial operand or wrap into another segment.

D7 XLAT reads one byte at DS:(BX + unsigned AL), with 16-bit offset arithmetic,
and replaces AL only. Segment overrides apply, including the hidden reset CS
base. AH, BX, the other registers and all flags are preserved. Offset FFFF is
valid for a byte. The functional bus performs exactly one data read and no
write. This does not define silicon cycle timing.

Independent Unicorn vectors cover all AL table indices, segment overrides,
offset wrap, address modes, signed BOUND endpoints and reversed ranges.
Out-of-range restart/handler tests use the manufacturer's vector/frame rules,
assert exact saved instruction PC, preserve source registers/flags, and execute
the handler's IRET and next instruction. The full completion ledger is unchanged.
