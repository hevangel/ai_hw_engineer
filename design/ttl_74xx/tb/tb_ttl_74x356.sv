`timescale 1ns/1ps
module tb_ttl_74x356;
    logic clk, oe_n;
    logic [2:0] s;
    logic [7:0] d;
    logic y;
    ttl_74x356 dut(.clk(clk), .oe_n(oe_n), .s(s), .d(d), .y(y));
    task automatic tick; clk=0; #1; clk=1; #1; clk=0; #1; endtask
    int errors;
    initial begin
        errors = 0;
        clk=0; oe_n=0; d=8'b10101010; s=3'd1; tick;
        if (y !== 1) errors++;
        d=8'h00; #1;
        if (y !== 1) errors++; // registered hold
        if (errors != 0) $fatal(1, "tb_ttl_74x356: %0d errors", errors);
        $display("PASS: tb_ttl_74x356");
        $finish;
    end
endmodule
