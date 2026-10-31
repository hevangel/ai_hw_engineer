# Protected I/O privilege and FLAGS restoration

## Scope

Implement the 80286 protected-mode I/O privilege checks for `IN`, `OUT`,
`INS`, and `OUTS`, plus the related `CLI`/`STI`, `POPF`, and `IRET` flag
rules needed to establish and preserve IOPL. The authority is Intel's
[80286 and 80287 Programmer's Reference Manual, order 210498-005](https://bitsavers.org/components/intel/80286/210498-005_80286_and_80287_Programmers_Reference_Manual_1987.pdf),
especially §§3.11.1, 3.11.3, 4.1 and 10.1.

This slice does not implement task switching, the 80386 I/O permission
bitmap, LOCK-prefix privilege, complete native port timing, or all FLAGS/NT
semantics outside the IOPL and IF rules below.

## I/O privilege

In protected mode, the FLAGS IOPL field (`FLAGS[13:12]`) is the greatest
numeric CPL allowed to use the I/O instructions. `IN`, `OUT`, `INS`, and
`OUTS` are allowed when `CPL <= IOPL`. When `CPL > IOPL`, raise restartable
`#GP(0)` with the saved IP at the first prefix/opcode byte. Do not issue an
I/O bus request or change an I/O destination before the fault is delivered.
In real-address mode, these IOPL checks do not apply.

For string I/O, apply the privilege check before the first element's memory
or I/O transfer, including a repeated instruction. Existing iteration,
address-update, and memory-fault restart rules remain otherwise unchanged.

## FLAGS restoration

- `POPF` and `IRET` may load IOPL only when executing at CPL 0 in protected
  mode. At other CPLs, preserve the existing IOPL value.
- `POPF` and `IRET` may change IF when executing in real-address mode or when
  protected-mode `CPL <= IOPL`. Otherwise preserve the existing IF value.
- Preserve the existing real-mode behavior for IOPL and NT. NT task-return
  semantics are outside this slice.

## Directed evidence

Cover every CPL/IOPL pair for byte and word register-port `IN`/`OUT`. For
allowed cases, check exact port, direction, width, data and successor. For
denied cases, check the exact restartable `#GP(0)` packet, no port transfer,
no destination update and no retirement. Add denied and allowed byte/word
`INS`/`OUTS` cases, including repeated forms. Check `CLI`/`STI` denial before
IF changes, protected CPL-0 IOPL updates through `POPF`/`IRET`, and ignored
IF/IOPL changes at restricted CPLs. Run each directed scenario in both READY
modes.

Directed simulation does not close native I/O timing, task switching, the
full privilege matrix for other instructions, connected-core formal proof,
or the full release gate.
