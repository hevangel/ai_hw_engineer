`timescale 1ns/1ps
// ---------------------------------------------------------------------------
// bisect_count.sv - axis 1: how many preceding calls does it take?
//
// The probe input is fixed: g_n=0, p=0, a=12'b111111111110 (the recorded first
// failing vector, v=4094). Warm-up calls use the real testbench's own sequence
//   {g_n,p,a} = v[16:0]   for v = 0 .. n-1
// so the probe call is always call number n+1 and the vector being evaluated is
// the same one every time. That separates "number of calls" from "which vector".
//
// Exponential search for a failing n, then binary search for the smallest one.
// Cost: ~24 probe evaluations, each <= 131072 calls.
//
// Expected if xezim were correct: "RESULT: no failure up to 131072 calls".
// ---------------------------------------------------------------------------
module bisect_count;

    logic        g_n;
    logic [3:0]  p;
    logic [12:1] a;

    logic        d;
    logic        r;
    int          n;
    int          lo;
    int          hi;
    int          mid;

    localparam logic [12:1] TARGET_A = 12'b111111111110;

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
        // n = 0: no warm-up at all - the known-correct short-run case.
        r = ref_y(1'b0, 4'b0000, TARGET_A);
        $write("probe n=%0d ret=%b ", 0, r);
        if (r === 1'b1) $display("ok"); else $display("WRONG");
        lo = 0;
        hi = -1;
        n  = 1;

        // Exponential search for an upper bound.
        while ((n <= 131072) && (hi < 0)) begin
            for (int v = 0; v < n; v++) begin
                {g_n, p, a} = v[16:0];
                d = ref_y(g_n, p, a);
            end
            r = ref_y(1'b0, 4'b0000, TARGET_A);
            $write("probe n=%0d ret=%b ", n, r);
            if (r === 1'b1) $display("ok"); else $display("WRONG");
            if (r !== 1'b1) hi = n;
            else            lo = n;
            n = n * 2;
        end

        if (hi < 0) begin
            $display("RESULT: no failure up to 131072 calls");
        end else begin
            while ((hi - lo) > 1) begin
                mid = (lo + hi) / 2;
                for (int v = 0; v < mid; v++) begin
                    {g_n, p, a} = v[16:0];
                    d = ref_y(g_n, p, a);
                end
                r = ref_y(1'b0, 4'b0000, TARGET_A);
                $write("probe n=%0d ret=%b ", mid, r);
                if (r === 1'b1) $display("ok"); else $display("WRONG");
                if (r !== 1'b1) hi = mid;
                else            lo = mid;
            end
            $display("RESULT: smallest failing warm-up count = %0d (probe is call #%0d), last good = %0d",
                     hi, hi + 1, lo);
        end
        $finish;
    end
endmodule
