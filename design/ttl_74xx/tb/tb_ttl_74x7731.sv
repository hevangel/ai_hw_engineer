`timescale 1ns/1ps
module tb_ttl_74x7731;
    logic clk;
    logic [3:0] ser_in, ser_out;
    ttl_74x7731 dut(.*);
    int errors;
    task tick; #1; clk = 1; #1; clk = 0; endtask
    initial begin
        errors = 0;
        clk = 0; ser_in = 4'b0001;
        for (int i = 0; i < 64; i++) tick;
        if (ser_out !== 4'b0001) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x7731: %0d errors", errors);
        $display("PASS: tb_ttl_74x7731");
        $finish;
    end
endmodule
