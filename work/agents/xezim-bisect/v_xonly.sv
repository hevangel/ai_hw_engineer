`timescale 1ns/1ps
// ---------------------------------------------------------------------------
// v_xonly.sv - axis 8: x-only detector on the unchanged function.
//
// Same function and the same 131072-call loop as minimal_fail.sv, but the
// checker needs no oracle at all: it only counts results that are `x`.
// Reference code can never legally return x here (every operand of the AND is
// 2-valued and m starts at 1), so any x is corruption.
//
// Compare its count with minimal_fail.sv's "errors=":
//   x_count == errors  -> every wrong result is x  (pure X-propagation)
//   x_count <  errors  -> some results are wrong 0/1 (stale/aliased value)
// ---------------------------------------------------------------------------
module v_xonly;

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
            if (i <= int'(pp)) m &= (aa[i] == 1'b0);
            else               m &= (aa[i] == 1'b1);
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
