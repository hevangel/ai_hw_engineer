"""Extract independent graphics expectations from the archived MAME artifact.

The three rows are above/on/below underline, encoded LA1/LA0/VSP/LTEN.
Cross-checked against Intel Table 2 (PDF page 13). No RTL is read here.
"""
import re
from pathlib import Path

here = Path(__file__).resolve().parent
source = (here / "mame_graphics_reference.txt").read_text()
table = source.split("character_attribute[3][16] =", 1)[1].split("};", 1)[0]
values = [int(n, 0) for n in re.findall(r"0x[0-9a-f]+|\b\d+\b", table)]
assert len(values) == 48
(here / "graphics_vectors.hex").write_text("\n".join(f"{n:x}" for n in values) + "\n")
