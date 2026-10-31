`timescale 1ns/1ps
// Dump every vector where the [12:1]-formal oracle disagrees with the mask oracle.
module probe_679_dump;
    function automatic logic refA(input logic [3:0] pp, input logic [12:1] aa);
        logic m;
        m = 1'b1;
        for (int i = 1; i <= 12; i++)
            if (i <= pp) m &= (aa[i] == 1'b0);
            else         m &= (aa[i] == 1'b1);
        return ~m;
    endfunction

    // same rule, but the select is spelled out with case so no variable index is used
    function automatic logic refS(input logic [3:0] pp, input logic [12:1] aa);
        logic m;
        m = 1'b1;
        for (int i = 1; i <= 12; i++) begin
            logic bitv;
            case (i)
                1: bitv = aa[1];  2: bitv = aa[2];  3: bitv = aa[3];
                4: bitv = aa[4];  5: bitv = aa[5];  6: bitv = aa[6];
                7: bitv = aa[7];  8: bitv = aa[8];  9: bitv = aa[9];
                10: bitv = aa[10]; 11: bitv = aa[11]; 12: bitv = aa[12];
                default: bitv = 1'bx;
            endcase
            if (i <= pp) m &= (bitv == 1'b0);
            else         m &= (bitv == 1'b1);
        end
        return ~m;
    endfunction

    function automatic logic mask_ref(input logic [3:0] pp, input logic [11:0] b);
        logic [11:0] low;
        low = (pp >= 12) ? 12'hFFF : ((12'h001 << pp) - 12'h001);
        return ~(((b & low) == 12'h000) && ((b & ~low) == (12'hFFF & ~low)));
    endfunction

    int n, nS;
    initial begin
        n = 0; nS = 0;
        for (int v = 0; v < (1 << 16); v++) begin
            logic [3:0] pp; logic [12:1] aa; logic truth;
            {pp, aa} = v[15:0];
            truth = mask_ref(pp, aa);
            if (refA(pp, aa) !== truth) begin
                n++;
                if (n <= 50)
                    $display("FAIL pp=%0d aa=%b got=%b truth=%b", pp, aa, refA(pp, aa), truth);
            end
            if (refS(pp, aa) !== truth) nS++;
        end
        $display("refA failures=%0d   refS(case-select, no variable index) failures=%0d", n, nS);
        $finish;
    end
endmodule
