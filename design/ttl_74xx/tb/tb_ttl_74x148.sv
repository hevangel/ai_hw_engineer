// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv.
`timescale 1ns/1ps
module tb_ttl_74x148;
    logic [7:0] i_n;
    logic ei_n;
    logic [2:0] y_n;
    logic gs_n, eo_n;
    ttl_74x148 dut(.i_n(i_n), .ei_n(ei_n), .y_n(y_n), .gs_n(gs_n), .eo_n(eo_n));
    int errors;
    initial begin
        errors = 0;
        // Disabled
        ei_n = 1; i_n = 8'h00; #1;
        if (y_n !== 3'b111 || gs_n !== 1 || eo_n !== 1) errors++;
        // Enabled, no inputs
        ei_n = 0; i_n = 8'hFF; #1;
        if (y_n !== 3'b111 || gs_n !== 1 || eo_n !== 0) errors++;
        // Enabled, input 5 active
        ei_n = 0; i_n = 8'b11011111; #1;
        if (y_n !== ~3'd5 || gs_n !== 0 || eo_n !== 1) errors++;
        // Enabled, input 7 active -> wins
        ei_n = 0; i_n = 8'b01011111; #1;
        if (y_n !== ~3'd7 || gs_n !== 0 || eo_n !== 1) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x148: %0d errors", errors);
        $display("PASS: tb_ttl_74x148");
        $finish;
    end
endmodule
