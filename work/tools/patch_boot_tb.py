"""Retime tb_rev0_boot sampling for real package delays (CRLF file)."""
from pathlib import Path

path = Path("system/apple_ii/tb/tb_rev0_boot.sv")
text = path.read_text()

old_head = """    initial forever #34.921 osc=~osc;
    initial forever begin
        @(posedge dut.board.B10.p3); #10;"""
new_head = """    // Sample late in the 69.8 ns master period so the value belongs to the
    // pixel just clocked, after the worst-case 74LS74 clock-to-Q (40 ns).
    localparam real VIDEO_SAMPLE_NS=50.0;
    localparam real SCAN_SAMPLE_NS=40.0;
    // Delayed continuous assignments start as X everywhere, so the netlist gets
    // a static settle window before the real oscillator starts. Silicon has no
    // equivalent X state; this only removes a time-zero artifact.
    initial begin #2000; forever #34.921 osc=~osc; end
    initial forever begin
        @(posedge dut.board.B10.p3); #(VIDEO_SAMPLE_NS);"""

assert text.count(old_head) == 1
text = text.replace(old_head, new_head)

# All scan sampling points move to the delayed counter value.
assert text.count("#25;") == 3
text = text.replace("#25;", "#(SCAN_SAMPLE_NS);")

path.write_text(text, newline="\r\n")
print("patched", path)
