# Independent physical-286 regression adapter

Status: the importer and functional replay pass for a bounded real-mode subset.
The result adds physical-capture evidence to the full-chip completion ledger;
it does not establish protected-mode, native-cycle, or full-chip completion.

## Source and scope

Use [SingleStepTests/80286 revision 37c73caf53dcd22d3dd369ff09305d13d117a4fe](https://github.com/SingleStepTests/80286/tree/37c73caf53dcd22d3dd369ff09305d13d117a4fe),
suite version 1.1.0. Its [README](https://github.com/SingleStepTests/80286/blob/37c73caf53dcd22d3dd369ff09305d13d117a4fe/README.md)
identifies a Harris N80C286-12 L4252050, copyright 1986, captured through
ArduinoX86. The exact stepping is uncertain; do not infer it from the date.
The generator uses physical execution independently of an emulator and accepts
repeat captures after its consistency checks. It can still have recording
defects, so preserve every test hash and apply the pinned revocation list.

This revision publishes real-mode data, with unreal/protected suites described
as future work. It does not exercise IF/TF, wait states or queue-dependent
instruction sequences, and deliberately omits very small-SP shutdown cases.
It cannot close those native/protected evidence gates. The cycle records will
also be useful for the later native bus; a functional byte-bus replay alone
does not establish native cycle timing or LOCK correctness.

## Completed functional subset

The adapter selects the pinned `v1_real_mode` accumulator immediate files
`04/05` (ADD), `14/15` (ADC), `1C/1D` (SBB), `2C/2D` (SUB) and `3C/3D`
(CMP), with 5,000 captures per opcode, plus all register INC/DEC files
`40` through `4F`, with 1,000 captures per opcode. The source revocation list
has three hashes; none matches these selected records. These 66,000 captures
plus 2,510 F6/F7 `/1` TEST-alias register captures pass both stalled and
unstalled functional replay: 68,510 captures and 137,020 runs total.
The TEST-alias files contain 10,000 records; 7,490 memory/fault cases are
explicitly listed as outside the register adapter, separately from revocations.
No RTL pass is claimed for those excluded cases. Selected alias counts are
F6: 1,254 and F7: 1,256, including 86 F0-prefixed register cases.

For these register-only, non-control-flow forms, the captured byte list
contains the tested instruction and its following `F4` HLT. The importer
checks that encoding against the initial RAM map and that final CS:IP accounts
for the exact captured bytes, including HLT. It merges final register and RAM
deltas with the initial state. Replay checks every architectural register,
compares FLAGS with mask `0x7fd7` (`0x7fc7` for TEST aliases, excluding undefined
AF), and checks the complete recorded RAM map.
The importer rejects initial FLAGS with IF, TF, IOPL or NT set because the
current real-mode bootstrap cannot initialize those states. All selected
captures have those bits clear. Replay also rejects IOPL/NT bits (`0x7000`) in
any state that reaches it. This limits the FLAGS evidence to states supported
by the current bootstrap.
The suite does not use Unicorn to generate expected state. Imported cycle
chunks are checked for framing but are not replayed or compared, so this is not
a timing or native-bus result.

The parser and importer fixtures pass together in the repository Docker image
(33 tests). The canonical `run_hardware.sh` phase is called from `run_all.sh`;
its 28 opcode baselines and 74 oracle-corruption checks pass, as do two controls
that change only undefined AF in the TEST-alias expected results. Checks cover
AX, preserved CX, DS, CF, OF, final IP, final RAM and the HLT successor, plus
each added arithmetic accumulator/CF/OF result and each INC/DEC register and
preserved CF, plus changed carry inputs for both byte/word ADC and SBB.
The completed scope is limited to these 28 register-only forms;
it does not cover other real-mode instruction forms or exceptions.

## Immutable preparation

### Register INC/DEC expansion contract

The selected physical files cover every one-byte register INC/DEC form
`40h` through `4Fh`, including SP. These forms have no operand-memory or I/O
transactions, preserve CF and define the other arithmetic flags; the complete
FLAGS comparison mask remains `0x7fd7`. No expected register or flag value may
be calculated locally: use the captured final delta merged with initial state.
Keep the exact instruction and HLT successor checks for every selected record.
Reject unexpected memory changes, exceptions, queues or unsupported initial
FLAGS rather than dropping such captures. Record actual imported case counts
and revocations before reporting an expansion as passing.

### Accumulator arithmetic expansion contract

The adapter includes the pinned byte/word accumulator immediate forms ADC (`14h/15h`), SBB
(`1Ch/1Dh`), SUB (`2Ch/2Dh`) and CMP (`3Ch/3Dh`). Intel Appendix B entries
ADC/ADD (B-19), SBB (B-99), SUB (B-109) and CMP (B-33) define the arithmetic
flags; use the existing `0x7fd7` mask, without locally computing results.
CMP must retain the externally captured unchanged accumulator. Carry-in for
ADC/SBB comes from the captured initial FLAGS through the instruction bootstrap.
Keep every register, exact PC/HLT, RAM and bus-effect assertion used above.
The shared bus monitor rejects fetches with asserted write or I/O controls
before servicing them. A separately compiled RTL copy that asserts write on
fetch is rejected by this invariant; production RTL remains unchanged.
The manifest records both initial CF states per opcode file, after revocation
filtering. Import fails if either bucket is empty. All 28 selected files meet
this requirement; carry-input coverage is captured evidence rather than an
assumption about the generator.

The importer downloads only revision-pinned source paths and checks each raw
file against its published Git blob identity and a retained SHA-256 manifest.
Downloaded MOO/gzip files, converted records and source artifacts remain under
ignored `work/hardware/`. The local parser follows the pinned SingleStepTests
converter; it bounds-checks nested MOO chunks, count fields and record framing,
preserves each test hash, and rejects malformed or truncated records. It
skips unknown chunks by their declared lengths. It does not decode the cycle
records.

The source uses MOO binary chunks and supplies tools/moo2json.py. Read that
format implementation before writing an adapter. The JSON final register and
memory maps are deltas: merge them with initial values before comparison.
Honor revocation_list.txt by test hash and report all exclusions explicitly.
Publish selected opcode files, imported cases, excluded cases and reasons;
never discard a mismatch or silently shrink coverage to obtain a pass.

## Setup, exact PCs and comparison

Initialize GPRs, FLAGS and real visible selectors/caches through a defined
bootstrap or a separately specified verification-only state-load interface.
Keep setup effects outside the instruction's observed transactions, and restore
the recorded initial RAM before execution. All initial memory bytes and all
observed memory changes must remain authoritative external inputs/results.
The adapter must not synthesize expected results with Unicorn.

For the selected non-control-flow forms, the replay executes the captured
instruction and its recorded HLT and asserts the exact resulting CS:IP. No
padding or guessed instruction length is used. Control transfers and
exceptions remain outside this subset. Any future support for source cases
that dynamically inject HLT at a target must preserve the source's fetch-only
override rule: inject only after the tested instruction retires, at the exact
asserted target, without changing data RAM or overriding another fetch.

Replay compares the complete architectural register map and all recorded RAM
bytes (including initial bytes unchanged by the instruction), while masking
FLAGS with `0x7fd7` or the TEST-alias `0x7fc7` mask. Undefined AF in TEST is
explicitly excluded. The selected source forms do not exercise
exceptions, I/O, or input instructions. Source hashes, encodings and PCs are
retained in the vectors and diagnostics. Exception records and non-empty
prefetch queues are rejected by the current adapter; exception delivery and
input behavior remain unfinished coverage rather than accepted results.

The current functional replay checks the same 68,510 architectural cases with
both unstalled and stalled buses. These operations have no data-memory or I/O
effects; exact instruction bytes, register results, successor PC and recorded
RAM are checked. Native address/data/BHE/LOCK/T-state comparisons remain a
separate required phase. The source's zero-wait timing is not a timing oracle
for the added stalls.

## Completion gates

The selected corpus is included in the canonical hardware phase. Its 68,510
records currently establish evidence only for ADD/ADC/SBB/SUB/CMP accumulator
immediate forms, all register INC/DEC forms and register TEST `/1` aliases;
expand the source files as architectural coverage grows. The 33 parser/importer
fixtures, 28 replay baselines, 74 oracle-corruption checks and two AF-mask
controls pass. Historical
software remains a separate requirement. Any semantic discrepancy against this
external source requires an escaped-defect post-mortem, a focused permanent
regression and an external citation when RTL/model semantics change together.
