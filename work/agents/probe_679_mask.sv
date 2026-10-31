`timescale 1ns/1ps
// Diagnostic probe: mask-based equivalent oracle, full exhaustive sweep.
module probe_679_mask;
    logic        g_n;
    logic [3:0]  p;
    logic [12:1] a;
    logic        y;
    int errors;

    ttl_74x679 dut (.g_n(g_n), .p(p), .a(a), .y(y));

    function automatic logic ref_y(input logic gn, input logic [3:0] pp,
                                   input logic [12:1] aa);
        logic [11:0] b;
        logic [11:0] low;
        logic        match;
        int          k;
        b = aa;                       // a[12:1] -> b[11:0]
        k = pp;                       // unsigned 0..15
        low = (k >= 12) ? 12'hFFF : ((12'h001 << k) - 12'h001);
        match = ((b & low) == 12'h000) && ((b & ~low) == (12'hFFF & ~low));
        return gn ? 1'b1 : ~match;
    endfunction

    initial begin
        errors = 0;
        for (int v = 0; v < 131072; v++) begin
            logic exp_y;
            {g_n, p, a} = v[16:0];
            #1;
            exp_y = ref_y(g_n, p, a);
            if (y !== exp_y) begin
                if (errors < 10)
                    $display("Mismatch v=%0d: g_n=%b p=%b a=%b -> got %b exp %b",
                             v, g_n, p, a, y, exp_y);
                errors++;
            end
        end
        $display("errors=%0d", errors);
        $finish;
    end
endmodule
