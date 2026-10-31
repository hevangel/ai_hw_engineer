`timescale 1ns/1ps
// Discriminate where the x enters ref_y: local accumulator, formal copy, or loop lowering.
module probe_679_disc;
    int errA, errB, errC, errD, errE;
    logic dbg_on;

    // A: the original shape
    function automatic logic refA(input logic gn, input logic [3:0] pp, input logic [12:1] aa);
        logic m;
        m = 1'b1;
        for (int i = 1; i <= 12; i++)
            if (i <= pp) m &= (aa[i] == 1'b0);
            else         m &= (aa[i] == 1'b1);
        return gn ? 1'b1 : ~m;
    endfunction

    // B: declaration initialiser instead of a separate blocking assign
    function automatic logic refB(input logic gn, input logic [3:0] pp, input logic [12:1] aa);
        logic m = 1'b1;
        for (int i = 1; i <= 12; i++)
            if (i <= pp) m &= (aa[i] == 1'b0);
            else         m &= (aa[i] == 1'b1);
        return gn ? 1'b1 : ~m;
    endfunction

    // C: copy the formal into a zero-based local first
    function automatic logic refC(input logic gn, input logic [3:0] pp, input logic [12:1] aa);
        logic [11:0] b;
        logic m;
        b = aa;
        m = 1'b1;
        for (int i = 1; i <= 12; i++)
            if (i <= pp) m &= (b[i-1] == 1'b0);
            else         m &= (b[i-1] == 1'b1);
        return gn ? 1'b1 : ~m;
    endfunction

    // D: same as A but no early-in-loop conditional — arithmetic select instead
    function automatic logic refD(input logic gn, input logic [3:0] pp, input logic [12:1] aa);
        logic [11:0] b;
        logic [11:0] low;
        b = aa;
        low = (pp >= 12) ? 12'hFFF : ((12'h001 << pp) - 12'h001);
        return gn ? 1'b1 : ~(((b & low) == 12'h000) && ((b & ~low) == (12'hFFF & ~low)));
    endfunction

    // E: A, but with a $display when the failing vector is seen (state probe)
    function automatic logic refE(input logic gn, input logic [3:0] pp, input logic [12:1] aa);
        logic m;
        m = 1'b1;
        for (int i = 1; i <= 12; i++)
            if (i <= pp) m &= (aa[i] == 1'b0);
            else         m &= (aa[i] == 1'b1);
        if (dbg_on && gn === 1'b0 && pp === 4'b0000 && aa === 12'b111111111110)
            $display("  [inside refE] m=%b aa=%b -> ~m=%b", m, aa, ~m);
        return gn ? 1'b1 : ~m;
    endfunction

    initial begin
        errA = 0; errB = 0; errC = 0; errD = 0; errE = 0;
        dbg_on = 1'b0;
        for (int v = 0; v < (1 << 17); v++) begin
            logic gn; logic [3:0] pp; logic [12:1] aa;
            logic truth;
            {gn, pp, aa} = v[16:0];
            truth = refD(gn, pp, aa);          // mask form, already proven correct
            #1;
            if (refA(gn, pp, aa) !== truth) errA++;
            if (refB(gn, pp, aa) !== truth) errB++;
            if (refC(gn, pp, aa) !== truth) errC++;
            if (refD(gn, pp, aa) !== truth) errD++;
            if (v == 4094) begin
                dbg_on = 1'b1;
                if (refE(gn, pp, aa) !== truth)
                    $display("  refE wrong at v=4094 (truth=%b)", truth);
                dbg_on = 1'b0;
            end
        end
        $display("errA(original)=%0d errB(decl-init)=%0d errC(zero-based local)=%0d errD(mask)=%0d",
                 errA, errB, errC, errD);
        $finish;
    end
endmodule
