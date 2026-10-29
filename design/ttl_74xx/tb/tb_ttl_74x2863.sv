`timescale 1ns/1ps
module tb_ttl_74x2863;
    logic oea_n, oeb_n;
    logic [8:0] a_in, b_in, a_out, b_out;
    logic a_hiz, b_hiz;
    ttl_74x2863 dut(.*);
    int errors;
    initial begin
        errors = 0;
        oea_n = 1; oeb_n = 0; a_in = 9'h1A5; b_in = 9'h0; #1;
        if (b_out !== 9'h1A5) errors++;
        if (a_hiz !== 1) errors++;
        oea_n = 0; oeb_n = 1; b_in = 9'h05A; #1;
        if (a_out !== 9'h05A) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x2863: %0d errors", errors);
        $display("PASS: tb_ttl_74x2863");
        $finish;
    end
endmodule
