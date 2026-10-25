`timescale 1ns/1ps
module tb_ttl_74x454;
    logic [1:0] clk, load_n, u_d_n;
    logic [3:0] d0, d1, q0, q1;
    ttl_74x454 dut(.clk(clk), .load_n(load_n), .u_d_n(u_d_n), .d0(d0), .d1(d1), .q0(q0), .q1(q1));
    task automatic t0; clk[0]=0; #1; clk[0]=1; #1; clk[0]=0; #1; endtask
    int errors;
    initial begin
        errors = 0;
        clk=0; load_n=2'b00; u_d_n=0; d0=0; d1=0; t0;
        load_n=2'b11;
        for (int i = 0; i < 10; i++) begin
            if (q0 !== 4'(i % 10)) errors++;
            t0;
        end
        if (errors != 0) $fatal(1, "tb_ttl_74x454: %0d errors", errors);
        $display("PASS: tb_ttl_74x454");
        $finish;
    end
endmodule
