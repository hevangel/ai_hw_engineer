"""C2 attempt 2: lose NMI edges inside an NMI sequence only."""
from pathlib import Path

p = Path("design/mos_6502_family/mos_6502/cycle/src/mos_6502_cycle.sv")
t = p.read_text()

pairs = [
("    logic in_interrupt_sequence;",
 "    logic nmi_sequence;"),
("""    // ASSUMPTION: an NMI edge inside the interrupt sequence is lost, matching
    // the NMOS NMI-during-BRK window. Verified against perfect6502 by the
    // back-to-back NMI sweep in tb/pin_test.cpp.
    assign in_interrupt_sequence = state==INT_STATUS || state==VECTOR_LOW ||
        state==VECTOR_HIGH;
""",
 ""),
("""            if(previous_nmi && !nmi_n && !in_interrupt_sequence) nmi_pending<=1;""",
 """            // ASSUMPTION: an NMI edge during an NMI sequence is lost, while an
            // NMI during IRQ/BRK still hijacks the vector. Verified against
            // perfect6502 by the back-to-back NMI sweep in tb/pin_test.cpp.
            if(previous_nmi && !nmi_n && !nmi_sequence) nmi_pending<=1;"""),
("""            nmi_pending<=0;
        end else begin""",
 """            nmi_pending<=0; nmi_sequence<=0;
        end else begin"""),
("""                state<=RESET_0; irq_latched<=0; nmi_latched<=0; nmi_pending<=0;""",
 """                state<=RESET_0; irq_latched<=0; nmi_latched<=0; nmi_pending<=0; nmi_sequence<=0;"""),
("""                        if(nmi_latched || irq_latched) begin
                            interrupt_brk<=0;""",
 """                        if(nmi_latched || irq_latched) begin
                            nmi_sequence<=nmi_latched;
                            interrupt_brk<=0;"""),
("""                    VECTOR_HIGH: begin pc<={bus_data_i,lo}; state<=FETCH; irq_latched<=0; nmi_latched<=0; end""",
 """                    VECTOR_HIGH: begin pc<={bus_data_i,lo}; state<=FETCH; irq_latched<=0; nmi_latched<=0; nmi_sequence<=0; end"""),
]
for old, new in pairs:
    assert t.count(old) == 1, (old[:60], t.count(old))
    t = t.replace(old, new)
p.write_text(t, newline="\r\n")
print("ok")
