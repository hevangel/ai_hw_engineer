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

    // A1..Ak must be low and A(k+1)..A12 must be high, k = P. Expressed as two
    // masked comparisons instead of a per-bit accumulation loop: the per-bit
    // form produced x/stale expectations for 43 vectors under xezim 0.11.3.
    // The two forms agree on all 131072 vectors (checked independently).
    function automatic logic ref_y(input logic gn, input logic [3:0] pp,
                                    input logic [12:1] aa);
        logic [11:0] bits;   // bits[0] = A1, bits[11] = A12
        logic [11:0] low;    // positions that must be low: A1..Ak
        logic        match;
        bits  = aa;
        low   = (pp >= 12) ? 12'hFFF : ((12'h001 << pp) - 12'h001);
        match = ((bits & low) == 12'h000) &&
                ((bits & ~low) == (12'hFFF & ~low));
        return gn ? 1'b1 : ~match;
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
