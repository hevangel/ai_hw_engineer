`timescale 1ns/1ps
module tb_ttl_74ls547;
    logic leab, leba, oeab_n, oeba_n, a_hiz, b_hiz;
    logic [7:0] a_in, b_in, a_out, b_out;
    ttl_74ls547 dut(.*);
    int errors;
    initial begin
        errors=0; oeab_n=0; oeba_n=0;
        leab=1; leba=1; a_in=8'h11; b_in=8'h22; #1;
        if (b_out !== 8'h11) errors++;
        if (a_out !== 8'h22) errors++;
        leab=0; a_in=8'hFF; #1;
        if (b_out !== 8'h11) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74ls547: %0d errors", errors);
        $display("PASS: tb_ttl_74ls547");
        $finish;
    end
endmodule
