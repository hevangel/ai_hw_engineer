from pathlib import Path
p = Path(r'B:\ai_hw_engineer\worktree\apple-ii-retime\system\apple_ii\scripts\run_timing_sim.sh')
t = p.read_text()
old = """    if [ "$mode" = typ ]; then
        python3 scripts/check_monitor_video.py
    fi
"""
assert t.count(old) == 1
t = t.replace(old, "")
old2 = """#   - the frame comparison runs at typical delays only. composite_sync is
#     produced after a deeper gate chain than the counter outputs the oracle
#     compares it against, so at maximum delays the same-instant comparison
#     cannot hold: no constant dot shift reconciles it (measured in
#     report/final_report.md). That limit is stated rather than hidden behind a
#     weaker check."""
new2 = """#   - the frame comparison is not run here. composite_sync is produced after a
#     deeper gate chain than the counter outputs the oracle derives it from, so
#     at datasheet delays the same-instant comparison cannot hold: no constant
#     dot shift reconciles it (measured in report/final_report.md). The frame
#     gate therefore stays on the legacy board in run_authored_boot.sh."""
assert t.count(old2) == 1
t = t.replace(old2, new2)
old3 = "echo 'PASS datasheet timing gate: socket wiring and Monitor boot at typical and maximum delays, frame comparison at typical delays (see report)'"
new3 = "echo 'PASS datasheet timing gate: socket wiring and Monitor boot at typical and maximum delays; frame comparison stays on the legacy board (see report)'"
assert t.count(old3) == 1
t = t.replace(old3, new3)
p.write_text(t, newline='\r\n')
print('gate scope corrected')
