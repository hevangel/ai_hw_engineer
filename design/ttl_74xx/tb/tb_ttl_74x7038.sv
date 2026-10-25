`timescale 1ns/1ps
module tb_ttl_74x7038;
    logic leab, oeab_n, leba, oeba_n;
    logic [8:0] a_in, b_in, a_out, b_out;
    logic a_hiz, b_hiz;
    ttl_74x7038 dut(.*);
    int errors;
    initial begin
        errors = 0;
        leab = 1; oeab_n = 0; leba = 0; oeba_n = 1;
        a_in = 9'h1A5; b_in = 0; #1;
        if (b_out !== 9'h1A5) errors++;
        // hold via leab=0
        leab = 0; a_in = 0; #1;
        if (b_out !== 9'h1A5) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x7038: %0d errors", errors);
        $display("PASS: tb_ttl_74x7038");
        $finish;
    end
endmodule
