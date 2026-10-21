`timescale 1ns/1ps
module tb_ttl_74x22501;
    logic oe_n, dir;
    logic [7:0] a_in, b_in, a_out, b_out;
    logic a_hiz, b_hiz;
    logic oe1_n, dir1, a1_in, b1_in, a1_out, b1_out;
    logic oe2_n, dir2, a2_in, b2_in, a2_out, b2_out;
    ttl_74x22501 dut(.*);
    int errors;
    initial begin
        errors = 0;
        oe_n = 0; dir = 1; a_in = 8'h5A; b_in = 0;
        oe1_n = 0; dir1 = 1; a1_in = 1; b1_in = 0;
        oe2_n = 0; dir2 = 0; a2_in = 0; b2_in = 1;
        #1;
        if (b_out !== 8'h5A) errors++;
        if (b1_out !== 1) errors++;
        if (a2_out !== 1) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x22501: %0d errors", errors);
        $display("PASS: tb_ttl_74x22501");
        $finish;
    end
endmodule
