`timescale 1ns/1ps
module tb_ttl_74x8153;
    logic clk, clr_n, ser, ser_out;
    logic [7:0] q;
    ttl_74x8153 dut(.*);
    int errors;
    task tick; #1; clk = 1; #1; clk = 0; endtask
    initial begin
        errors = 0;
        clk = 0; ser = 0;
        clr_n = 1; #1; clr_n = 0; #1; clr_n = 1; #1;
        if (q !== 8'd0) errors++;
        ser = 1; for (int i = 0; i < 8; i++) tick;
        if (q !== 8'hFF) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x8153: %0d errors", errors);
        $display("PASS: tb_ttl_74x8153");
        $finish;
    end
endmodule
