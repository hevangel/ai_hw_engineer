`timescale 1ns/1ps
module tb_ttl_74x3283;
    logic oe_n, dir, leab, leba, clk, clr_n;
    logic [31:0] a_in, b_in, a_out, b_out;
    logic parity_in, parity_out, err_n, hiz;
    ttl_74x3283 dut(.*);
    int errors;
    initial begin
        errors = 0;
        clk = 0; oe_n = 0; dir = 1; leab = 1; leba = 0;
        a_in = 32'hDEAD_BEEF; b_in = 32'h0; parity_in = 0;
        clr_n = 1; #1; clr_n = 0; #1; clr_n = 1; #1;
        if (b_out !== 32'hDEAD_BEEF) errors++;
        // hold via leab=0
        leab = 0; a_in = 32'h0; #1;
        if (b_out !== 32'hDEAD_BEEF) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x3283: %0d errors", errors);
        $display("PASS: tb_ttl_74x3283");
        $finish;
    end
endmodule
