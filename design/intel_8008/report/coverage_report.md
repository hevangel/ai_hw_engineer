# Coverage Report: Intel 8008

## Opcode family coverage

`scripts/make_scelbal_vectors.py` counts every opcode the 200,000-instruction
authentic SCELBAL trace executes (`build/scelbal_opcount.txt`, 42 distinct
opcodes) and maps the counts onto the spec's defined instruction families
(review F3). Result of the measured run:

| Family | SCELBAL trace | Directed test |
|---|---|---|
| Lds move (11dddsss) | 841 executions, 12 opcodes | — |
| LdI immediate (00ddd110) | 791, 5 opcodes | LMI, LAI/LBI/LHI/LLI |
| INr (00ddd000, ddd≠7) | 126, 3 opcodes | INB |
| DCr (00ddd001, ddd≠7) | 96,213, 2 opcodes | — |
| ALU register (10ooosss) | 540, 3 opcodes | ADI-register path, CPI |
| ALU immediate (00ooo100) | 682, 2 opcodes | ADI, CPI |
| Rotates (02/0a/12/1a) | 1,428, 4 opcodes | RLC |
| JMP unconditional | 118 | — |
| JMP conditional | 96,525, 4 opcodes | JTZ |
| CAL unconditional | 813 | CAL |
| RET unconditional | 747 | RET |
| RET conditional false (RFc) | 63 | RFZ both senses |
| RET conditional true (RTc) | 1 | RTZ both senses |
| INP (input group) | 475 | OUT path |
| OUT (output latch) | 637 | OUT 8 |
| HLT (000/001/377) | absent (SCELBAL does not halt in-window) | HLT entry, wake, re-halt |
| ALU memory (10ooo111) | absent | ADM, CPM |
| CAL conditional | absent | CFc taken, CTc not-taken |
| RST (00eee101) | absent | RST 6 and RST 7 injection |

Union across both regressions: **19/19 defined families**, with both senses of
the conditional returns exercised taken and not-taken at the RTL level. The
SCELBAL profile confirms the review's suspicion (F3): with inputs tied to
zero, 96% of the 200,000 instructions are the DCR/JMP delay-loop pair around
console polling, so authentic-software execution alone would silently miss
whole families. `--strict-coverage` fails vector generation if the
authentic-software run ever loses a family it covers today; feeding scripted
console input to run a parsed BASIC program remains the path to deeper
authentic coverage.

The single RTc in the SCELBAL trace executes not-taken, which is why the
pre-review RTL defect (true-sense returns decoded as NOP) never surfaced in
this regression; the directed test now covers the taken path explicitly.

## State coverage

The SCELBAL regression compares, at every instruction boundary: PC, all seven
registers, all four flags, and stack depth; after 200,000 instructions it
compares all 16,384 memory bytes. The directed regression additionally checks
exact post-instruction PC with no landing pads, exact flag encodings after
selected instructions, exact I/O port/data, memory write addresses and
counts, and the HLT/wake/return cycle.

## Formal cover

SymbiYosys cover mode reaches every cover point: retirement, memory write,
I/O write, HLT fetch, INR M and DCR M fetch, RTc and RFc fetch, JMP/CAL
fetch, injection from HLT, and RST under interrupt. See
[the formal plan](../plans/formal_plan.md) for the proven property set.

## Known gaps

- Console input is never exercised with non-zero data at the RTL level; the
  scripted-input SCELBAL run described above is future work.
- Register-file contents for register-targeted INR/DCR M writes are
  structurally impossible after the review fix (single write port, guarded
  address), proven formally rather than observed.
