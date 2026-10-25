`timescale 1ns/1ps
module tb_ttl_74x996;
    logic clk, oerb_n;
    logic [7:0] d_in, d_out, q;
    logic d_oe_n;
    ttl_74x996 dut(.*);
    int errors;
    initial begin
        errors = 0;
        clk = 0; oerb_n = 1; d_in = 8'h5A; #1; clk = 1; #1;
        if (q !== 8'h5A) errors++;
        d_in = 8'h00; clk = 0; #1; clk = 1; #1;
        if (q !== 8'h00) errors++;
        d_in = 8'hFF; clk = 0; #1; clk = 1; #1;
        oerb_n = 0; #1;
        if (d_out !== 8'hFF) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x996: %0d errors", errors);
        $display("PASS: tb_ttl_74x996");
        $finish;
    end
endmodule
