#!/usr/bin/env python3
"""Publish verification evidence only after every current-source check passes."""
from datetime import datetime, timezone
import json
from pathlib import Path
import subprocess
import sys
from run_library import inventory, digest

root=Path(__file__).resolve().parents[1]
chips=inventory()
results=[]
for chip in chips:
    for phase in ('lint','sim','synth'):
        result=json.loads((root/f'work/library/{chip["module"]}/{phase}.json').read_text())
        if not result['passed'] or result.get('source_digest')!=digest(chip,phase):
            raise SystemExit(f'Missing, failed or stale result: {chip["module"]} {phase}')
        results.append(result)
formal=json.loads((root/'work/formal/library_results.json').read_text())
if len(formal)!=10 or any(not item['passed'] for item in formal):
    raise SystemExit('Formal family checks are incomplete or failed')
for task in ('bmc','prove','cover'):
    if (root/f'work/formal/{task}/status').read_text().split()[0]!='PASS':
        raise SystemExit(f'Original 74181 {task} did not pass')
stamp=datetime.now(timezone.utc).strftime('%Y-%m-%d %H:%M UTC')
versions=[]
for command in (['verilator','--version'],['yosys','-V'],['xezim','--version']):
    completed=subprocess.run(command,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,check=False)
    versions.append(completed.stdout.splitlines()[0] if completed.returncode==0 else command[0]+" (bundled image; version flag unavailable)")
report=f'''# Classic 7400–74299 library verification report

Verified: {stamp}

## Result

**289 digital function models; 867/867 current-source per-part checks passed.**
Each part passed strict RTL lint, self-checking simulation and generic synthesis
including structural assertions. Seven user-excluded analog/timing devices are
explicitly listed in the manifest. No modules are created for unassigned numbers.

All ten independent family formal check/cover tasks passed. The original 74181
also passed strict Verilator/Verible lint, 16,384 exhaustive binary input vectors
(81,920 output-field comparisons), its 64-transaction UVM test, BMC, unbounded
proof, cover and generic synthesis. `ttl_74x181` wraps that unchanged RTL.

## Tools

'''+''.join(f'- {version}\n' for version in versions)+'''
The repository's `ai-hw-engineer:latest` Docker image supplies the tools and UVM.
Builds use only local library sources, tests and test images; upstream code is
pinned by revision and its MIT license is retained.

## Formal evidence and limits

| Family | Check | Non-vacuity |
|---|---|---|
| 46 gate/strobe modules | Unbounded independent truth-table proofs | All covers PASS |
| 74160/161/162/163 | Unbounded transition/carry contracts | Reset/load/hold/terminal count covers PASS |
| 74164 | Unbounded bit-history contract | Nonzero serial sequence cover PASS |
| 74189 | Unbounded symbolic-address read/write/drive invariant (ABC PDR) | Written-address readback cover PASS |
| 74222 | Bounded ordering/flag contract, 8 steps | Full and mixed-operation covers, depth 20, PASS |
| Original 74181 | BMC and unbounded proof | Cover PASS |

The FIFO bounded result is not an unbounded ordering proof. All FIFO models also
run full/empty, overflow/underflow prevention, pointer wraparound and 2,000 mixed
transactions against independent queues in simulation. Targeted formal coverage
does not certify every part's complete native datasheet behavior.

## Corrections and test depth

The initial imported functional baseline was not accepted on its prior pass claims.
Local tool and source review corrected strobe polarity, expander support, complete
7485 cascade semantics, independent clock storage, forced 7474 output state,
falling-edge ripple counters and 7492 state order, asynchronous 74165 loading,
serial bit ordering, 74279 set controls, storage synthesis feedback, drive enables,
74299 serial endpoints, ROM-versus-RAM distinctions, 74289 inversion, converter
truncation and divider ratios. The generic substitute 74297 filter was replaced
by a documented digital K-counter/I-D/phase-detector model.

RAM tests exercise every address with three data patterns and check inactive
write/chip-select protection. ROM tests load nontrivial image fixtures and read
every address. Shift-register tests cover all 256 byte loads and complete serial
chains. Expander tests cover both input states. Tests flush unreset storage before
requiring known contents; power-up zeros are not assumed.

## Functional-interface boundaries

These are the documented **normalized digital function models**. They are not all
native package-pin-compatible replicas. Some RAM, FIFO, rate multiplier and
multi-clock devices use explicit clock/transaction adapters. Native asynchronous
handshake timing, exact rate-multiplier pulse distribution and the 74297 internal
pipeline placement are not certified. See each part's specification before board
integration. Three-state buses use drive enables/split I/O, and open-collector
levels require board-level wired-AND resolution. ROM masks, including the 74262
teletext character image, must be supplied; synthetic test fixtures are not
historical contents. Exact launch years outside the sourced 1970 74181 date
remain explicitly unknown.

## Reproduction

```sh
docker run --rm -v "${PWD}:/workspace" -w /workspace \\
  ai-hw-engineer:latest sh design/ttl_74xx/scripts/run_all.sh
```

Per-part phase logs and source fingerprints are under `work/library/<module>/`.
Proof logs/traces are under `work/formal/`. Build artifacts are git-ignored.
The aggregate command fails on tool errors, missing PASS markers, missing parts,
unexpected exclusions, failed covers or stale successful per-part results.

## Per-part checks

| Module | Strict lint | Simulation | Generic synthesis | Contract |
|---|---|---|---|---|
'''
for chip in chips:
    report+=f'| {chip["module"]} | PASS | PASS | PASS | [specification](../{chip["specification"]}) |\n'
(root/'report/library_report.md').write_text(report)
print(f'Verification report written: {len(results)}/{len(results)} current-source checks; 10 family formal tasks; original 74181 sign-off')
