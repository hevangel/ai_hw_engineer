"""Correct the package-timing documentation to match the cited table."""
from pathlib import Path

BASE = Path(r'B:\ai_hw_engineer\worktree\apple-ii-timing')


def patch(rel, old, new):
    p = BASE / rel
    t = p.read_text()
    assert t.count(old) == 1, f'{rel}: anchor count {t.count(old)}'
    p.write_text(t.replace(old, new), newline='\r\n')
    print('patched', rel)


patch(
    r'system\apple_ii\board\README.md',
    '''`timing.json` records a per-part propagation delay for every package model,
with the datasheet, document number and page that publish it. A module's
`T_PD` parameter delays each package output; internal state still follows the
documented clock edge.

`generate_rev0.py --timing typ|max` regenerates the identical netlist with
typical or maximum datasheet delays. `--timing legacy` keeps the original
uniform 5 ns placeholder and remains the checked-in default, because the
directed testbenches encode zero-delay phase relationships that have not all
been retimed. `scripts/run_timing_sim.sh` runs the socket wiring test and the
unmodified Monitor boot at datasheet timing; measured results and open harness
work are in the [verification report](../report/final_report.md).

The memory packages keep the legacy placeholder. The 4116 model has no row
access (tRAC) or refresh behaviour, so a datasheet access delay makes the video
data latch capture Hi-Z between CAS cycles. That belongs to review item P3, not
to the TTL delay table.
''',
    '''`timing.json` records a per-part propagation delay for every package model,
with the manufacturer document and printed page that publish it. The TI
literature number is recorded only where the scan prints one; the rest cite the
document URL and page, because an unprinted number is not a citation. A
module's `T_PD` parameter delays each package output; internal state still
follows the documented clock edge.

`generate_rev0.py --timing typ|max` regenerates the same connectivity with
typical or published maximum delays, and refuses to run when a characterized
part has no source. The two boards differ only in `T_PD` values. `--timing
legacy` keeps the original uniform 5 ns placeholder and remains the checked-in
default, because the directed testbenches encode zero-delay phase relationships
that have not all been retimed. `scripts/run_timing_sim.sh` runs the socket
wiring test and the unmodified Monitor boot at datasheet timing; measured
results and open harness work are in the
[verification report](../report/final_report.md).

Two entries are bounds rather than numbers measured at the board load. The 8T97
sheet is specified at CL = 50 pF, so its 13 ns maximum is conservative at
15 pF, and no Signetics 8T28 delay could be read, so the AMD second-source
17 ns maximum is used. `timing.json` carries both caveats on the entries.

The memory packages are marked `idealized` and keep the legacy output delay in
every mode: 20 ns for the 4116, 5 ns for the system ROM and 2513. The 4116 model
has no row access (tRAC) or refresh behaviour, so a datasheet access delay makes
the video data latch capture Hi-Z between CAS cycles. That belongs to review
item P3, not to the TTL delay table.
''')

patch(
    r'system\apple_ii\spec\spec.md',
    '''- ASSUMPTION: memory packages (4116, system ROM, 2513) keep that placeholder
  because the 4116 model has no row-access or refresh timing.
''',
    '''- ASSUMPTION: memory packages (4116, system ROM, 2513) are marked
  `idealized` and keep that placeholder in every timing mode, because the 4116
  model has no row-access, column-access or refresh timing.
- ASSUMPTION: two characterized delays are bounds, not board-load numbers. The
  8T97 value is its datasheet maximum at CL = 50 pF, and the 8T28 value is the
  AMD second-source maximum because no Signetics delay was readable.
''')
