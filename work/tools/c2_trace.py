"""Temporary per-cycle trace for the back-to-back NMI case."""
from pathlib import Path

p = Path("design/mos_6502_family/mos_6502/cycle/tb/pin_test.cpp")
t = p.read_text()
old = """            cpu.irq_n=irq;cpu.nmi_n=nmi;cpu.rdy=ready;cpu.so_n=so;cpu.res_n=res;
            oracle_pins(res,irq,nmi,ready,so);"""
new = """            cpu.irq_n=irq;cpu.nmi_n=nmi;cpu.rdy=ready;cpu.so_n=so;cpu.res_n=res;
            oracle_pins(res,irq,nmi,ready,so);
            if(getenv("TRACE") && test==728)
                std::printf("TRACE c=%u nmi=%d rtl pc=%04x addr=%04x we=%d sync=%d P=%02x | ora addr=%04x rw=%d sync=%d P=%02x\\n",
                    cycle,nmi,cpu.pc_o,cpu.bus_addr,cpu.bus_we,cpu.fetch_o,cpu.status_o,
                    oracle_address(),oracle_rw(),oracle_sync(),oracle_p());"""
assert t.count(old) == 1
p.write_text(t.replace(old, new), newline="\r\n")
print("ok")
