`timescale 1ns/1ps
module tb_ttl_74x9595;
    logic clk, lclk, oe_n, clr_n, ser;
    logic [7:0] q;
    logic qs;
    ttl_74x9595 dut(.*);
    int errors;
    task tick; #1; clk = 1; #1; clk = 0; endtask
    task ltick; #1; lclk = 1; #1; lclk = 0; endtask
    initial begin
        errors = 0;
        clk = 0; lclk = 0; oe_n = 0; ser = 1;
        clr_n = 1; #1; clr_n = 0; #1; clr_n = 1; #1;
        for (int i = 0; i < 8; i++) tick;
        ltick;
        if (q !== 8'hFF) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x9595: %0d errors", errors);
        $display("PASS: tb_ttl_74x9595");
        $finish;
    end
endmodule
