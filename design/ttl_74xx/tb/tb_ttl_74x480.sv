`timescale 1ns/1ps
module tb_ttl_74x480;
    logic clk, clr_n, din, err;
    logic [15:0] reg_state;
    ttl_74x480 dut(.clk(clk), .clr_n(clr_n), .din(din), .reg_state(reg_state), .err(err));
    task automatic tick; clk=0; #1; clk=1; #1; clk=0; #1; endtask
    int errors;
    initial begin
        errors = 0;
        clk=0; clr_n=0; din=0; #1;
        if (reg_state !== 0) errors++;
        clr_n=1;
        din=1; tick;
        if (reg_state === 0) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x480: %0d errors", errors);
        $display("PASS: tb_ttl_74x480");
        $finish;
    end
endmodule
