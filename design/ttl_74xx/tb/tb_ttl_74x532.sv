`timescale 1ns/1ps
module tb_ttl_74x532;
    logic clk, oe_n, hiz;
    logic [7:0] d, q;
    ttl_74x532 dut(.*);
    task automatic tick; clk=0; #1; clk=1; #1; clk=0; #1; endtask
    int errors;
    initial begin
        errors=0; oe_n=0; d=8'hA5; tick;
        if (q !== 8'hA5) errors++;
        oe_n=1; #1; if (hiz !== 1) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x532: %0d errors", errors);
        $display("PASS: tb_ttl_74x532");
        $finish;
    end
endmodule
