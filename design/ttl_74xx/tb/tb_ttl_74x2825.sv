`timescale 1ns/1ps
module tb_ttl_74x2825;
    logic clk, oe_n, clr_n, ce_n;
    logic [7:0] d, q;
    logic hiz;
    ttl_74x2825 dut(.*);
    int errors;
    task tick; #1; clk = 1; #1; clk = 0; endtask
    initial begin
        errors = 0;
        clk = 0; oe_n = 0; ce_n = 0; d = 8'hA5;
        clr_n = 1; #1; clr_n = 0; #1; clr_n = 1; #1;
        if (q !== 8'h00) errors++;
        tick;
        if (q !== 8'hA5) errors++;
        // disable clock enable
        ce_n = 1; d = 8'h5A; tick;
        if (q !== 8'hA5) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x2825: %0d errors", errors);
        $display("PASS: tb_ttl_74x2825");
        $finish;
    end
endmodule
