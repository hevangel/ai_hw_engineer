`timescale 1ns/1ps
module tb_ttl_74x469;
    logic clk, load_n, u_d_n, ce_n;
    logic [7:0] d, q;
    ttl_74x469 dut(.clk(clk), .load_n(load_n), .u_d_n(u_d_n), .ce_n(ce_n), .d(d), .q(q));
    task automatic tick; clk=0; #1; clk=1; #1; clk=0; #1; endtask
    int errors;
    initial begin
        errors = 0;
        clk=0; load_n=0; u_d_n=0; ce_n=1; d=8'd10; tick;
        if (q !== 8'd10) errors++;
        load_n=1; ce_n=0;
        tick; if (q !== 8'd11) errors++;
        u_d_n=1; tick; if (q !== 8'd10) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x469: %0d errors", errors);
        $display("PASS: tb_ttl_74x469");
        $finish;
    end
endmodule
