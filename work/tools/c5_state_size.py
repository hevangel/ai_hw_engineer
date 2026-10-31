"""Size the generated state covers so Yosys can infer the comparison width."""
from pathlib import Path

p = Path("design/mos_6502_family/mos_6502/cycle/formal/mos_6502_cycle_formal.sv")
t = p.read_text()
old = """    for (genvar state_number = 0; state_number < 40; state_number++) begin : g_state
        always_ff @(posedge clk)
            cover(rst_n && dut.state == state_number);
    end
"""
new = """    for (genvar state_number = 0; state_number < 40; state_number++) begin : g_state
        localparam logic [5:0] STATE_VALUE = state_number;
        always_ff @(posedge clk)
            cover(rst_n && dut.state == STATE_VALUE);
    end
"""
assert t.count(old) == 1
p.write_text(t.replace(old, new), newline="\n")
print("ok")
