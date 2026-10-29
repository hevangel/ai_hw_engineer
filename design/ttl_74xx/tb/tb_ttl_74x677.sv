`timescale 1ns/1ps
// Testbench for ttl_74x677. The input space (16 A + 4 P + g_n = 21 bits) is too
// large to exhaust, so this uses:
//   1. Every datasheet Function Table row: for each threshold k = 0..15, the
//      exact matching pattern (A1..Ak low, rest high) must drive Y low; a
//      single flipped bit must drive Y high; the disabled (g_n=1) case is high.
//   2. 1000 seeded-random vectors checked against a reference model.
module tb_ttl_74x677;
    logic        g_n;
    logic [3:0]  p;
    logic [16:1] a;
    logic        y;
    int errors;

    ttl_74x677 dut (.g_n(g_n), .p(p), .a(a), .y(y));

    // Reference model: low iff enabled and A1..Ak low, A(k+1)..A16 high.
    function automatic logic ref_y(input logic gn, input logic [3:0] pp,
                                    input logic [16:1] aa);
        logic m;
        m = 1'b1;
        for (int i = 1; i <= 16; i++)
            if (i <= int'(pp)) m &= (aa[i] == 1'b0);
            else               m &= (aa[i] == 1'b1);
        return gn ? 1'b1 : ~m;
    endfunction

    // Build the canonical matching address for threshold k.
    function automatic logic [16:1] match_addr(input int k);
        logic [16:1] aa;
        for (int i = 1; i <= 16; i++) aa[i] = (i <= k) ? 1'b0 : 1'b1;
        return aa;
    endfunction

    task automatic check(input string tag);
        #1;
        if (y !== ref_y(g_n, p, a)) begin
            $display("Mismatch [%s]: g_n=%b p=%b a=%b -> got %b exp %b",
                     tag, g_n, p, a, y, ref_y(g_n, p, a));
            errors++;
        end
    endtask

    logic [31:0] dummy;
    initial begin
        errors = 0;

        // 1. Directed: every datasheet row.
        for (int k = 0; k <= 15; k++) begin
            p = k[3:0];

            // Exact match, enabled -> Y low.
            g_n = 1'b0; a = match_addr(k);
            check($sformatf("k=%0d match", k));

            // Same pattern but disabled -> Y high.
            g_n = 1'b1;
            check($sformatf("k=%0d disabled", k));

            // Enabled, one bit flipped -> Y high (mismatch). Flip bit 1.
            g_n = 1'b0; a = match_addr(k); a[1] = ~a[1];
            check($sformatf("k=%0d flip1", k));
            // Flip a high-half bit (16) too.
            a = match_addr(k); a[16] = ~a[16];
            check($sformatf("k=%0d flip16", k));
        end

        // 2. Seeded random.
        dummy = $urandom(32'h0677_A5A5);
        for (int n = 0; n < 1000; n++) begin
            dummy = $urandom; g_n = dummy[0];
            dummy = $urandom; p   = dummy[3:0];
            dummy = $urandom; a   = dummy[15:0];
            check($sformatf("rand %0d", n));
        end

        if (errors != 0) $fatal(1, "tb_ttl_74x677: %0d mismatches", errors);
        $display("PASS: tb_ttl_74x677 (64 directed + 1000 random vectors)");
        $finish;
    end
endmodule
