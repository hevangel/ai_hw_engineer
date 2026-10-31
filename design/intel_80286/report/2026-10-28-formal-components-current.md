# Current-source component formal refresh

**Run:** 2026-10-28 14:41–14:44 UTC  
**Scope:** all 12 standalone component formal configurations  
**Issue:** [hevangel/ai_hw_engineer#80](https://github.com/hevangel/ai_hw_engineer/issues/80)

## Result

All 36 component tasks passed: BMC, induction proof and cover for each of the
12 configurations below. The cover tasks reached 59 witnesses in total.
`preflight.py` passed before the runs. A current-source formal audit compared
each saved SBY task configuration and copied source file to the repository
inputs; all 36 tasks passed that audit as well.

| Component | BMC | Prove | Cover witnesses |
| --- | --- | --- | ---: |
| Access check | Pass | Pass | 5 |
| Bus owner | Pass | Pass | 3 |
| Cached reference | Pass | Pass | 6 |
| Code check | Pass | Pass | 5 |
| Code load | Pass | Pass | 5 |
| Datapath | Pass | Pass | 8 |
| Decimal | Pass | Pass | 4 |
| Effective address | Pass | Pass | 3 |
| Event control | Pass | Pass | 5 |
| Multiply/divide | Pass | Pass | 4 |
| Segment check | Pass | Pass | 6 |
| Segment load | Pass | Pass | 5 |
| **Total** | **12 pass** | **12 pass** | **59** |

## Reproduction and evidence

The runs used `scripts/run_formal.sh` with the 12 component `.sby` files and
separate evidence under `work/formal_selector_refresh_20261028/run/`. The
`component_audit.json` was produced by `scripts/audit_formal.py` against a
temporary view containing those 12 configs and their declared sources. That
scope intentionally excludes the connected-core `intel_80286.sby` and PDR
jobs; it cannot be read as whole-CPU proof.

Tool versions: SBY 0.69, Yosys 0.69, Z3 5.1.0 and Yices 2.7.0.

Current-source audit manifest SHA-256:
`b3e4317241c96bab81895fe4cc60834268ca941ac6622ae97878be4208687ffe`  
Second-batch SBY log SHA-256:
`bcc5942702efaba19c30342eaeb11567430b5349d2eebc793d335187467b2f0c`

## Limits and next step

These are component-level properties. The connected-core BMC, proof, cover,
PDR and release audit still need one consistent, current source/property
snapshot. The older whole-core PDR remains active on its earlier 21-file
snapshot; at 14:46 UTC it was at frame 89 with 321/411 assertion outputs
proven and 70 timeout retries. Its result is not current-source evidence.
Protected-mode acceptance, independent historical-software execution, native
hardware timing and the full release gate also remain open.
