`timescale 1ns/1ps
// ---------------------------------------------------------------------------
// minimal_fail.sv - minimal self-contained reproducer for the xezim 0.11.3
// automatic-function misbehaviour seen in
// design/ttl_74xx/tb/tb_ttl_74x679.sv.
//
// No DUT and no design files are needed: the expected value comes from an
// inline masked comparison (the form already proven equivalent to the
// documented rule over all 131072 vectors by work/agents/oracle_679_equiv.py),
// so the only thing under test is ref_y().
//
// Run:
//   xezim --simulate -s minimal_fail --error-exit minimal_fail.sv
//
// Expected if xezim were correct: "errors=0" then PASS.
// Recorded xezim 0.11.3 behaviour in the full testbench: 43 mismatches,
// first at v=4094.
// ---------------------------------------------------------------------------
module minimal_fail;

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
        for (int i = 1; i <= 12; i++)
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
        if (errors != 0) $fatal(1, "minimal_fail: %0d mismatches", errors);
        $display("PASS: minimal_fail (131072 vectors)");
        $finish;
    end
endmodule
