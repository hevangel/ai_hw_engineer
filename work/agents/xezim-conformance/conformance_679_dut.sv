`timescale 1ns/1ps
// =============================================================================
// Conformance harness: exact reproduction of the testbench construct that
// xezim 0.11.3 reports 43 mismatches on, run against the real RTL.
//
//   {g_n, p, a} = v[16:0];
//   #1;
//   if (y !== ref_y(g_n, p, a)) ...
//
// Requires design/ttl_74xx/src/ttl_74x679.sv on the command line.
// Build/run commands: work/agents/xezim-conformance/findings.md
// Function-only companion top: conformance_679.sv
// =============================================================================
module conf_679_dut;
    logic        g_n;
    logic [3:0]  p;
    logic [12:1] a;
    logic        y;
    int          errors;

    ttl_74x679 dut (.g_n(g_n), .p(p), .a(a), .y(y));

    // Same text as the committed testbench. Referenced a second time in the
    // mismatch branch on purpose: that is what tb_ttl_74x679.sv does, and it is
    // why the log's "exp" value is the second call's result, not necessarily
    // the one the comparison used.
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
        for (int v = 0; v < (1 << 17); v++) begin
            {g_n, p, a} = v[16:0];
            #1;
            if (y !== ref_y(g_n, p, a)) begin
                if (errors < 50)
                    $display("Mismatch v=%0d: g_n=%b p=%b a=%b -> got %b exp %b",
                             v, g_n, p, a, y, ref_y(g_n, p, a));
                errors++;
            end
        end
        if (errors != 0) $fatal(1, "conf_679_dut: %0d mismatches", errors);
        $display("PASS: conf_679_dut (131072 vectors, exhaustive)");
        $finish;
    end
endmodule
