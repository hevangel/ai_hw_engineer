`timescale 1ns/1ps
module tb_ttl_74x748;
    logic [7:0] i_n;
    logic ei_n;
    logic [2:0] y_n;
    logic gs_n, eo_n;
    ttl_74x748 dut(.*);
    int errors;
    initial begin
        errors = 0;
        // Disabled: outputs all high, eo_n high.
        ei_n = 1; i_n = 8'h00; #1;
        if (y_n !== 3'b111 || gs_n !== 1 || eo_n !== 1) errors++;

        // Enabled, no inputs active.
        ei_n = 0; i_n = 8'hFF; #1;
        if (y_n !== 3'b111 || gs_n !== 1 || eo_n !== 0) errors++;

        // Highest priority is bit 7 (lowest binary index → highest priority because lower asserted).
        for (int b = 0; b < 8; b++) begin
            i_n = 8'hFF & ~(8'b1 << b); #1;
            // i_n bit b is low (active), others high. Encoded code = b. y_n = ~b.
            if (y_n !== ~b[2:0] || gs_n !== 0 || eo_n !== 1) begin
                errors++; $display("single bit %0d: y_n=%b gs=%b eo=%b", b, y_n, gs_n, eo_n);
            end
        end

        // Multiple inputs: priority is the highest-numbered asserted bit.
        // (Active-low: a bit is "active" when it reads 0.)
        i_n = 8'b00000000; #1;  // all bits active → top active is 7
        if (y_n !== 3'b000 || gs_n !== 0) errors++;  // ~7 = 000
        i_n = 8'b10111111; #1;  // bits 0..6 active (0), bit 7 inactive (1) → top is 6
        if (y_n !== ~3'd6 || gs_n !== 0) errors++;

        if (errors != 0) $fatal(1, "tb_ttl_74x748: %0d errors", errors);
        $display("PASS: tb_ttl_74x748");
        $finish;
    end
endmodule
