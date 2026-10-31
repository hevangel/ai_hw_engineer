"""Point the package-library spec at the sourced timing table."""
from pathlib import Path

p = Path("design/apple_ii_chips/spec/spec.md")
t = p.read_text()

old = """Analog package contracts are in [analog.md](analog.md). Optional output delay
`T_PD` is an integer count of nanoseconds under the model's 1 ns timescale.
The motherboard experiment sets 5 ns for TTL/ROM and 20 ns for DRAM outputs;
these are event-ordering assumptions, not measured propagation specifications.
"""
new = """Analog package contracts are in [analog.md](analog.md). Optional output delay
`T_PD` is an integer count of nanoseconds under the model's 1 ns timescale.

The package tests leave `T_PD` at zero. The motherboard generator reads
[board/timing.json](../../../system/apple_ii/board/timing.json), which cites a
manufacturer datasheet, document and page for every part, and can build the
board with typical (`--timing typ`) or published maximum (`--timing max`)
delays. Its checked-in default remains the earlier uniform 5 ns TTL/ROM and
20 ns DRAM placeholder until the directed testbenches are retimed; memory
delays stay idealized because the 4116 model has no row-access or refresh
behaviour. These are model options, not a claim of characterized timing.
"""
assert t.count(old) == 1
p.write_text(t.replace(old, new), newline="\r\n")
print("ok")
