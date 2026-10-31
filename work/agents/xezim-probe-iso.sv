`timescale 1ns/1ps
// Isolate why errC==0: is it the copy of the formal, or the [i-1] index base?
module probe_679_iso;
    int errA, errF, errG, errH, errI;

    // A: formal [12:1], direct indexed read  (known failing shape)
    function automatic logic refA(input logic [3:0] pp, input logic [12:1] aa);
        logic m;
        m = 1'b1;
        for (int i = 1; i <= 12; i++)
            if (i <= pp) m &= (aa[i] == 1'b0);
            else         m &= (aa[i] == 1'b1);
        return ~m;
    endfunction

    // F: copy the formal to a local, but keep the SAME direct index aa[i]
    function automatic logic refF(input logic [3:0] pp, input logic [12:1] aa);
        logic m;
        logic [11:0] b;
        b = aa;
        m = 1'b1;
        for (int i = 1; i <= 12; i++)
            if (i <= pp) m &= (aa[i] == 1'b0);
            else         m &= (aa[i] == 1'b1);
        return ~m;
    endfunction

    // G: copy + zero-based index on the local  (= earlier refC)
    function automatic logic refG(input logic [3:0] pp, input logic [12:1] aa);
        logic m;
        logic [11:0] b;
        b = aa;
        m = 1'b1;
        for (int i = 1; i <= 12; i++)
            if (i <= pp) m &= (b[i-1] == 1'b0);
            else         m &= (b[i-1] == 1'b1);
        return ~m;
    endfunction

    // H: zero-based formal, no copy, index [i-1]
    function automatic logic refH(input logic [3:0] pp, input logic [11:0] bb);
        logic m;
        m = 1'b1;
        for (int i = 1; i <= 12; i++)
            if (i <= pp) m &= (bb[i-1] == 1'b0);
            else         m &= (bb[i-1] == 1'b1);
        return ~m;
    endfunction

    // I: ascending formal [1:12] instead of descending [12:1]
    function automatic logic refI(input logic [3:0] pp, input logic [1:12] aa);
        logic m;
        m = 1'b1;
        for (int i = 1; i <= 12; i++)
            if (i <= pp) m &= (aa[i] == 1'b0);
            else         m &= (aa[i] == 1'b1);
        return ~m;
    endfunction

    function automatic logic mask_ref(input logic [3:0] pp, input logic [11:0] b);
        logic [11:0] low;
        low = (pp >= 12) ? 12'hFFF : ((12'h001 << pp) - 12'h001);
        return ~(((b & low) == 12'h000) && ((b & ~low) == (12'hFFF & ~low)));
    endfunction

    initial begin
        errA = 0; errF = 0; errG = 0; errH = 0; errI = 0;
        for (int v = 0; v < (1 << 16); v++) begin
            logic [3:0] pp; logic [12:1] aa; logic truth;
            {pp, aa} = v[15:0];
            truth = mask_ref(pp, aa);
            if (refA(pp, aa) !== truth) errA++;
            if (refF(pp, aa) !== truth) errF++;
            if (refG(pp, aa) !== truth) errG++;
            if (refH(pp, aa) !== truth) errH++;
            if (refI(pp, aa) !== truth) errI++;
        end
        $display("errA([12:1] direct)=%0d  errF(copy, still aa[i])=%0d  errG(copy + b[i-1])=%0d",
                 errA, errF, errG);
        $display("errH([11:0] formal, bb[i-1])=%0d  errI([1:12] ascending, aa[i])=%0d", errH, errI);
        $finish;
    end
endmodule
