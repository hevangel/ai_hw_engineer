`timescale 1ns/1ps
module tb_ttl_74x40104;
    logic clk, clr_n, sin;
    logic [1:0] mode;
    logic [3:0] d, q;
    ttl_74x40104 dut(.*);
    int errors;
    task tick; #1; clk = 1; #1; clk = 0; endtask
    initial begin
        errors = 0;
        clk = 0; mode = 2'b00; sin = 0; d = 0;
        clr_n = 1; #1; clr_n = 0; #1; clr_n = 1; #1;
        mode = 2'b11; d = 4'h9; tick;
        if (q !== 4'h9) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x40104: %0d errors", errors);
        $display("PASS: tb_ttl_74x40104");
        $finish;
    end
endmodule
