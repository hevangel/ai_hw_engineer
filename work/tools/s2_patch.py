"""S2: Icarus is the board simulator; drop the SIMULATOR switch (CRLF files)."""
from pathlib import Path

pairs = [
    ("system/apple_ii/scripts/run_all.sh",
     "SIMULATOR=iverilog sh scripts/run_board_sim.sh",
     "sh scripts/run_board_sim.sh"),
    ("system/apple_ii/board/DEPENDENCIES.md",
     "SIMULATOR=iverilog sh scripts/run_board_sim.sh",
     "sh scripts/run_board_sim.sh"),
]
for name, old, new in pairs:
    path = Path(name)
    text = path.read_text()
    assert text.count(old) == 1, (name, text.count(old))
    path.write_text(text.replace(old, new), newline="\r\n")
print("ok")
