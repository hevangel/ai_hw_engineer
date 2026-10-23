`timescale 1ns/1ps
module tb_ttl_74x550;
    logic clkab, clkba, oeab_n, oeba_n, ab_zero, ba_zero, a_hiz, b_hiz;
    logic [7:0] a_in, b_in, a_out, b_out;
    ttl_74x550 dut(.*);
    task automatic tab; clkab=0; #1; clkab=1; #1; clkab=0; #1; endtask
    task automatic tba; clkba=0; #1; clkba=1; #1; clkba=0; #1; endtask
    int errors;
    initial begin
        errors=0; clkab=0; clkba=0; oeab_n=0; oeba_n=0;
        a_in=8'h00; b_in=8'h01; tab; tba;
        if (b_out !== 8'h00) errors++;
        if (!ab_zero) errors++;
        if (ba_zero) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x550: %0d errors", errors);
        $display("PASS: tb_ttl_74x550");
        $finish;
    end
endmodule
