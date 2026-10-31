## Conflict resolution blocked on a semantic (not textual) conflict

I tried to update this branch against `main` (62 commits behind, merge base `4612e2c`) and stopped: the
conflicts are not mechanical, and a resolved-but-mechanical merge would damage the tree.

### What a mechanical merge produces

* **A hybrid layout.** This branch groups 23 chips into 7 families. `main` has since grown to ~70 flat
  chip folders (`amd_am2902`…`am2918`, `intel_3205`, `intel_3404`, `mos_6507`, `mos_6510`, `mos_6522`,
  `mos_6526`, `mos_6530`, `mos_6532`, `mos_6560`, `mos_6567`, `mos_6581`, `mos_8520`, `ricoh_5a22`,
  `ricoh_5c77`, `ricoh_5c78`, `sony_*`, `wdc_65c816`, …). Only the chips this branch knows about would
  move, so `design/` ends up half-migrated — e.g. `design/mos_6502_family/mos_6502/` next to a flat
  `design/mos_6510/`.
* **A duplicate 74181.** `main` relocated 74181 into its own `ttl_74xx` catalog (`README_74181.md`,
  `spec/74181.md`, `src/alu_74181.sv`, `scripts/run_74181_*.sh`). This branch's
  `ttl_74_series/alu_74181/` is the same RTL in a second layout, so merging keeps two copies, and the
  `ttl_74_series` idea cannot cover the catalog that now sits in `ttl_74xx`.
* **Broken build scripts.** 37 files on `main` reference paths this branch moves and are not in its
  update set. The load-bearing ones:
  * `system/commodore_64/scripts/sources.sh:3` → `$ROOT/design/mos_6502/src/mos_6502_native.sv`
  * `system/scelbi_8b/scripts/run_lint.sh:6`, `run_sim.sh:9,12,18`, `run_system.sh:10`,
    `scripts/test_backend.py:65` → `design/intel_8008/src/intel_8008.sv`
  * 12 shell/Python/SystemVerilog entry points in total.

The C64 system was merged into `main` after this branch was cut; a raw merge would leave it unable to
find its CPU.

### Suggested way forward

1. **Fresh PR on current `main`** for the family consolidation, with a taxonomy that covers all ~70
   chips (AMD Am2900/Am25xx/Am95xx, Intel MCS-4/MCS-8/8086, MOS 65xx, Ricoh, Sony, Motorola, Apple,
   WDC), `ttl_74xx` kept as the TTL catalog, and every script/system source list rewritten and
   re-verified.
2. **Split out the Java half.** The Java JDK addition to the EDA image, its smoke checks and the
   `docs/family-layout-migration.md` write-up are independent of the path moves and would make a small,
   verifiable PR against the current `Dockerfile`.

I am leaving this PR open and unmerged rather than landing a half-migrated layout with broken
references. Merging it as-is is possible if that trade-off is explicitly wanted, but it needs the
`design/` taxonomy decision first.
