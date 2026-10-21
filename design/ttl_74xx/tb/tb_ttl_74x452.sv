`timescale 1ns/1ps
module tb_ttl_74x452;
    logic [1:0] clk, clr_n;
    logic [3:0] q0, q1;
    ttl_74x452 dut(.clk(clk), .clr_n(clr_n), .q0(q0), .q1(q1));
    task automatic t0; clk[0]=0; #1; clk[0]=1; #1; clk[0]=0; #1; endtask
    int errors;
    initial begin
        errors = 0;
        clk=0; clr_n=0; #1;
        if (q0 !== 0) errors++;
        clr_n=2'b11;
        for (int i = 0; i < 12; i++) begin
            if (q0 !== 4'(i % 10)) errors++;
            t0;
        end
        if (errors != 0) $fatal(1, "tb_ttl_74x452: %0d errors", errors);
        $display("PASS: tb_ttl_74x452");
        $finish;
    end
endmodule
