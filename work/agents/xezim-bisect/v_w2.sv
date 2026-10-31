`timescale 1ns/1ps
// ---------------------------------------------------------------------------
// v_w2.sv - axis 2: does the threshold scale with the inner loop count?
//
// The function keeps its shape but the port is [2:1] and the loop runs 2
// iterations instead of 12. The 7-bit input space {g_n,p,a} = 128 vectors is
// swept 1024 times, so the call count (~131072) matches minimal_fail.sv while
// the number of iterations per call drops from 12 to 2.
//
//   failure appears in pass 0            -> iteration count is irrelevant
//   failure appears late in the sweep    -> the trigger is the number of calls
//   first failing pass * 128 ~= 4095     -> same call threshold as the 12-bit case
//                                           (=> it scales with calls, not iterations)
//   no failure at all                    -> the 12-iteration loop is required
// ---------------------------------------------------------------------------
module v_w2;

    logic        g_n;
    logic [3:0]  p;
    logic [2:1]  a;

    int          errors;
    int          first_pass;
    int          first_v;
    logic        g1;
    logic        g2;
    logic        got;
    logic        gold;

    function automatic logic ref_y(input logic gn, input logic [3:0] pp,
                                   input logic [2:1] aa);
        logic m;
        m = 1'b1;
        for (int i = 1; i <= 2; i++)
            if (i <= int'(pp)) m &= (aa[i] == 1'b0);
            else               m &= (aa[i] == 1'b1);
        return gn ? 1'b1 : ~m;
    endfunction

    initial begin
        errors     = 0;
        first_pass = -1;
        first_v    = -1;
        for (int pass = 0; pass < 1024; pass++) begin
            for (int v = 0; v < 128; v++) begin
                {g_n, p, a} = v[6:0];
                got = ref_y(g_n, p, a);

                if (p >= 1) g1 = (a[1] == 1'b0);
                else        g1 = (a[1] == 1'b1);
                if (p >= 2) g2 = (a[2] == 1'b0);
                else        g2 = (a[2] == 1'b1);
                gold = g_n ? 1'b1 : ~(g1 && g2);

                if (got !== gold) begin
                    if (first_pass < 0) begin
                        first_pass = pass;
                        first_v    = v;
                        $display("first mismatch pass=%0d call=%0d v=%0d g_n=%b p=%0d a=%b -> got %b exp %b",
                                 pass, pass * 128 + v, v, g_n, p, a, got, gold);
                    end
                    if (errors < 10)
                        $display("Mismatch pass=%0d v=%0d p=%0d a=%b -> got %b exp %b",
                                 pass, v, p, a, got, gold);
                    errors++;
                end
            end
        end
        $display("errors=%0d first_pass=%0d first_call=%0d",
                 errors, first_pass, first_pass * 128 + first_v);
        $finish;
    end
endmodule
