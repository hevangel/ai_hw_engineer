# CPL1/CPL2 protected event delivery — 2026-10-28

## Result

The strict Verilator runner build, five focused event slices and the full
default bootstrap pass. Four reachable CPL1/CPL2 matrices add 48 executions:
16 software-INT cases, 16 privileged-LIDT exception cases, 8 external-INTR
cases and 8 NMI cases. This change is testbench and documentation only; no RTL
changed.

Intel 210498-005 §9.4 distinguishes software `INT n` gate-DPL checks from
processor exceptions: `INT n` is allowed when CPL is no greater than the gate
DPL, while a rejected instruction raises #GP with the IDT selector error code.
Exception delivery then ignores the gate DPL. A second matrix confirms that a
privileged `LIDT` at CPL1/CPL2 raises #GP(0) through a type-6 or type-7 gate
even when its DPL is 0 or 3; the instruction's pseudo-descriptor operand is
not read. Figure 9-4 shows the saved SS:SP, FLAGS, CS, IP and optional
error-code frame for a privilege transition. The scanned manual was visually
reviewed through Playwright CLI.

## Coverage

Each scenario reaches CPL1 or CPL2 using a real outer-level IRET, loads a real
286 TSS, and executes `INT 13h`. The matrix crosses interrupt gate type 6 and
trap gate type 7, the allowed boundary (gate DPL equal to CPL), the denied
boundary (gate DPL one level more privileged), and READY asserted/stalled.

- The allowed software INT enters the ring-0 handler without an error word,
  saves the post-INT IP, and returns through a five-word outer frame.
- The denied software INT raises restartable #GP with error code `006A`,
  saves the INT instruction IP, and enters the same ring-0 handler despite the
  handler gate's lower DPL. The handler discards the error word, advances the
  saved IP by the two-byte INT length, and returns through the six-word frame.
- Both paths check TSS SP0:SS0 reads before new-stack descriptor validation
  and frame writes, exact frame bytes and order, saved CS:IP:FLAGS:SP, IF/TF
  behavior, no writes to the interrupted CPL1/CPL2 stack, restored SS:SP and
  FLAGS, and execution of the exact successor NOP.

The `--protected-event-ring12-exception` matrix reaches CPL1/CPL2
the same way, then executes a five-byte privileged `LIDT` memory form. It
crosses interrupt/trap gates, gate DPL 0/3 and both READY policies. All 16
cases require restartable #GP(0), no LIDT operand read, a six-word outer frame
including the zero error word, TSS stack selection before frame writes,
gate-specific IF/TF behavior, and handler repair plus IRET to the exact NOP
successor. This confirms processor-exception delivery ignores IDT gate DPL at
both nonzero privilege levels.

The `--protected-event-ring12-external` matrix asserts external INTR after
entering CPL1/CPL2 and presents vector 13 through a DPL-0 type-6 or type-7
gate. All eight cases require the first NOP to retire before INTR is sampled,
then check a no-error outer frame whose saved IP is the exact successor. They
also check that TSS SP0:SS0 is read before the ring-0 stack descriptor and
frame writes, that the interrupted ring-level stack is untouched, that the
gate applies the expected IF/TF behavior, and that outer IRET restores the
ring-level state before executing the successor NOP. READY is asserted and
stalled in separate cases. This exercises external-interrupt delivery through
a gate whose DPL is below the interrupted CPL.

The `--protected-event-ring12-nmi` matrix tests NMI vector 2 through the same
DPL-0 interrupt/trap gate types. Its eight cases require the NMI request to be
delivered without an acknowledge transaction, then verify the no-error outer
frame, TSS SP0:SS0 selection, untouched interrupted stack, gate IF/TF behavior
and outer IRET to the exact successor. The test also checks that NMI service
is blocked on handler entry and released by the valid outer IRET. READY is
asserted and stalled in separate cases.

This was a narrow protected-event slice. A follow-up on 2026-10-29 added basic
external-INTR and software-INT/#GP delivery through an IDT task gate; see the
[task-gate event report](2026-10-29-task-gate-event-delivery.md). Other
CPL1/CPL2 processor exceptions and external vectors, nested fault handling
during a stack or task switch, native interrupt-pin timing, and current-source
connected-core formal closure remain open.

## Reproduction and evidence

The strict Verilator 5.052 runner was built with `-Wall`; its build manifest
fingerprint is `198170ebacb7`. The build command was
`INTEL_80286_WORK_DIR=/work/design/intel_80286/work/selector_ring12_dev_20261028 sh design/intel_80286/scripts/build_runner.sh`.
The exact focused and full-bootstrap logs and
manifest are preserved under
`design/intel_80286/work/selector_ring12_dev_20261028/`:

- `protected_event_ring12.log` — `--protected-event-ring12`, 16 cases;
  SHA-256 `a2c543fb71718d53f8ece827d15aba59d8010db39c2d8c07e4171b7a26f55d75`.
- `protected_event_ring12_exception.log` —
  `--protected-event-ring12-exception`, 16 cases; SHA-256
  `7f037c7f2f960931bba2f1ba662f75f2ae62259c69ee3b2dba270e739e2cb963`.
- `protected_event_ring12_external.log` —
  `--protected-event-ring12-external`, 8 cases; SHA-256
  `007b7cb074db8fae4c35eb4e87c2f17b9484bd149bab80d5e31dc3324ee7c6ad`.
- `protected_event_ring12_nmi.log` — `--protected-event-ring12-nmi`, 8 cases;
  SHA-256 `e192218c17805b8912c867a372bb6fb6ec6041291909fc9b51fb7336adfbb180`.
- `protected_event_outer.log` — existing CPL3 event regression;
  SHA-256 `049b850db9bc1df1ee0aeeddc29c23ff4c48841100cc34370cf08a67e2184f9b`.
- `full_bootstrap.log` — complete default bootstrap;
  SHA-256 `8f307eba64dbe373ffa6c851de4feb45e09601692363e1afc4b49a555bab765a`.
- `sim/build_manifest.json` — SHA-256
  `a223333eee75b86ea6fdf9c40794a5ee416177ee10d397d3c9bc127f9f8f8574`;
  runner SHA-256 `d362b6b91fcfd3cb56f03a69618267df442d18f87113a8c49017390a99d5401b`.
- Current `tb/bootstrap.cpp` SHA-256:
  `66627e4a7d3de610873e7f789ca15bda4832214f5da47f79c7b874e13bc9944d`.

The source remains in `tb/bootstrap.cpp`; focused invocations are
`work/selector_ring12_dev_20261028/sim/Vintel_80286 --protected-event-ring12`
and the corresponding `--protected-event-ring12-exception`,
`--protected-event-ring12-external`, `--protected-event-ring12-nmi` and
`--protected-event-outer` options.
The complete `run_all.sh` release gate and exact-source connected-core
formal audit have not been rerun. The still-running whole-core PDR uses an
older 21-file snapshot and is not evidence for this source.
The issue checkpoint is
[comment 6472602584](https://github.com/hevangel/ai_hw_engineer/issues/80#issuecomment-6472602584).
No GitHub project fields were changed in this checkpoint.

## Source

Intel, *80286 and 80287 Programmer's Reference Manual*, order 210498-005,
§9.4 and Figure 9-4: [scanned manual](https://bitsavers.org/components/intel/80286/210498-005_80286_and_80287_Programmers_Reference_Manual_1987.pdf#page=166).
