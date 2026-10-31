`timescale 1ns/1ps
module tb_ttl_74x8965;
    logic leab, sab, oeab_n, leba, sba, oeba_n;
    logic [8:0] a_in, b_in, a_out, b_out;
    ttl_74x8965 dut(.*);
    int errors;
    initial begin
        errors = 0;
        leab = 1; sab = 0; oeab_n = 0;
        leba = 0; sba = 0; oeba_n = 1;
        a_in = 9'h0AA; b_in = 0; #1;
        if (b_out !== 9'h0AA) errors++;
        // freeze ab_q and switch to stored value
        leab = 0; sab = 1; a_in = 9'h000; #1;
        if (b_out !== 9'h0AA) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x8965: %0d errors", errors);
        $display("PASS: tb_ttl_74x8965");
        $finish;
    end
endmodule
