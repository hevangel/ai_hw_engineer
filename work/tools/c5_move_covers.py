"""C5: put sequencer-state covers where the enum is in scope, and drive the
wrapper's instruction-class covers from the fetch_o port."""
from pathlib import Path

rtl = Path("design/mos_6502_family/mos_6502/cycle/src/mos_6502_cycle.sv")
text = rtl.read_text()
old = """            cover(fetch_o && pc==16'h8000);
            cover(bus_we && state==RMW_NEW);
            cover(state==INT_STATUS && !interrupt_brk);
"""
new = """            cover(fetch_o && pc==16'h8000);
            cover(bus_we && state==RMW_NEW);
            cover(state==INT_STATUS && !interrupt_brk);
            // Sequencer-path covers: each control-flow family must stay
            // reachable, so a stranded state fails the cover task.
            cover(state==MEM_READ);
            cover(state==MEM_WRITE);
            cover(state==RMW_OLD);
            cover(state==BRANCH_FIX);
            cover(state==JMP_HIGH);
            cover(state==JSR_FINISH);
            cover(state==PULL_READ);
            cover(state==RTS_FINISH);
            cover(state==RTI_HIGH);
            cover(state==INT_HIGH);
            cover(state==VECTOR_HIGH);
"""
assert text.count(old) == 1
rtl.write_text(text.replace(old, new), newline="\r\n")

wrapper = Path("design/mos_6502_family/mos_6502/cycle/formal/mos_6502_cycle_formal.sv")
text = wrapper.read_text()
start = text.find("    // Sequencer coverage.")
end = text.find("    // Instruction-class coverage")
assert 0 < start < end
text = text[:start] + text[end:]
text = text.replace("if (rst_n && dut.state == 6'd0) begin", "if (rst_n && fetch_o) begin")
wrapper.write_text(text, newline="\n")
print("ok")
