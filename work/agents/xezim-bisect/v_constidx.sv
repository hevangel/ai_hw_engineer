`timescale 1ns/1ps
// ---------------------------------------------------------------------------
// v_constidx.sv - axis 5: variable bit-select aa[i] versus constant aa[1].
//
// Only change: the loop still runs 12 iterations, but the bit-select uses
// constant indices. A constant select cannot be out of range, so x here can
// only come from a corrupted loop counter or a corrupted argument.
//
// Detector is x-only (the rule this body computes is not the 679 rule).
//
// xcount=0  -> the variable index aa[i] is a necessary ingredient.
// xcount>0  -> even a constant bit-select sees a corrupted port/loop variable.
// ---------------------------------------------------------------------------
module v_constidx;

    logic        g_n;
    logic [3:0]  p;
    logic [12:1] a;

    int          xcount;
    logic        got;

    function automatic logic ref_y(input logic gn, input logic [3:0] pp,
                                   input logic [12:1] aa);
        logic m;
        m = 1'b1;
        for (int i = 1; i <= 12; i++)
            if (i <= int'(pp)) m &= (aa[1] == 1'b0);
            else               m &= (aa[12] == 1'b1);
        return gn ? 1'b1 : ~m;
    endfunction

    initial begin
        xcount = 0;
        for (int v = 0; v < 131072; v++) begin
            {g_n, p, a} = v[16:0];
            got = ref_y(g_n, p, a);
            if (got === 1'bx) begin
                if (xcount < 10)
                    $display("x at v=%0d: g_n=%b p=%0d a=%b", v, g_n, p, a);
                xcount++;
            end
        end
        $display("xcount=%0d", xcount);
        $finish;
    end
endmodule
