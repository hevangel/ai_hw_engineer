`timescale 1ns/1ps
module tb_ttl_74x333;
    logic clk, clr_n;
    logic [11:0] in;
    logic [5:0]  out;
    logic [3:0]  state;
    ttl_74x333 dut(.clk(clk), .clr_n(clr_n), .in(in), .out(out), .state(state));
    task automatic tick; clk=0; #1; clk=1; #1; clk=0; #1; endtask
    int errors;
    initial begin
        errors = 0;
        clk=0; clr_n=0; in=0; #1;
        if (state !== 0) errors++;
        clr_n=1;
        in=12'h5A5; tick;
        if (out !== 0 || state !== 0) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x333: %0d errors", errors);
        $display("PASS: tb_ttl_74x333");
        $finish;
    end
endmodule
