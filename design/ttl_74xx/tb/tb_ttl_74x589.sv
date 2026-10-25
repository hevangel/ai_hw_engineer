`timescale 1ns/1ps
module tb_ttl_74x589;
    logic clk_lat, le_n, clk_shift, shift_load_n, oe_n, sin, qh, hiz;
    logic [7:0] d;
    ttl_74x589 dut(.*);
    task automatic tlat;  clk_lat=0; #1; clk_lat=1; #1; clk_lat=0; #1; endtask
    task automatic tshift; clk_shift=0; #1; clk_shift=1; #1; clk_shift=0; #1; endtask
    int errors;
    initial begin
        errors=0; clk_lat=0; clk_shift=0; oe_n=0; sin=0;
        le_n=0; d=8'b10101010; tlat;
        shift_load_n=0; tshift; // load into shifter
        // shifter = 10101010 → shifting MSB first
        if (qh !== 1) errors++;
        shift_load_n=1; sin=0; tshift; // {0101010, 0}
        if (qh !== 0) errors++;
        tshift; if (qh !== 1) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x589: %0d errors", errors);
        $display("PASS: tb_ttl_74x589");
        $finish;
    end
endmodule
