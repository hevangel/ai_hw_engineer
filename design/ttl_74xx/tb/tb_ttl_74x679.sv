`timescale 1ns/1ps
// Exhaustive testbench for ttl_74x679. The input space is 12 A + 4 P + g_n =
// 17 bits (131072 vectors) — small enough to check exhaustively against a
// reference model. This covers every threshold P = 0..15 (including the
// P >= 12 "all low" aliases) and both enable polarities.
module tb_ttl_74x679;
    logic        g_n;
    logic [3:0]  p;
    logic [12:1] a;
    logic        y;
    int errors;

    ttl_74x679 dut (.g_n(g_n), .p(p), .a(a), .y(y));

    function automatic logic ref_y(input logic gn, input logic [3:0] pp,
                                    input logic [12:1] aa);
        logic m;
        m = 1'b1;
        for (int i = 1; i <= 12; i++)
            if (i <= int'(pp)) m &= (aa[i] == 1'b0);
            else               m &= (aa[i] == 1'b1);
        return gn ? 1'b1 : ~m;
    endfunction

    initial begin
        errors = 0;
        for (int v = 0; v < (1 << 17); v++) begin
            {g_n, p, a} = v[16:0];
            #1;
            if (y !== ref_y(g_n, p, a)) begin
                $display("Mismatch v=%0d: g_n=%b p=%b a=%b -> got %b exp %b",
                         v, g_n, p, a, y, ref_y(g_n, p, a));
                errors++;
            end
        end
        if (errors != 0) $fatal(1, "tb_ttl_74x679: %0d mismatches", errors);
        $display("PASS: tb_ttl_74x679 (131072 vectors, exhaustive)");
        $finish;
    end
endmodule
