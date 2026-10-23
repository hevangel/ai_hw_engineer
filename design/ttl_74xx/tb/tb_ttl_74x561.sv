`timescale 1ns/1ps
module tb_ttl_74x561;
    logic clk, ce_n, load_n, clr_n, tc;
    logic [3:0] d, q;
    ttl_74x561 dut(.*);
    task automatic tick; clk=0; #1; clk=1; #1; clk=0; #1; endtask
    int errors;
    initial begin
        errors=0; clk=0; clr_n=1; #1; clr_n=0; #1; clr_n=1;
        load_n=0; ce_n=1; d=4'd14; tick;
        load_n=1; ce_n=0; tick; if (q !== 4'd15) errors++;
        if (!tc) errors++;
        tick; if (q !== 4'd0) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x561: %0d errors", errors);
        $display("PASS: tb_ttl_74x561");
        $finish;
    end
endmodule
