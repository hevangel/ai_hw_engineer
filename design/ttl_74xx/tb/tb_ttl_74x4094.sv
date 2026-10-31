`timescale 1ns/1ps
module tb_ttl_74x4094;
    logic clk, stb, oe, ser;
    logic [7:0] q;
    logic qs1, qs2;
    ttl_74x4094 dut(.*);
    int errors;
    task tick; #1; clk = 1; #1; clk = 0; endtask
    initial begin
        errors = 0;
        clk = 0; stb = 1; oe = 1; ser = 1;
        for (int i = 0; i < 8; i++) tick;
        if (q !== 8'hFF) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x4094: %0d errors", errors);
        $display("PASS: tb_ttl_74x4094");
        $finish;
    end
endmodule
