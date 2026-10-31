from pathlib import Path
p = Path(r'B:\ai_hw_engineer\worktree\apple-ii-retime\system\apple_ii\tb\tb_rev0_wiring.sv')
t = p.read_text()
old = """    // Delayed continuous assignments start as X everywhere, so the netlist gets
    // a static settle window before the real oscillator starts. Silicon has no
    // equivalent X state; this only removes a time-zero artifact.
    // Record how long the DRAM took to drive a defined value in the read phase.
    always @(data)
        if (reading && arrive_ns < 0 && data !== 8'bz && !$isunknown(data))
            arrive_ns = $time - edge_time;

    initial begin #2000; forever #34.921 osc = ~osc; end
"""
new = """    // Delayed continuous assignments start as X everywhere, so the netlist gets
    // a static settle window before the real oscillator starts. Silicon has no
    // equivalent X state; this only removes a time-zero artifact.
    initial begin #2000; forever #34.921 osc = ~osc; end

    // Record how long the DRAM took to drive a defined value in the read phase.
    always @(data)
        if (reading && arrive_ns < 0 && data !== 8'bz && !$isunknown(data))
            arrive_ns = $time - edge_time;
"""
assert t.count(old) == 1
p.write_text(t.replace(old, new), newline='\r\n')
print('comment order fixed')
