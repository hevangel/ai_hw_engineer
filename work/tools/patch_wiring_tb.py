"""Add the power-up settle window to the wiring testbench (CRLF file)."""
from pathlib import Path

path = Path("system/apple_ii/tb/tb_rev0_wiring.sv")
text = path.read_text()

old = "    initial forever #34.921 osc = ~osc;"
new = """    // Delayed continuous assignments start as X everywhere, so the netlist gets
    // a static settle window before the real oscillator starts. Silicon has no
    // equivalent X state; this only removes a time-zero artifact.
    initial begin #2000; forever #34.921 osc = ~osc; end"""
assert text.count(old) == 1
path.write_text(text.replace(old, new), newline="\r\n")
print("patched", path)
