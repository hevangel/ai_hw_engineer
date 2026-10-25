`timescale 1ns/1ps
module tb_ttl_74x1074;
    logic clk1_n, pre1_n, clr1_n, d1, q1, q1_n;
    logic clk2_n, pre2_n, clr2_n, d2, q2, q2_n;
    ttl_74x1074 dut(.*);
    int errors;
    initial begin
        errors = 0;
        clk1_n = 1; clk2_n = 1; pre1_n = 1; pre2_n = 1; clr1_n = 1; clr2_n = 1;
        d1 = 0; d2 = 0;
        // Async clear pulse.
        clr1_n = 0; clr2_n = 0; #1;
        if (q1 !== 0 || q1_n !== 1) errors++;
        clr1_n = 1; clr2_n = 1;
        // Negative-edge capture: set d, drop clock low.
        d1 = 1; clk1_n = 0; #1;
        if (q1 !== 1) errors++;
        // Hold while clock stays low (no new edge).
        d1 = 0; #1;
        if (q1 !== 1) errors++;
        // Bring clock high (no edge for negedge).
        clk1_n = 1; #1;
        if (q1 !== 1) errors++;
        // New negedge captures new D.
        clk1_n = 0; #1;
        if (q1 !== 0) errors++;
        // Async preset.
        pre1_n = 0; #1;
        if (q1 !== 1) errors++;
        pre1_n = 1;
        // Clear priority over preset.
        clr1_n = 0; pre1_n = 0; #1;
        if (q1 !== 0) errors++;
        clr1_n = 1; pre1_n = 1;

        if (errors != 0) $fatal(1, "tb_ttl_74x1074: %0d errors", errors);
        $display("PASS: tb_ttl_74x1074");
        $finish;
    end
endmodule
