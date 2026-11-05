# Test plan — PDP-8 Am29xx reconstruction

Two independent evidence sources are used, and they are kept separate in the
report:

- **Architectural agreement** against `scripts/pdp8_ref.py`, an instruction-set
  model written from DEC/SIMH documentation, not from the RTL.
- **Directed** tests whose expected result comes from the documented device
  contract (console/paper-tape transcripts, panel operations, interrupt entry).

## 1. Instruction-set agreement

| Test | Coverage | Oracle |
| --- | --- | --- |
| `opr_group1` | Every group-1 encoding `7000`-`7377` except the undefined double-rotate combination, from two starting AC/LINK states (`5252`/L=1 and `7777`/L=0) | reference model |
| `opr_group2` | Every group-2 encoding without HLT, from three states (AC=5252/L=1, AC=0/L=0, AC=4001/L=0), each followed by a NOP landing pad for the skip | reference model |
| `addressing` | Direct page zero, direct current page, indirect page zero, indirect current page, auto-index through 0010/0011 twice, page-boundary instruction at 0277, ISZ with and without a zero result, AND with zero | reference model |
| `control` | JMS direct, JMS indirect, JMP direct, JMP indirect, subroutine return through the first word, ISZ skip | reference model |
| `random_000`-`random_039` | Straight-line pseudo-random programs mixing all memory-reference opcodes, both addressing modes, group-1 and group-2 operate encodings | reference model |

The comparison is exact and per instruction: PC, AC and LINK at every
instruction boundary, plus the trace length (so a missing or extra instruction
fails the test).

## 2. Console and paper tape

| Test | Checks |
| --- | --- |
| `console_print` | `TSF / JMP .-1 / TLS` prints "HI" |
| `console_echo` | `KSF / KRB` reads a queued key and prints it back |
| `reader_fetch` | `RFC / RSF / RRB` consumes the paper-tape image without hanging |

## 3. Front panel and interrupt (`tb/tb_panel.sv`)

| Check | Expected |
| --- | --- |
| DEPOSIT five words with the switch register, then EXAMINE them | the same words come back and PC advances |
| START the deposited program | it halts with the stored value in memory |
| STEP twice | PC advances one instruction per press, AC shows the accumulated result |
| CONTINUE | runs to HLT |
| Interrupt with a queued key and ION | the handler at location 1 runs after exactly one instruction following ION, saves the return address in 0, punches the key, and returns through `JMP I 0` |

## 4. Build gates

- `verilator --lint-only -Wall` with documented waivers (the Am2901 transparent
  latch structure).
- Yosys synthesis of the CPU, console and panel with the core memory as an
  external interface.

## 5. What these tests cannot show

- The reference model shares SIMH's reading of ambiguous encodings. Where the
  two agree the result is "consistent with SIMH", not "proven against the
  original hardware". The assumption ledger lists those items.
- No DEC diagnostic or historical application has been run yet, so a shared
  misreading of the manual between the RTL and the model is still possible.
- Character timing, front-panel switch bounce and analog core behaviour are not
  modelled.

See [../report/final_report.md](../report/final_report.md) for the recorded
results.
