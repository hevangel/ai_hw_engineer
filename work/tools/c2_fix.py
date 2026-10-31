"""C2: ignore NMI edges while the interrupt sequence is in flight.

The NMOS 6502 loses an NMI that arrives during the interrupt sequence (the
well-known NMI-during-BRK window); perfect6502 is the oracle. Accepting the
edge produces an immediate re-entry the transistor netlist never performs.
"""
from pathlib import Path

p = Path("design/mos_6502_family/mos_6502/cycle/src/mos_6502_cycle.sv")
t = p.read_text()

old = """    logic interrupt_brk, irq_latched, nmi_latched;
    logic previous_nmi, previous_so, previous_irq, nmi_pending;
"""
new = """    logic interrupt_brk, irq_latched, nmi_latched;
    logic previous_nmi, previous_so, previous_irq, nmi_pending;
    logic in_interrupt_sequence;
"""
assert t.count(old) == 1
t = t.replace(old, new)

old = """    always_ff @(posedge clk) begin
        if(!rst_n) begin"""
new = """    // ASSUMPTION: an NMI edge inside the interrupt sequence is lost, matching
    // the NMOS NMI-during-BRK window. Verified against perfect6502 by the
    // back-to-back NMI sweep in tb/pin_test.cpp.
    assign in_interrupt_sequence = state==INT_DUMMY || state==INT_HIGH ||
        state==INT_LOW || state==INT_STATUS || state==VECTOR_LOW ||
        state==VECTOR_HIGH;

    always_ff @(posedge clk) begin
        if(!rst_n) begin"""
assert t.count(old) == 1
t = t.replace(old, new)

old = """            if(previous_nmi && !nmi_n) nmi_pending<=1;"""
new = """            if(previous_nmi && !nmi_n && !in_interrupt_sequence) nmi_pending<=1;"""
assert t.count(old) == 1
t = t.replace(old, new)

p.write_text(t, newline="\r\n")
print("ok")
