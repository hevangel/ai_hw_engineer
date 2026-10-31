"""S2 documentation updates."""
from pathlib import Path

readme = Path("system/apple_ii/README.md")
text = readme.read_text()
old = """Individual regressions have separate passing scripts. The motherboard uses
Icarus; package tests use Xezim. `sh scripts/run_timing_sim.sh` repeats the
socket and Monitor gates with datasheet package delays; see
[package timing](board/README.md#package-timing) for what is and is not covered.
"""
new = """Individual regressions have separate passing scripts. The motherboard uses
Icarus only; package tests use Xezim. Xezim cannot run the resolved board bus
(it loses driven CPU data), so it is not a board option;
`scripts/run_xezim_board_probe.sh` keeps that tool defect reproducible and is
expected to fail. `sh scripts/run_timing_sim.sh` repeats the socket and Monitor
gates with datasheet package delays; see
[package timing](board/README.md#package-timing) for what is and is not covered.
"""
assert text.count(old) == 1
readme.write_text(text.replace(old, new), newline="\r\n")

report = Path("system/apple_ii/report/final_report.md")
text = report.read_text()
old = """6. Xezim package tests pass; the complete resolved-bus board test loses driven
   CPU data. Icarus passes the identical board test. The full reproducer is
   `SIMULATOR=xezim sh scripts/run_board_sim.sh`; scalar reductions passed,
   so the simulator defect is not yet reduced to an isolated minimal case.
"""
new = """6. Xezim package tests pass; the complete resolved-bus board test loses driven
   CPU data, so Icarus is the board simulator and Xezim is not a board option.
   `scripts/run_xezim_board_probe.sh` reproduces the defect and is expected to
   fail; scalar reductions passed, so it is not yet reduced to a minimal case.
"""
assert text.count(old) == 1
report.write_text(text.replace(old, new), newline="\r\n")

plan = Path("system/apple_ii/plans/implementation_plan.md")
text = plan.read_text()
old = "5. Reduce the Xezim resolved-bus failure and establish a passing board backend."
new = ("5. Icarus is the declared board backend. Reduce the Xezim resolved-bus defect\n"
       "   with `scripts/run_xezim_board_probe.sh` as the reproducible failing case.")
assert text.count(old) == 1
plan.write_text(text.replace(old, new), newline="\r\n")
print("ok")
