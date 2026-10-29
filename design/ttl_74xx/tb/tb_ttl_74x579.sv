`timescale 1ns/1ps
module tb_ttl_74x579;
    logic clk, ce_n, u_d_n, oe_n, load_n, hiz;
    logic [7:0] d_in, q;
    ttl_74x579 dut(.*);
    task automatic tick; clk=0; #1; clk=1; #1; clk=0; #1; endtask
    int errors;
    initial begin
        errors=0; oe_n=0; load_n=0; ce_n=1; d_in=8'd100; tick;
        load_n=1; ce_n=0; u_d_n=0; tick;
        if (q !== 8'd101) errors++;
        u_d_n=1; tick;
        if (q !== 8'd100) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x579: %0d errors", errors);
        $display("PASS: tb_ttl_74x579");
        $finish;
    end
endmodule
