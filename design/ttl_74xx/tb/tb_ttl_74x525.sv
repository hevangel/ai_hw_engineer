`timescale 1ns/1ps
module tb_ttl_74x525;
    logic clk, load_n, ce_n, clr_n, tc;
    logic [15:0] d, q;
    ttl_74x525 dut(.*);
    task automatic tick; clk=0; #1; clk=1; #1; clk=0; #1; endtask
    int errors;
    initial begin
        errors=0; clk=0; clr_n=1; #1; clr_n=0; #1; clr_n=1;
        load_n=0; ce_n=1; d=16'hFFFE; tick;
        if (q !== 16'hFFFE) errors++;
        load_n=1; ce_n=0; tick;
        if (q !== 16'hFFFF) errors++;
        if (!tc) errors++;
        tick;
        if (q !== 16'h0000) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x525: %0d errors", errors);
        $display("PASS: tb_ttl_74x525");
        $finish;
    end
endmodule
