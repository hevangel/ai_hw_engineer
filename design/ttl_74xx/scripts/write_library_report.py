#!/usr/bin/env python3
"""Publish tool evidence and coverage without hiding pending digital devices."""
from datetime import datetime,timezone
from pathlib import Path
import json,sys
from run_library import inventory,digest
from run_library_formal import families,source_digest
root=Path(__file__).resolve().parents[1]
chips=inventory()
entries=json.loads((root/'manifest.json').read_text(encoding='utf-8'))
pending=[c for c in entries if c['status']=='pending']
excluded=[c for c in entries if c['status']=='excluded']
checks=[];failures=[]
for c in chips:
    for phase in ('lint','sim','synth'):
        path=root/f'work/library/{c["module"]}/{phase}.json'
        r=json.loads(path.read_text(encoding='utf-8')) if path.exists() else {}
        ok=r.get('passed',False) and r.get('source_digest')==digest(c,phase)
        checks.append((c,phase,ok))
        if not ok:failures.append(f'{c["module"]} {phase}')
formal_path=root/'work/formal/library_results.json'
formal=json.loads(formal_path.read_text(encoding='utf-8')) if formal_path.exists() else []
expected_formal={(family,task) for family in families for task in ('check','cover')}
formal_ok={(c['family'],c['task']) for c in formal}==expected_formal and all(c['passed'] and c.get('source_digest')==source_digest(c['family']) for c in formal)
stamp=datetime.now(timezone.utc).strftime('%Y-%m-%d %H:%M UTC')
report=f"""# Numbered 74-series coverage and verification

Updated {stamp}.

**Requested scope is incomplete.** {len(entries)} catalog entries:
{len(chips)} normalized digital function models, **{len(pending)} pending digital
parts**, and {len(excluded)} analog/electrical exclusions. Numbers above 74299
have no artificial upper limit; wide-bus functions are included. Distinct family
functions retain their letters. Unknown historical introduction years are not guessed.

Implemented-subset tool results: **{sum(ok for _,_,ok in checks)}/{len(checks)}**
current-source checks passed. Family formal check/cover tasks: {sum(c['passed'] for c in formal)}/{len(expected_formal)}.
Tool success is not full manufacturer-table or native pin compatibility certification.
See the [original range evidence](classic_range_report.md) for the preserved
74181 verification and corrections made to the first 289 models.

## Verification contract and limits

- Verilator --lint-only -Wall, no blanket warning suppression.
- xezim self-checking simulation with required per-part PASS marker and timeout.
- Yosys synthesis and check -assert. Models labelled memory_inference stop
  after coarse memory inference; other models use complete generic gate synthesis.
- Source/test/runner fingerprints prevent stale successes. ROM fixtures are
  synthetic test patterns, not recovered historical masks.
- Eight formal families include unbounded 74574 register/drive and universal
  driver register/transparent-mode contracts, passive-switch topology/contention
  proofs and reachable non-vacuity covers. Formal verification is targeted, not exhaustive across the catalog.
- New imported models have normalized functional interfaces. Full native
  timing/control conformance remains unreviewed except where explicitly stated.
  Missing boundary-scan functions, generic placeholders and absent models are
  pending, with no misleading RTL stubs.
- The 74681 ALU/register tables are source-reviewed, while its P/G equations and
  logic-mode carry remain normalized assumptions. Native carry-chain behavior is
  not certified; see the per-part specification.
- New ROM/PROM models are read-only image-backed arrays. Selected RAM/FIFO
  models normalize clocks and controls; external board adapters must respect
  the local contract. Dual-clock FIFO simulations do not prove CDC safety.

## Pending digital functions

These are required by the user's scope. They are **not analog exclusions**.
The full run_all.sh completion gate returns nonzero while this table is nonempty.

| Part | Function | Reason / next work |
|---|---|---|
"""
limits=[c for c in chips if c.get('conformance_limits')]
if limits:
    heading='## Pending digital functions'
    details='## Part-specific conformance limits\n\n'
    for c in limits:
        details+=f'- [{c["part_number"]}](../{c["specification"]}): {c["conformance_limits"]}\n'
    report=report.replace(heading, details+'\n'+heading, 1)
for c in pending:
    reason=c['reason'].replace('\n',' ').replace('|','/')
    desc=c['description'].replace('\n',' ').replace('|','/')
    report+=f'| [{c["part_number"]}](../{c["specification"]}) | {desc} | {reason} |\n'
report+='\n## Analog exclusions\n\n'
for c in excluded:report+=f'- {c["part_number"]}: {c["description"].replace(chr(10)," ")}.\n'
report+='\n## Implemented-subset results\n\n| Module | Lint | Sim | Synthesis | Synthesis level |\n|---|---|---|---|---|\n'
for c in chips:
    phases=[('PASS' if ok else 'MISSING / FAIL / STALE') for x,p,ok in checks if x['module']==c['module']]
    report+=f'| [{c["module"]}](../{c["specification"]}) | '+ ' | '.join(phases)+f' | {c.get("synthesis_level","generic gates")} |\n'
for name in ('extended_report.md','library_report.md'):(root/'report'/name).write_text(report, encoding='utf-8', newline='\n')
print(f'Report: {sum(ok for _,_,ok in checks)}/{len(checks)} checks; {len(pending)} pending digital parts')
if failures:print('Unverified checks: '+', '.join(failures))
sys.exit(int(bool(failures) or not formal_ok))
