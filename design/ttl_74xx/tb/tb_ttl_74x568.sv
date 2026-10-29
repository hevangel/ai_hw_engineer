`timescale 1ns/1ps
module tb_ttl_74x568;
    logic clk, ce_n, load_n, clr_n, u_d_n, tcu_n, tcd_n;
    logic [3:0] d, q;
    ttl_74x568 dut(.*);
    task automatic tick; clk=0; #1; clk=1; #1; clk=0; #1; endtask
    int errors;
    initial begin
        errors=0; clk=0; clr_n=1; #1; clr_n=0; #1; clr_n=1;
        u_d_n=0; load_n=0; ce_n=1; d=4'd8; tick;
        load_n=1; ce_n=0; tick; if (q !== 4'd9) errors++;
        tick; if (q !== 4'd0) errors++;
        u_d_n=1; tick; if (q !== 4'd9) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x568: %0d errors", errors);
        $display("PASS: tb_ttl_74x568");
        $finish;
    end
endmodule
