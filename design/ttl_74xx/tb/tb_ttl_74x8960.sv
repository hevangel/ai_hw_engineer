`timescale 1ns/1ps
module tb_ttl_74x8960;
    logic leab, oeab_n, leba, oeba_n;
    logic [7:0] a_in, b_in, a_out, b_out;
    ttl_74x8960 dut(.*);
    int errors;
    initial begin
        errors = 0;
        leab = 1; oeab_n = 0; leba = 0; oeba_n = 1;
        a_in = 8'h0F; b_in = 0; #1;
        if (b_out !== 8'hF0) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x8960: %0d errors", errors);
        $display("PASS: tb_ttl_74x8960");
        $finish;
    end
endmodule
