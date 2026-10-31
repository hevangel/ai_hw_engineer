`timescale 1ns/1ps
// ---------------------------------------------------------------------------
// v_noif.sv - axis 4(b): is the if/else inside the loop required?
//
// Only change: the body loses the conditional and keeps one plain accumulate
//   m &= (aa[i] == 1'b1)      for i = 1..12
// which equals "all A high" = the P=0 rule, so the oracle is the same masked
// compare with low = 0 (i.e. all 12 bits must be 1).
//
// errors>0  -> the loop alone (variable bit-select) is enough; the conditional
//              is not necessary.
// errors=0  -> the conditional contributes.
// ---------------------------------------------------------------------------
module v_noif;

    logic        g_n;
    logic [3:0]  p;
    logic [12:1] a;

    int          errors;
    logic [11:0] b;
    logic        got;
    logic        gold;

    function automatic logic ref_y(input logic gn, input logic [3:0] pp,
                                   input logic [12:1] aa);
        logic m;
        m = 1'b1;
        for (int i = 1; i <= 12; i++)
            m &= (aa[i] == 1'b1);
        return gn ? 1'b1 : ~m;
    endfunction

    initial begin
        errors = 0;
        for (int v = 0; v < 131072; v++) begin
            {g_n, p, a} = v[16:0];
            got  = ref_y(g_n, p, a);
            b    = a;
            gold = g_n ? 1'b1 : ~((b & 12'hFFF) == 12'hFFF);
            if (got !== gold) begin
                if (errors < 10)
                    $display("Mismatch v=%0d: g_n=%b p=%0d a=%b -> got %b exp %b",
                             v, g_n, p, a, got, gold);
                errors++;
            end
        end
        $display("errors=%0d", errors);
        $finish;
    end
endmodule
