"""Retime the directed socket test to sample at the phi2 falling edge."""
from pathlib import Path

P = Path(r'B:\ai_hw_engineer\worktree\apple-ii-retime\system\apple_ii\tb\tb_rev0_wiring.sv')
t = P.read_text()

old_decl = """    int cpu_edges = 0;
    assign data = rw ? 8'bz : write_data;
"""
new_decl = """    int cpu_edges = 0;
    time edge_time = 0;
    int arrive_ns = -1;
    logic reading = 0;
    assign data = rw ? 8'bz : write_data;
"""
assert t.count(old_decl) == 1
t = t.replace(old_decl, new_decl)

old_hook = """    initial begin #2000; forever #34.921 osc = ~osc; end
"""
new_hook = """    // Record how long the DRAM took to drive a defined value in the read phase.
    always @(data)
        if (reading && arrive_ns < 0 && data !== 8'bz && !$isunknown(data))
            arrive_ns = $time - edge_time;

    initial begin #2000; forever #34.921 osc = ~osc; end
"""
assert t.count(old_hook) == 1
t = t.replace(old_hook, new_hook)

old_sample = """            repeat(2) @(posedge phi0);
            #470;
            if(data !== 8'(8'h5a+i)) begin
"""
new_sample = """            repeat(2) @(posedge phi0);
            // The 6502 latches read data at the phi2 falling edge, so the socket
            // harness samples there instead of 18 ns early. A fixed early sample
            // sits 1-3 ns inside the valid window once package delays are real.
            edge_time = $time; arrive_ns = -1; reading = 1;
            @(negedge phi0);
            reading = 0;
            if(data !== 8'(8'h5a+i)) begin
"""
assert t.count(old_sample) == 1
t = t.replace(old_sample, new_sample)

old_pass = """            @(negedge phi0); #10;
"""
new_pass = """            $display("READ row %0d data=%h at +%0d ns after phi2 rise",i,data,arrive_ns);
            @(negedge phi0); #10;
"""
assert t.count(old_pass) == 1
t = t.replace(old_pass, new_pass)

P.write_text(t, newline='\r\n')
print('socket test retimed')
