`timescale 1ns/1ps
// Exhaustive testbench for ttl_74x2253: s(2)+g_n(2)+d0(4)+d1(4) = 12 bits
// (4096 vectors), all checked against the dual 4-to-1 mux with per-channel
// active-low output enable.
module tb_ttl_74x2253;
    logic [1:0] s, g_n, y, expected;
    logic [3:0] d0, d1;
    ttl_74x2253 dut(.s(s), .g_n(g_n), .d0(d0), .d1(d1), .y(y));
    int errors;
    initial begin
        errors = 0;
        for (int v = 0; v < (1 << 12); v++) begin
            {g_n, s, d1, d0} = v[11:0];
            #1;
            expected[0] = g_n[0] ? 1'b0 : d0[s];
            expected[1] = g_n[1] ? 1'b0 : d1[s];
            if (y !== expected) begin
                $display("Mismatch v=%0d: s=%b g_n=%b d0=%b d1=%b got %b exp %b",
                         v, s, g_n, d0, d1, y, expected);
                errors++;
            end
        end
        if (errors != 0) $fatal(1, "tb_ttl_74x2253: %0d mismatches", errors);
        $display("PASS: tb_ttl_74x2253 (4096 vectors, exhaustive)");
        $finish;
    end
endmodule
