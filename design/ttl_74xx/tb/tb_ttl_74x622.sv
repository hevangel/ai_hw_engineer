`timescale 1ns/1ps
module tb_ttl_74x622;
    logic gab, gba_n;
    logic [7:0] a_in, b_in, a_out, b_out;
    ttl_74x622 dut(.*);
    int errors;
    initial begin
        errors=0;
        gab=1; gba_n=1; a_in=8'h33; b_in=0; #1;
        if (b_out !== 8'hCC) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x622: %0d errors", errors);
        $display("PASS: tb_ttl_74x622");
        $finish;
    end
endmodule
