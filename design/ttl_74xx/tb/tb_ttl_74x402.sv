`timescale 1ns/1ps
module tb_ttl_74x402;
    logic clk, clr_n, din;
    logic [15:0] crc;
    ttl_74x402 dut(.clk(clk), .clr_n(clr_n), .din(din), .crc(crc));
    task automatic tick; clk=0; #1; clk=1; #1; clk=0; #1; endtask
    int errors;
    initial begin
        errors = 0;
        clk=0; clr_n=0; din=0; #1;
        if (crc !== 0) errors++;
        clr_n=1;
        din=1; tick; if (crc !== 16'h8005) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x402: %0d errors", errors);
        $display("PASS: tb_ttl_74x402");
        $finish;
    end
endmodule
