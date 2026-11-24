# IBM System/360 family

Reconstruction of the IBM System/360 as verifiable hardware. This folder holds
the **shared** S/360 engine and the family-level specification; each physical
model gets its own member folder (`model30/`, `model65/`, …) when its issue
reaches implementation.

- Program roadmap: [hevangel/ai_engineer#379](https://github.com/hevangel/ai_engineer/issues/379)
- Shared CPU engine (issue): [hevangel/ai_engineer#384](https://github.com/hevangel/ai_engineer/issues/384)
- Source and provenance ledger: [spec/sources.md](spec/sources.md)
- Architecture specification and current milestone report:
  [spec/spec.md](spec/spec.md),
  [report/2026-11-23-m6-addressing-external.md](report/2026-11-23-m6-addressing-external.md)

## History

IBM announced the System/360 on **7 April 1964** and delivered machines from
1965 until the family was withdrawn from marketing at the end of 1977. It was
the first IBM family designed so that one architecture — one instruction set,
one set of peripherals, one operating-system interface — covered both
commercial and scientific work across a range of performance and price. The
initial announcement named Models 30, 40, 50, 60, 62 and 70; 60/62/70 were
never shipped and were replaced by the 65 and 75. Later models included the
20 (1966), 22 (1971), 25 (1968), 44 (1966), 67 (1966, the first production
machine with dynamic address translation), 85 (1969), 91 (1967), 95 (1968) and
195 (1971). Model dates here are from the cited secondary source; per-model
dates, features and bill of materials are re-sourced in each model issue.

The architectural separation of *definition* from *implementation* is the
reason this family is interesting for reconstruction: the same program runs on
a Model 20 with a reduced instruction set and 16-bit registers, on a
microcoded Model 30, and on a hardwired Model 91 with out-of-order execution.
A faithful family reconstruction must therefore model the shared architecture
and the per-model deviations separately — never claim that architectural
compatibility implies cycle fidelity.

## Why it is important

- It established the idea of a **computer family** with binary compatibility
  and a published *Principles of Operation* that separated architecture from
  implementation.
- It introduced the 8-bit byte, 24-bit byte addressing, and the
  general-register machine model that later IBM mainframes still run.
- Its channel subsystem, program status word, interruption classes and
  condition code are the direct ancestors of System/370, ESA/390 and z/Architecture.
- Its software record (OS/360, DOS/360, CP/67, TSS/360, FORTRAN, COBOL, PL/I,
  APL\360) is the basis of the program's Rust software reconstruction.

## Status in this repository

| Area | State |
|---|---|
| Architecture specification | written and sourced — [spec/spec.md](spec/spec.md) |
| Source/provenance ledger | started — [spec/sources.md](spec/sources.md) |
| Shared CPU engine, M1 | implemented: 23 instructions, PSW, address generation, self-checking simulation, formal properties |
| Status switching and program interruptions (M2) | implemented: `SPM`, `SSM`, `LPSW`, program interruptions 1/2/6/8, problem state, wait state |
| Fixed-point completion and SVC (M3) | implemented: halfword group, `MR`/`M`, `DR`/`D`, shifts, `SVC` with supervisor-call interruption, specification and divide exceptions |
| Character and SS-format group (M4) | implemented: `MVC`, `MVN`, `MVZ`, `NC`, `OC`, `XC`, `CLC`, `TM`, `IC`, `STC` with a byte-loop SS engine |
| Translate and execute (M5) | implemented: `TR`, `TRT`, `EXECUTE` with the execute exception and EX's own address/ILC rule |
| Addressing and external interruptions (M6) | implemented: code 5 for operands outside installed storage, timer interruption with PSWs at `0x18`/`0x58` (code `0x0080`), wait-state exit |
| Storage, channel I/O, protection/DAT, SVC/external/I/O interruptions | not started |
| Model members (20, 22, 25, 30, 40, 44, 50, 65, 67, 75, 85, 91, 95, 195) | not started; each will be a member folder |
| Independent emulator oracle, IBM diagnostics, real OS boot | not started (issues #383, #441, #429 and later) |

The core is a **functional** increment, not a qualified S/360 CPU. It runs
hand-assembled programs that exercise every instruction and interruption it
implements, and it has formal proofs for the arithmetic unit, the address
adder, the PSW field contract, the retirement contract and the program-check
suppression rules. It does **not** yet run historical S/360 software, does not
implement protection or DAT, has only program interruptions, and has no timing
or microarchitecture claim. See
[report/2026-11-05-m1-core.md](report/2026-11-05-m1-core.md),
[report/2026-11-08-m2-status-switching.md](report/2026-11-08-m2-status-switching.md)
and
[report/2026-11-17-m3-fixedpoint.md](report/2026-11-17-m3-fixedpoint.md) and
[report/2026-11-18-m4-character-ss.md](report/2026-11-18-m4-character-ss.md)
and
[report/2026-11-20-m5-translate-execute.md](report/2026-11-20-m5-translate-execute.md)
and
[report/2026-11-23-m6-addressing-external.md](report/2026-11-23-m6-addressing-external.md)
for the measured evidence and the exact list of limitations.

## Folder layout

```
design/ibm_system360/
├── README.md                 — this file
├── spec/
│   ├── spec.md               — architecture, M1 subset, deviations, assumptions
│   └── sources.md            — source/provenance ledger and licensing policy
├── src/
│   ├── ibm_s360_defs.svh     — formats, PSW field positions, decode table
│   ├── ibm_s360_alu.sv       — 32-bit fixed-point/logical unit and CC rules
│   ├── ibm_s360_addr.sv      — 24-bit base/index/displacement addition
│   ├── ibm_s360_psw.sv       — PSW register with field writes and whole-word load
│   └── ibm_s360_cpu.sv       — fetch/decode/execute sequencer (M1 core)
├── tb/tb_ibm_s360_cpu.sv     — self-checking directed testbench
├── formal/                   — arithmetic, address, PSW and core properties
├── plans/                    — implementation plan, test plan, formal plan
├── scripts/                  — lint, simulation, formal, synthesis entry points
└── report/                   — dated evidence reports
```

## Running the checks

All tools run from the project Docker image, from the repository root:

```sh
docker run --rm -v "$PWD":/work -w /work ai-hw-engineer:latest \
    sh design/ibm_system360/scripts/run_all.sh
```

Individual entry points:

```sh
sh design/ibm_system360/scripts/run_lint.sh     # Verilator -Wall
sh design/ibm_system360/scripts/run_sim.sh      # self-checking simulation
sh design/ibm_system360/scripts/run_formal.sh   # SymbiYosys jobs
sh design/ibm_system360/scripts/run_synth.sh    # Yosys synthesis smoke test
```

The scripts expect `verilator`, `yosys` and `sby` on `PATH`, as provided by the
image; results and logs land in the ignored `design/ibm_system360/work/` tree.

### Differential check against an independent emulator

`tools/oracle/run_diff.py` runs the same program images on this RTL and on an
independent System/360 emulator and compares registers, PSW fields and storage.
It runs on the host (needs `python3` and `node`) and uses the project image for
the RTL side:

```sh
python design/ibm_system360/tools/oracle/run_diff.py
```

The emulator is **not** in this repository: it is fetched into the ignored
`work/` tree and located through `ORACLE_ROOT`; URL, commit and licence status
are in [spec/sources.md](spec/sources.md). Results:
[report/2026-11-22-oracle-differential.md](report/2026-11-22-oracle-differential.md).

## Sources

The architecture in this folder is derived from IBM System/360 Principles of
Operation, form A22-6821-7 (eighth edition, September 1968 reprint of
A22-6821-6 with Technical Newsletter changes), held by bitsavers. Every
statement in [spec/spec.md](spec/spec.md) carries a page reference to that
manual; the ledger, hashes, licensing notes and the list of not-yet-located
sources are in [spec/sources.md](spec/sources.md).

No IBM code, microcode or copyrighted program is redistributed by this folder:
the testbench contains a hand-assembled program written for this project, and
the only external artifact used during development is the public PDF of the
Principles of Operation, which is read from the network and never committed.
