`timescale 1ns/1ps
// ---------------------------------------------------------------------------
// v_foreach.sv - axis 4(d): is `for (int i = ...)` required?
//
// Same rule, same body, but the loop is
//   foreach (aa[i]) ...
// which for a [12:1] packed variable visits i = 1..12.
//
// errors>0  -> any iteration construct over the port triggers it.
// errors=0  -> the C-style for loop with its own induction variable is required.
// ---------------------------------------------------------------------------
module v_foreach;

    logic        g_n;
    logic [3:0]  p;
    logic [12:1] a;

    int          errors;
    logic [11:0] b;
    logic [11:0] low;
    int          k;
    logic        got;
    logic        gold;

    function automatic logic ref_y(input logic gn, input logic [3:0] pp,
                                   input logic [12:1] aa);
        logic m;
        m = 1'b1;
        foreach (aa[i])
            if (i <= int'(pp)) m &= (aa[i] == 1'b0);
            else               m &= (aa[i] == 1'b1);
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
