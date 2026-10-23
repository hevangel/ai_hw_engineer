`timescale 1ns/1ps
module tb_ttl_74x2652;
    logic gab, gba_n, sab, sba, cab, cba;
    logic [7:0] a_in, b_in, a_out, b_out;
    ttl_74x2652 dut(.*);
    int errors;
    initial begin
        errors = 0;
        gab = 1; gba_n = 1; sab = 0; sba = 0; cab = 0; cba = 0;
        a_in = 8'hC3; b_in = 0; #1;
        if (b_out !== 8'hC3) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x2652: %0d errors", errors);
        $display("PASS: tb_ttl_74x2652");
        $finish;
    end
endmodule
