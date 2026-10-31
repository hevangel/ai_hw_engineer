`timescale 1ns/1ps
// =============================================================================
// Standalone conformance harness: the 74x679 expectation FUNCTION ONLY.
//
// No DUT, no delays, no hierarchy. Sweeps all 131072 input vectors and compares
// the testbench's `ref_y` (verbatim copy) against an independent mask-form
// oracle. If `ref_y` is the pure function of its 17 input bits that the source
// says it is, any conforming simulator must report 0 mismatches here.
//
// Build/run commands: work/agents/xezim-conformance/findings.md
// Companion DUT-reproduction top: conformance_679_dut.sv
// =============================================================================
module conf_679_func;
    logic        g_n;
    logic [3:0]  p;
    logic [12:1] a;
    int          errors;

    // --- under test: verbatim copy of tb_ttl_74x679.sv's ref_y ---------------
    function automatic logic ref_y(input logic gn, input logic [3:0] pp,
                                   input logic [12:1] aa);
        logic m;
        m = 1'b1;
        for (int i = 1; i <= 12; i++)
            if (i <= int'(pp)) m &= (aa[i] == 1'b0);
            else               m &= (aa[i] == 1'b1);
        return gn ? 1'b1 : ~m;
    endfunction

    // --- independent oracle: two masked compares -----------------------------
    // aa is declared [12:1], so aa[i] is A_i. low[i] = 1 marks "A_i must be 0"
    // (i.e. i <= P). The documented rule is
    //     match = (A_1..A_k all 0) & (A_(k+1)..A_12 all 1),  k = P
    function automatic logic mask_y(input logic gn, input logic [3:0] pp,
                                    input logic [12:1] aa);
        logic [12:1] low;
        for (int i = 1; i <= 12; i++) low[i] = (i <= int'(pp));
        return gn ? 1'b1
                  : ~( ((aa & low) == 12'h000) && ((aa & ~low) == (~low)) );
    endfunction

    task automatic show(input int v);
        {g_n, p, a} = v[16:0];
        $display("VEC v=%0d gn=%b p=%0d a=%b ref=%b mask=%b",
                 v, g_n, p, a, ref_y(g_n, p, a), mask_y(g_n, p, a));
    endtask

    initial begin
        errors = 0;

        $display("=== disputed vectors: function only, no DUT ===");
        show(4094);
        show(4095);
        show(8188);
        show(8189);
        show(8190);
        show(8191);
        show(12280);
        show(12284);
        show(16368);
        show(45056);
        show(61441);

        $display("=== full sweep: 131072 vectors, ref_y vs mask_y ===");
        for (int v = 0; v < (1 << 17); v++) begin
            {g_n, p, a} = v[16:0];
            if ($isunknown({g_n, p, a}))
                $display("INPUT_X v=%0d", v);
            if (ref_y(g_n, p, a) !== mask_y(g_n, p, a)) begin
                if (errors < 50)
                    $display("FUNC_DIFF v=%0d gn=%b p=%0d a=%b ref=%b mask=%b",
                             v, g_n, p, a, ref_y(g_n, p, a), mask_y(g_n, p, a));
                errors++;
            end
        end

        $display("RESULT vectors=131072 func_vs_mask_mismatches=%0d", errors);
        if (errors != 0) $fatal(1, "conf_679_func: %0d mismatches", errors);
        $display("PASS: conf_679_func");
        $finish;
    end
endmodule
