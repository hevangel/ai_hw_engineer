# PDP-8 (1965) Am29xx reconstruction — specification

Status: implemented and verified for the architectural profile below. This
document pins the machine the RTL implements; where the primary sources are
silent or contradictory the choice is recorded in the assumption ledger.

## 1. Machine profile

| Property | Value | Source |
| --- | --- | --- |
| Model | PDP-8, 1965 original ("straight-8") | D. W. Jones, *PDP-8 FAQ* (https://homepage.divms.uiowa.edu/~jones/pdp8/faqs/) lists PDP-8, 1965, 12 bits, 4K |
| Word size | 12 bits | DEC PDP-8 handbook; Jones FAQ, "The PDP-8 word size is 12 bits" |
| Memory | 4096 words of core (one field) | DEC PDP-8 handbook; Jones FAQ, "the basic memory is 4K words" |
| Arithmetic | two's complement, 13-bit link/accumulator | DEC PDP-8 handbook |
| Registers | PC, AC (12 bits), LINK (1 bit) architecturally; MA, MB, IR internally | Jones FAQ register list |
| EAE | absent (group 3 is a no-op) | Jones, *PDP-8 Microcoded Instructions*, "On all models of PDP-8 prior to the PDP-8/E, the group three instructions were only implemented if the EAE option was present. If this option is absent ... all group three instructions become no-ops." |
| Byte swap (BSW) | absent | same page: BSW "is only supported by the PDP-8/E and later models" |
| Memory extension, user mode, time-share | absent | straight-8 has no MMU; the KM8-E/TSC8-75 options are later |
| Interrupts | one level, vector through location 0, one-instruction delay after ION | Jones FAQ, "In effect, an interrupt is a JMS instruction to location zero ... The effect of ION is delayed so that interrupts are not enabled until after the JMP"; SIMH `pdp8_cpu.c` |
| I/O | program transfer, devices 00-04 | DEC device assignments; SIMH `PDP8/pdp8_pt.c`, `PDP8/pdp8_tt.c` |

No claim of cycle-for-cycle identity with the original transistor machine is
made. The microcode is a functional microprogram; see section 7.

## 2. Instruction formats

```
 11 10  9  8  7  6 ................................ 0
+---------+--+--+----------------------------------+
| opcode  | i| z|            address (7 bits)      |   memory reference
+---------+--+--+----------------------------------+
```

- `opcode` bits 11-9: `000` AND, `001` TAD, `010` ISZ, `011` DCA, `100` JMS,
  `101` JMP, `110` IOT, `111` OPR.
- `i` (bit 8, mask 0400): indirect.
- `z` (bit 7, mask 0200): current page when set, page zero when clear.
- address: offset in a 128-word page.

### Effective address

`PA = (z ? PC[11:7] : 0) | address`, using the page of the **instruction**, not
of the incremented PC, so an instruction in the last word of a page with `z`
set still addresses its own page (SIMH keeps `MA = IF|PC` from before the
increment for exactly this reason).

Indirect (`i = 1`): the word at `PA` supplies the address, except that page-zero
locations 0010-0017 are auto-index: the word is incremented first and the
incremented value is used as the address. On a 4K machine only 0010-0017 can
be auto-index locations.

### Memory reference semantics

| Opcode | Action |
| --- | --- |
| AND | `AC = AC & M[EA]` (LINK preserved) |
| TAD | `L'AC = L'AC + M[EA]` (13-bit) |
| ISZ | `M[EA] = M[EA] + 1`; skip if the result is zero |
| DCA | `M[EA] = AC; AC = 0` (LINK preserved) |
| JMS | `M[EA] = PC; PC = EA + 1` |
| JMP | `PC = EA` |

## 3. Operate instructions

### Group 1 (bit 8 clear)

Bit masks: CLA `0200`, CLL `0100`, CMA `0040`, CML `0020`, RAR `0010`,
RAL `0004`, BSW/double `0002`, IAC `0001`.

Order of execution, from the DEC programming note reproduced in *PDP-8
Computer and Teletype ASR-33 Programming Info* ("Order of Execution of
Combined Group 1 Instructions: 1) CLA, CLL 2) CMA, CML 3) IAC 4) RAR, RAL,
RTR, RTL") and Jones's numbering (CLA/CLL = 1, CMA/CML = 2, IAC = 3, shifts = 4):

1. CLA clears AC; CLL clears LINK.
2. CMA complements AC; CML complements LINK.
3. IAC increments the 13-bit LINK/AC (LINK = LINK xor carry out).
4. Shift: `0010` RAR, `0004` RAL, `0100` + `0010` (i.e. `0012`) RTR, `0004` +
   `0002` (i.e. `0006`) RTL.

`0002` alone is byte swap on a PDP-8/E; on this profile it does nothing.

### Group 2 (bit 8 set, bit 0 clear)

Skip conditions are ORed and then inverted by the reverse-sense bit `0010`:

```
skip = ( (0010 & reverse) xor
         ((0020 and LINK) or (0040 and AC == 0) or (0100 and AC[11])) )
```

Then `0200` clears AC, `0004` ORs the switch register into AC, and `0002`
halts. The skip test happens before the clear, matching the hardware and SIMH.

### Group 3 (bit 8 and bit 0 set)

No-op on this profile because the EAE is absent (see the table in section 1).

## 4. I/O devices

Device number is bits 8-3, pulse bits 2-0. Pulse bit 0 (`1`) tests and skips on
flag, bit 1 (`2`) clears a flag or returns a buffer, bit 2 (`4`) starts a
transfer.

| Device | Instruction | Meaning |
| --- | --- | --- |
| 00 | 6001 ION | enable interrupts, one instruction delayed |
| 00 | 6002 IOF | disable interrupts |
| 01 | 6011 PRS | skip if the reader has a character |
| 01 | 6012 RRB | clear the reader flag, OR the buffer into AC |
| 01 | 6014 RFC | start the next reader read |
| 02 | 6021 PPS | skip if the punch is ready |
| 02 | 6022 PPB | punch AC[7:0] |
| 03 | 6031 KSF | skip if a key is available |
| 03 | 6032 KCC | clear the keyboard flag and AC |
| 03 | 6034 KRS | OR the keyboard buffer into AC |
| 03 | 6036 KRB | KCC + KRS |
| 04 | 6041 TSF | skip if the printer is ready |
| 04 | 6042 TCF | clear the printer flag |
| 04 | 6044 TPC | print AC[7:0] |
| 04 | 6046 TLS | TCF + TPC |

Pulse decoding and the KCC accumulator clear follow SIMH's `ptr`, `ptp`, `tti`
and `tto` routines; the bootstrap sequence in `pdp8_pt.c` confirms that RFC
loads the next character while RRB returns the previous one.

The printer flag is set at power-on ("printer idle"), which makes the
ubiquitous `TSF / JMP .-1 / TLS` idiom work without a priming character.

Character timing is not modelled: a printed or punched character completes in
the strobe cycle and the flag is valid in the next cycle. The real ASR-33 runs
at 110 baud.

## 5. Interrupt

`irq = interrupt_enable and any device flag and not ion_delay and running`.
When taken at an instruction boundary:

1. `M[0] = PC`
2. `PC = 1`
3. interrupt enable cleared

The delay flip-flop is set by ION and cleared at the next instruction boundary,
so exactly one instruction executes between ION and the first possible
interrupt (the usual `ION / JMP I return` idiom).

## 6. Front panel

Functional reconstruction, not a switch-for-switch copy:

- One 12-bit switch register supplies the address, the deposit data and the
  OSR operand. The original has separate address and data switch rows.
- LOAD ADDRESS: `PC = switches`.
- EXAMINE: display `M[PC]`, then `PC = PC + 1`.
- DEPOSIT: `M[PC] = switches`, then `PC = PC + 1`.
- START: master clear (AC, LINK, interrupt enable, microsequencer) then run at
  the current PC.
- STOP: stop at the next instruction boundary.
- CONTINUE: resume.
- STEP: execute exactly one instruction and stop.
- Lamps: PC, AC, MA, MB, and the last examined word, plus LINK, ION and RUN.

## 7. Implementation architecture

```
                 +---------------------------+
   switch reg -->|  pdp8_panel (keys, lamps) |
                 +-------------+-------------+
                               | pc/deposit/examine
+------------------------------v-------------------------------+
| pdp8_cpu                                                     |
|   3 x amd_am2901  (12-bit ALU, AC in R0, scratch in R1/R2)   |
|   amd_am2910      (11-bit control store address, 5-deep stack)|
|   pdp8_ucode      (87 x 72-bit microinstructions)            |
|   external PC, MA, MB, IR, LINK, page latch                  |
+------------------------------+-------------------------------+
                               | memory port
                 +-------------v-------------+
                 | pdp8_core 4096 x 12       |
                 +---------------------------+
                               |
                 +-------------v-------------+
                 | pdp8_console (01/02/03/04)|
                 +---------------------------+
```

### Timing

One microinstruction per clock. The Am2901 model latches its register-file read
ports while CP is high and writes the file while CP is low, so the
microinstruction is presented at the rising edge, the slice latches close at
the falling edge and the register file, LINK and the external registers commit
at that falling edge. The Am2910 advances on the rising edge, which keeps the
control-store address stable for the whole cycle.

The link is captured in `l_hold` at the rising edge so the slice's write-phase
shift input and carry input cannot change when the link updates at the falling
edge. Without that register the shifted word loses the incoming link bit.

### Pipeline

Fetch is `FETCH -> F_CHK -> F_MA -> F_INC -> dispatch`, then a subroutine call
to a shared effective-address routine, then the operation. A memory reference
instruction takes roughly 12-18 cycles depending on indirect/auto-index; operate
instructions take 7-11. This is not the 1.5 µs (or 1.6 µs with defer) of the
original machine.

### Control store

72-bit microinstructions, fields documented in `scripts/gen_microcode.py` and
`src/pdp8_microcode.asm`. The microcode is generated into
`src/pdp8_ucode.sv` by `scripts/gen_microcode.py`; do not edit the generated
file.

## 8. Assumption ledger

Every item below is a behaviour the primary documentation does not fully
state, or a deliberate simplification. Each is also marked in the RTL.

| # | Assumption | Basis | Consequence if wrong |
| --- | --- | --- | --- |
| A1 | Group-1 micro-operations execute in the order CLA/CLL, CMA/CML, IAC, shifts | DEC programming note; Jones's numbering | Only combined instructions that mix IAC with a rotate could differ. Jones notes that pre-PDP-8/I machines executed the shift simultaneously with IAC; portable code avoids the combination and no test in this repository relies on it. |
| A2 | Simultaneous RAR and RAL (`0014`) is undefined and treated as no operation | Hardware documentation calls it undefined; SIMH models it through an unrelated AND path | No software uses the encoding. |
| A3 | Group 3 is a no-op | Jones: no-op when the EAE option is absent | Correct for this profile; EAE is out of scope. |
| A4 | Byte swap (`0002`) does nothing | Jones: PDP-8/E feature | Correct for a straight-8. |
| A5 | Auto-index applies only to 0010-0017 of the field being addressed | SIMH tests the page offset of the pointer address; a 4K machine has one field | No change on this profile. |
| A6 | The printer flag is set at power-on | The standard `TSF/JMP .-1/TLS` idiom requires it; SIMH clears it, and DEC software prints a priming character | A program that expects a cleared flag would skip one TSF wait; harmless. |
| A7 | Characters complete instantly | Functional model, not electrical timing | Programs that depend on real 110-baud timing will run faster. |
| A8 | STOP takes effect at the next instruction boundary | Chosen for state integrity | The original can stop mid-instruction. |
| A9 | One 12-bit switch register instead of separate address/data rows | Panel simplification | OSR reads the same value the address field uses. |
| A10 | The core memory has independent read and write addresses | Lets the defer state's read-modify-write auto-index complete in one cycle | Program-visible order is unchanged; the real core is single-ported. |
| A11 | The Am2910's CI input is driven as an increment enable (1 = advance, 0 = branch) by the adapter | The Am2910 model loads micro-PC with Y+CI; the adapter documents the derivation and is unit-tested | None observed; `tb_seq` checks jump/call/return order. |
| A12 | Interrupt entry is modelled as three micro-operations; the return address is the next instruction | DEC: "an interrupt is a JMS to location zero" | None. |

## 9. Provenance

- DEC PDP-8 handbook material and the 1966 programming note reproduced in
  *PDP-8 Computer and Teletype ASR-33 Programming Info*
  (http://commons.princeton.edu/motorcycledesign/wp-content/uploads/sites/70/2018/07/PDP-8-Computer-and-ASR-33-Teletype-Programming-Info.pdf).
- D. W. Jones, *PDP-8 FAQ* and *PDP-8 Microcoded Instructions*,
  https://homepage.divms.uiowa.edu/~jones/pdp8/ (fetched 2026-11-04).
- SIMH `PDP8/pdp8_cpu.c`, `pdp8_pt.c`, `pdp8_tt.c`
  (https://github.com/simh/simh), MIT licence; the fetched CPU file is kept
  under `work/ref/` for the reference model's provenance.
- Am2900 family models reused from `design/amd_am29xx/amd_am2901` and
  `design/amd_am29xx/amd_am2910`; their own specifications and formal proofs
  are the authority for slice and sequencer behaviour.

The reference model in `scripts/pdp8_ref.py` is written from these external
sources, not from the RTL. It is the oracle for the per-instruction traces.
