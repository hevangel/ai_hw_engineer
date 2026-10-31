`timescale 1ns/1ps
// ---------------------------------------------------------------------------
// v_zerobase.sv - axis 5: is the non-zero-based port range [12:1] required?
//
// Only change: the function port and the module signal become [11:0], the loop
// runs i = 0..11, and the threshold test becomes `i < pp` (address A(i+1) must
// be low when i+1 <= pp). The rule and the oracle are unchanged.
//
// This is the workaround already recorded in docs/xezim/overview.md for
// design/mos_6567 ("function ports with non-zero-based ranges ... returned X in
// exactly the result bits derived from those ports").
//
// errors=0  -> the [12:1] declaration is a necessary ingredient.
// errors>0  -> the port range is not the trigger.
// ---------------------------------------------------------------------------
module v_zerobase;

    logic        g_n;
    logic [3:0]  p;
    logic [11:0] a;

    int          errors;
    logic [11:0] b;
    logic [11:0] low;
    int          k;
    logic        got;
    logic        gold;

    function automatic logic ref_y(input logic gn, input logic [3:0] pp,
                                   input logic [11:0] aa);
        logic m;
        m = 1'b1;
        for (int i = 0; i <= 11; i++)
            if (i < int'(pp)) m &= (aa[i] == 1'b0);
            else              m &= (aa[i] == 1'b1);
        return gn ? 1'b1 : ~m;
    endfunction

    initial begin
        errors = 0;
        for (int v = 0; v < 131072; v++) begin
            {g_n, p, a} = v[16:0];
            got  = ref_y(g_n, p, a);
            b    = a;
            k    = p;
            low  = (k >= 12) ? 12'hFFF : ((12'h001 << k) - 12'h001);
            gold = g_n ? 1'b1
                       : ~(((b & low) == 12'h000) &&
                           ((b & ~low) == (12'hFFF & ~low)));
            if (got !== gold) begin
                if (errors < 10)
                    $display("Mismatch v=%0d: g_n=%b p=%0d a=%b -> got %b exp %b",
                             v, g_n, k, a, got, gold);
                errors++;
            end
        end
        $display("errors=%0d", errors);
        $finish;
    end
endmodule
