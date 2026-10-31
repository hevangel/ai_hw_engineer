`timescale 1ns/1ps
// ---------------------------------------------------------------------------
// v_retm.sv - axis 6: is the `gn ? 1'b1 : ~m` return expression required?
//
// Only change: the function returns the accumulator directly (`return m;`),
// no ternary and no inversion. g_n is held at 0 for the whole sweep, so the
// value under test is exactly `match` and the oracle is the same masked compare
// without the final inversion.
//
// errors>0  -> the ternary/inversion is not involved; the loop or the port is.
// errors=0  -> the ternary return expression is part of the trigger.
// ---------------------------------------------------------------------------
module v_retm;

    logic [3:0]  p;
    logic [12:1] a;

    int          errors;
    logic [11:0] b;
    logic [11:0] low;
    int          k;
    logic        got;
    logic        gold;

    function automatic logic ref_y(input logic [3:0] pp,
                                   input logic [12:1] aa);
        logic m;
        m = 1'b1;
        for (int i = 1; i <= 12; i++)
            if (i <= int'(pp)) m &= (aa[i] == 1'b0);
            else               m &= (aa[i] == 1'b1);
        return m;
    endfunction

    initial begin
        errors = 0;
        for (int v = 0; v < 65536; v++) begin
            {p, a} = v[15:0];
            got  = ref_y(p, a);
            b    = a;
            k    = p;
            low  = (k >= 12) ? 12'hFFF : ((12'h001 << k) - 12'h001);
            gold = ((b & low) == 12'h000) &&
                   ((b & ~low) == (12'hFFF & ~low));
            if (got !== gold) begin
                if (errors < 10)
                    $display("Mismatch v=%0d: p=%0d a=%b -> got %b exp %b",
                             v, k, a, got, gold);
                errors++;
            end
        end
        $display("errors=%0d", errors);
        $finish;
    end
endmodule
