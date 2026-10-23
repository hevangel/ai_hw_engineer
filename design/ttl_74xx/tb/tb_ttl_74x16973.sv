`timescale 1ns/1ps
module tb_ttl_74x16973;
    logic oe_n, dir;
    logic [7:0] a_in, b_in, a_out, b_out;
    logic a_hiz, b_hiz;
    logic le, latch_oe_n;
    logic [7:0] l_d, l_q;
    logic l_hiz;
    ttl_74x16973 dut(.*);
    int errors;
    initial begin
        errors = 0;
        oe_n = 0; dir = 1; a_in = 8'h5A; b_in = 0;
        le = 1; latch_oe_n = 0; l_d = 8'hC3;
        #1;
        if (b_out !== 8'h5A) errors++;
        if (l_q !== 8'hC3) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x16973: %0d errors", errors);
        $display("PASS: tb_ttl_74x16973");
        $finish;
    end
endmodule
