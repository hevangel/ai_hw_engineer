`timescale 1ns/1ps
module tb_ttl_74x348;
    logic [7:0] i_n;
    logic ei_n, oe_n;
    logic [2:0] y_n;
    logic gs_n, eo_n;
    ttl_74x348 dut(.i_n(i_n), .ei_n(ei_n), .oe_n(oe_n), .y_n(y_n), .gs_n(gs_n), .eo_n(eo_n));
    int errors;
    initial begin
        errors = 0;
        ei_n=0; oe_n=0; i_n=8'b11011111; #1;
        if (y_n !== ~3'd5) errors++;
        oe_n=1; #1;
        if (y_n !== 0) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x348: %0d errors", errors);
        $display("PASS: tb_ttl_74x348");
        $finish;
    end
endmodule
