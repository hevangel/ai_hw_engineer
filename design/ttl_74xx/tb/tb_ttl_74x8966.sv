`timescale 1ns/1ps
module tb_ttl_74x8966;
    logic leab, oeab_n, leba, oeba_n;
    logic [8:0] a_in, b_in, a_out, b_out;
    logic idle_n;
    ttl_74x8966 dut(.*);
    int errors;
    initial begin
        errors = 0;
        leab = 1; oeab_n = 1; leba = 0; oeba_n = 1;
        a_in = 9'h0AB; b_in = 0; #1;
        if (idle_n !== 0) errors++;
        oeab_n = 0; #1;
        if (idle_n !== 1) errors++;
        if (b_out !== 9'h0AB) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x8966: %0d errors", errors);
        $display("PASS: tb_ttl_74x8966");
        $finish;
    end
endmodule
