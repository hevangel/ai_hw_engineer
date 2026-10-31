"""Remove the verbatim duplicate 'Physical package adapter' section (review C6)."""
from pathlib import Path

path = Path("design/mos_6502_cycle/spec/spec.md")
text = path.read_text()

section = """## Physical package adapter

`a2_mos6502` maps the original 40 pins, resolves data only while writing,
and consumes a read before phi0 falls. Its startup counter chooses canonical
internal initialization for three clocks; the motherboard RES pin remains a
warm reset. ASSUMPTION: phi1/phi2 outputs are ideal complementary levels;
analog delay and clock non-overlap are not modeled. ASSUMPTION: unresolved
read bits sample high and increment `unknown_read_samples`, matching the
explicit external reference boundary. No electrical validity is inferred.
NC pins 5, 35 and 36 are unused. Only `mos_6502_cycle`, not this resolved-pin
simulation adapter, is covered by the synthesis gate.
"""

assert text.count(section) == 2, text.count(section)
text = text.replace(section, "", 1)
path.write_text(text, newline="\r\n")
print("removed duplicate section")
