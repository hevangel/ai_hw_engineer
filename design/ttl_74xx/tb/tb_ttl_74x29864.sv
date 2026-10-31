`timescale 1ns/1ps
module tb_ttl_74x29864;
    logic oea_n, oeb_n;
    logic [8:0] a_in, b_in, a_out, b_out;
    logic a_hiz, b_hiz;
    ttl_74x29864 dut(.*);
    int errors;
    initial begin
        errors = 0;
        oea_n = 1; oeb_n = 0; a_in = 9'h0F0; b_in = 0; #1;
        if (b_out !== 9'h10F) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x29864: %0d errors", errors);
        $display("PASS: tb_ttl_74x29864");
        $finish;
    end
endmodule
