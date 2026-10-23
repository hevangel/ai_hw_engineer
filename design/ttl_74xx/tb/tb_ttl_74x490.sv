`timescale 1ns/1ps
module tb_ttl_74x490;
    logic [1:0] clk, clr;
    logic [3:0] q0, q1;
    ttl_74x490 dut(.clk(clk), .clr(clr), .q0(q0), .q1(q1));
    task automatic t0; clk[0]=0; #1; clk[0]=1; #1; clk[0]=0; #1; endtask
    int errors;
    initial begin
        errors = 0;
        clk=0; clr=2'b11; #1; clr=0;
        for (int i = 0; i < 12; i++) begin
            if (q0 !== 4'(i % 10)) errors++;
            t0;
        end
        if (errors != 0) $fatal(1, "tb_ttl_74x490: %0d errors", errors);
        $display("PASS: tb_ttl_74x490");
        $finish;
    end
endmodule
