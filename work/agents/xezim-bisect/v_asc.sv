`timescale 1ns/1ps
// ---------------------------------------------------------------------------
// v_asc.sv - axis 5: ascending range [0:11] instead of [12:1]/[11:0].
//
// `logic [0:11] a` puts index 0 at the MSB, so a[i] is address A(i+1) but the
// numeric weight is flipped. The oracle is therefore mirrored: with
// b = a (b[11] = a[0]) the TOP p bits of b must be zero, not the low ones.
//
// errors=0  -> only non-zero-based *descending* ranges are safe.
// errors>0  -> the failure follows the port, whichever direction it is declared.
// ---------------------------------------------------------------------------
module v_asc;

    logic        g_n;
    logic [3:0]  p;
    logic [0:11] a;

    int          errors;
    logic [11:0] b;
    logic [11:0] zmask;
    int          k;
    logic        got;
    logic        gold;

    function automatic logic ref_y(input logic gn, input logic [3:0] pp,
                                   input logic [0:11] aa);
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
            got = ref_y(g_n, p, a);
            b   = a;
            k   = p;
            if (k >= 12) zmask = 12'hFFF;
            else         zmask = (12'hFFF << (12 - k)) & 12'hFFF;
            gold = g_n ? 1'b1
                       : ~(((b & zmask) == 12'h000) &&
                           ((b & ~zmask) == (12'hFFF & ~zmask)));
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
