# Busicom 141 manual regression — 2026-09-27

## Inputs and method

The [readable Markdown manual](../spec/reference/Unicom_141P_manual.md) and
[JSON examples](../spec/reference/Unicom_141P_examples.json) cover all **42 numbered
operation examples**, with **135 checkpoints**. All operation tables were checked
visually against the 35-page PDF. The original OCR is retained separately, unchanged
apart from line endings. The PDF and recovered 1280-byte ROM hashes are embedded
in the JSON and were checked against the local source files.

The RTL replay sends actual key/scancode and switch events through the panel
bridge to the historical firmware. It checks exact printed strings (including
trailing zeros), symbols, red ink, rounding marks and specified indicator lamps.
Expected rows are an ordered suffix of the new output at each checkpoint.
The checker does not replace the firmware with host arithmetic.

Each case clears entry, registers and memory with `CE C CM C`. The RTL runs retain
one simulator across cases; the independent reference uses a fresh board per case.
The `paper_sequence` counter preserves identical consecutive tape rows.

## Results

- **Verilator 5.052, spin=1481:** all 42 examples executed. 37 match the scan
  exactly; five produce the independently confirmed ROM differences below.
- **Recovered-ROM profile on Verilator:** the five changed cases were replayed
  with their explicit overrides and all five passed. Combined with the 37
  unchanged cases from the full run, all 42 match the documented ROM expectations.
- **Independent V. Ilmer CPU emulator:** all 42 pass the recovered-ROM profile.
  It reproduces exactly the same five differences from the manual. Its complete
  printed tape matches the Verilator tape for every example, including the
  intermediate lines outside the 135 explicitly asserted checkpoints.
- **xezim 0.11.0, JIT/AOT, spin=740:** all 42 executed across three isolated
  partitions (28 arithmetic, three square-root, eleven capacity examples). The
  exact same 37 strict passes and five source differences occur. Complete tapes
  and checkpoint results equal Verilator for all 42. A separate native xezim
  replay of 2-1 passes at the restored default spin=1481.
- **Browser:** loaded all 42 cases and replayed 11-1 successfully using the ROM
  profile. Physical browser keys `C 5 + 6 + =` printed `11 *` and returned to idle.
- **Headless launcher:** examples 1-1 and 11-1 passed in an isolated Verilator
  process; the launcher exited successfully and stopped its child process.
- **Checker tests:** 12 pass, including deliberate precision, symbol, color and
  lamp mismatches, profile separation, duplicate rows, and incomplete traces.
- **CPU verification:** xezim 0.11.0 passes 166,754 cycles and 20,192 instruction
  boundaries; all 46 instruction classes are observed. Verilator/Verible lint,
  SBY BMC/prove/cover (including non-vacuity), and Yosys synthesis pass.
- **Board bring-up:** xezim passes 600,001 cycles with all ten keyboard rows seen.
- **Bridge:** C syntax/warnings pass with `-Wall -Wextra -Werror`; shell syntax
  and JavaScript syntax checks pass. The Docker image build and final executable
  smoke checks also pass.

The interactive app at <http://localhost:8081/> uses the new image with the
Verilator backend. The previous image and web container are retained for rollback.
Tool versions and upstream release pins are in
[the toolchain manifest](../../../docs/toolchain-releases.md).

## Five source differences

The JSON's default `expect` always preserves the scan. Only the five affected
checkpoints have `expect_profiles.recovered-rom`; selecting that profile is
explicit in both Python and the browser. Unexpected differences still fail.

| Example | Printed manual | Recovered ROM and independent emulator |
|---|---|---|
| 3-1 | `6.6666666666666 *` | `6.666666666666 *` (one fewer fractional digit) |
| 5-1 | `329.36 *`, no rounding mark | `329.36 ^*`, rounding-up mark present |
| 11-1 | `12345.73 *` | `12345.750000000 SQRT` |
| 11-2 | `1.414214 *` | `1.414214 SQRT` |
| 11-3 | `14.422205 *` | `14.422205 SQRT` |

For 11-1, `12345.75² = 152417543.0625` exactly, so the scan's `12345.73` is an
arithmetic typo. The other differences are observed scan/ROM variations; the
evidence does not establish which historical firmware/manual revision caused
them. The recovered ROM has not been edited to match the scan.

### Independent evidence

The project-owned [reference adapter](../scripts/reference_oracle.rs) calls the
external [V. Ilmer chips implementation at 1bc3d578](https://github.com/veniamin-ilmer/chips/tree/1bc3d5781474ef9d7e7305af91071a723797f222).
Its board wiring and drum tables are grounded in
[Busicom emulator dea0745b](https://github.com/veniamin-ilmer/busicom/tree/dea0745b10032ebf632f0431b26728717920e17f).
The CPU checkout is pinned and checked for semantic modifications, mounted
read-only, and kept outside this repository. No external CPU source is copied
into the project. Reference runs use 1481 cycles per half-spin, 2000 boot ticks,
and 400 ticks per key (64 pressed, 336 released).

TCS and DAA repairs are independently grounded in
[MAME's MCS-40 implementation](https://github.com/mamedev/mame/blob/8089ec90d3543a04311fab69733af1ac033fcd39/src/devices/cpu/mcs40/mcs40.cpp).
The board repairs follow the recovered Kintli disassembly. See the
[escaped-defect post-mortem](../../../failure_notes/2026-09-27-busicom-manual-regression.md).

## Reproduce

From the system directory inside the rebuilt image:

```sh
BUSICOM_BACKEND=verilator sh scripts/run_manual_test.sh --profile recovered-rom
XEZIM_JIT=1 XEZIM_AOT=1 sh scripts/run_manual_test.sh --profile recovered-rom
python3 scripts/test_replay_manual.py
python3 scripts/check_reference.py --chips /reference/chips --profile recovered-rom
```

Omit `--profile recovered-rom` for strict comparison with the scan; five failures
are expected for this ROM. See [replay instructions](../spec/reference/README.md)
for running against an existing server, choosing cases and using the web GUI.
Detailed development logs and full tape traces remain under ignored `work/`.

## Coverage limits

- Sections 12 and 13 describe buffer/entry capacity without numbered sequences.
  They are transcribed but do not count as executed examples. Buffer timing,
  physical paper/ribbon changes and electrical printer timing are not verified.
- The transcription normalizes graphical key labels and layout. Photographs
  remain in the PDF; raw OCR is preserved for comparison.
- Only one replay client may drive a given panel at a time. The simulator runs
  continuously while idle and uses a CPU core. Boot and key latency depend on
  simulator throughput.
- Square-root cases require the feature in this recovered five-ROM image.
- Browser replay and tape output were verified. The in-app browser did not
  expose a download-completion event for the report; use the headless `--report`
  option when a verified saved report is required.

<!-- CASE MATRIX -->
## Case matrix

Full observed tapes and differences are saved in [manual_results.json](manual_results.json).

| Example | Manual page | Verilator / xezim vs. scan | Recovered ROM / independent CPU |
|---|---:|---|---|
| 1-1 | 10 | PASS | PASS |
| 1-2 | 11 | PASS | PASS |
| 1-3 | 11 | PASS | PASS |
| 1-4 | 12 | PASS | PASS |
| 2-1 | 13 | PASS | PASS |
| 2-2 | 13 | PASS | PASS |
| 2-3 | 13 | PASS | PASS |
| 2-4 | 13 | PASS | PASS |
| 2-5 | 14 | PASS | PASS |
| 2-6 | 14 | PASS | PASS |
| 2-7 | 15 | PASS | PASS |
| 2-8 | 15 | PASS | PASS |
| 3-1 | 16 | Documented difference | PASS |
| 3-2 | 16 | PASS | PASS |
| 3-3 | 16 | PASS | PASS |
| 3-4 | 16 | PASS | PASS |
| 3-5 | 17 | PASS | PASS |
| 3-6 | 17 | PASS | PASS |
| 4-1 | 18 | PASS | PASS |
| 4-2 | 18 | PASS | PASS |
| 5-1 | 19 | Documented difference | PASS |
| 6-1 | 20 | PASS | PASS |
| 6-2 | 21 | PASS | PASS |
| 7-1 | 22 | PASS | PASS |
| 7-2 | 22 | PASS | PASS |
| 8-1 | 23 | PASS | PASS |
| 9-1 | 24 | PASS | PASS |
| 10-1 | 25 | PASS | PASS |
| 11-1 | 26 | Documented difference | PASS |
| 11-2 | 26 | Documented difference | PASS |
| 11-3 | 28 | Documented difference | PASS |
| 14-1 | 30 | PASS | PASS |
| 14-2 | 30 | PASS | PASS |
| 14-3 | 30 | PASS | PASS |
| 15-1 | 31 | PASS | PASS |
| 15-2 | 31 | PASS | PASS |
| 15-3 | 31 | PASS | PASS |
| 15-4 | 31 | PASS | PASS |
| 16-1 | 32 | PASS | PASS |
| 16-2 | 32 | PASS | PASS |
| 16-3 | 32 | PASS | PASS |
| 16-4 | 32 | PASS | PASS |
