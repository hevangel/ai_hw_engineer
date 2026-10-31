"""S4: split the Apple II report into a status page and a dated history."""
from pathlib import Path

report = Path("system/apple_ii/report/final_report.md")
text = report.read_text()
lines = text.split("\n")


def index_of(prefix):
    for i, line in enumerate(lines):
        if line.startswith(prefix):
            return i
    raise SystemExit(f"missing section {prefix}")


start_observed = index_of("## Observed results")
start_limits = index_of("## Limits that prevent sign-off")
start_narrative = index_of("## Video oracle and stimulus corrections")

observed = lines[start_observed:start_limits]
limits = lines[start_limits:start_narrative]
narrative = lines[start_narrative:]

history = "\n".join(
    ["# Revision-0 reconstruction verification history", "",
     "Dated evidence record. Current gate status is in",
     "[final_report.md](final_report.md); superseded results are kept here for",
     "audit rather than deleted.", ""]
    + observed + narrative) + "\n"
Path("system/apple_ii/report/history.md").write_text(history, newline="\r\n")

status = "\n".join(
    ["# Revision-0 reconstruction verification", "",
     "Status of the working tree on `cb9d40f`, 30 October 2026.",
     "Every gate is a script under `scripts/`; `run_all.sh` runs the full set in",
     "order and returns nonzero while analog and font sign-off remain incomplete.",
     "The datasheet timing gate is separate: `scripts/run_timing_sim.sh`.", "",
     "## Gate status", "",
     "<!-- STATUS-TABLE -->", ""]
    + limits) + "\n"
report.write_text(status, newline="\r\n")
print("split", len(observed), len(limits), len(narrative))
