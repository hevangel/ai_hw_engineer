# Reference material

Downloaded third-party sources used as *facts-only* references for the
141-PF reconstruction. The upstream checkouts are intentionally **not
stored in this repository** (unlicensed third-party code, and the security
scanner correctly refuses third-party minified JS in the tree); they are
kept in a sibling scratch folder (`B:/ai_hw_engineer_ref/`) and can be
re-fetched with:

```
git clone --depth 1 https://github.com/veniamin-ilmer/busicom.git
git clone --depth 1 https://github.com/veniamin-ilmer/boards.git
git clone --depth 1 https://github.com/veniamin-ilmer/chips.git
```

* `rom_141pf_combined.bin` — the authentic 1280-byte Busicom 141-PF
  firmware (5 × 256-byte 4001 masks), extracted from the emulator's
  published ROM array. Split per chip into `../../src/rom/` by
  `../../scripts/extract_rom.py`.

## User manual extraction and replay

- [PDF scan](Unicom_141P_manual_text.pdf): original source, 35 PDF pages.
- [Readable Markdown](Unicom_141P_manual.md): normalized text and visually checked
  operation tables, with printed/PDF page references.
- [Raw OCR Markdown](Unicom_141P_manual_ocr.md): original extraction retained for
  audit; graphical keys and some numbers are garbled.
- [Replay JSON](Unicom_141P_examples.json): all 42 numbered examples, explicit
  physical key names/codes, switch changes, decimal strings, ink color, symbols,
  rounding marks and overflow expectations. The source PDF SHA-256 is embedded.

Without a browser, start the simulator with `scripts/run_system.sh`, then run:

```sh
python3 scripts/replay_manual.py --url http://127.0.0.1:8080 --report work/manual-results.json
python3 scripts/replay_manual.py --url http://127.0.0.1:8080 --only 1-1,9-1
```

Or start and stop an isolated simulator automatically:

```sh
sh scripts/run_manual_test.sh
BUSICOM_BACKEND=verilator sh scripts/run_manual_test.sh
```

In the web panel, use **Replay manual examples**, click **Load included examples**
or load the JSON file, select an
example or all examples, and click **Run**. **Save results** downloads a report.
Both runners submit the same physical key/switch events to the DPI HTTP bridge;
the Python runner does not require a browser. Use one runner at a time per panel.
Neither runner computes answers in place of the historical firmware.

The default **manual** profile preserves the scanned answers. Five examples
disagree with this recovered ROM on precision, print marks, or a square-root
answer. Each difference was reproduced with an independent emulator. For the
documented ROM expectations, use `--profile recovered-rom` in Python or select
**Recovered ROM** in the panel. `expect_profiles.recovered-rom` overrides only
those checkpoints; `expect` always retains the scan. See the
[results and differences](../../report/manual_regression.md). CPU `run_all.sh`
uses the recovered-ROM profile so it catches new defects without treating the
documented source differences as new failures.

The JSON format is versioned (`schema_version: 1`). Each example contains
`switches`, `setup_keys` and ordered `steps`. A step changes `switches` or sends
`keys`; after each key, wait for `ready && !busy`. `expect.tape` is an exact
ordered suffix of the new lines printed by that step. Every row includes
`value`, `symbol`, `red` and `rounded`. `value: null, symbol: overflow` means a
dotted overflow line. `expect.lamps` tests named indicators. Setup is separate
from manual operations, clearing prior entry/accumulators/memory. Numbers stay
strings; do not convert them to floating point or discard trailing zeros.

`paper_sequence` in `state.json` gives the current bottom row's ID; visible row
`i` has ID `paper_sequence - 6 + i`. Replay collectors retain these IDs across
polls, so repeated identical printed lines are preserved rather than deduplicated.

Validate the dataset without a simulator using `python3 scripts/replay_manual.py
--validate`. Regenerate the Markdown example tables after editing the JSON using
`python3 scripts/manual_markdown.py`. Sections 12-13 describe capacity but contain
no worked sequence; physical paper/ribbon procedures cannot be executed in RTL.

## Independent CPU cross-check

`scripts/check_reference.py` runs the same JSON on the separately cloned
V. Ilmer `chips` crate, pinned to
`1bc3d5781474ef9d7e7305af91071a723797f222`. It rejects semantic worktree edits.
The small project-owned Rust adapter contains host wiring and printer decoding;
the external CPU implementation is neither copied here nor derived from our RTL.
Each example starts from a fresh reference board and waits 400 half-spin ticks
per key (64 pressed, remainder released), at 1481 cycles per tick.

With Rust available and the pinned checkout mounted read-only at `/reference/chips`:

```sh
python3 scripts/check_reference.py --chips /reference/chips --profile recovered-rom
```

The trace, compiler log and results go to `work/reference-oracle/`. Crate
dependencies are fetched by Cargo on the first run. The normal RTL regression
does not depend on this external checkout. Checker unit tests can be run with
`python3 scripts/test_replay_manual.py`.

## Source bibliography

* V. Ilmer, *Busicom 141-PF emulator* (board wiring, keyboard matrix,
  printer protocol) — <https://veniamin-ilmer.github.io/emu/busicom/>,
  repos above. No code reused; behaviour tables only.
* Busicom 141-PF Replication Project (firmware reverse-engineering by
  B. & B. Silverman, E. Dvorak, L. Kintli) — <https://www.4004.com>,
  project materials CC BY-NC-SA 2.5.
* IPSJ Computer Museum, *Busicom 141-PF* — history and introduction date.
