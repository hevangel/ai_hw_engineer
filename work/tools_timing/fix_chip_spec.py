from pathlib import Path
p = Path(r'B:\ai_hw_engineer\worktree\apple-ii-timing\design\apple_ii_chips\spec\spec.md')
t = p.read_text()
old = """The package tests leave `T_PD` at zero. The motherboard generator reads
[board/timing.json](../../../system/apple_ii/board/timing.json), which cites a
manufacturer datasheet, document and page for every part, and can build the
board with typical (`--timing typ`) or published maximum (`--timing max`)
delays."""
new = """The package tests leave `T_PD` at zero. The motherboard generator reads
[board/timing.json](../../../system/apple_ii/board/timing.json), which records,
for every part, the manufacturer document, printed page and URL that publish
its delay (the literature number where the scan prints one), and can build the
board with typical (`--timing typ`) or published maximum (`--timing max`)
delays."""
assert t.count(old) == 1, t.count(old)
p.write_text(t.replace(old, new), newline='\r\n')
print('chip spec wording aligned')
