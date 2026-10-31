`timescale 1ns/1ps
module tb_ttl_74x16863;
    logic oe_n, dir;
    logic [17:0] a_in, b_in, a_out, b_out;
    logic a_oe_n, b_oe_n;
    ttl_74x16863 dut(.*);
    int errors;
    initial begin
        errors = 0;
        oe_n = 0; dir = 1; a_in = 18'h2_ABCD; b_in = 0; #1;
        if (b_out !== 18'h2_ABCD) errors++;
        oe_n = 0; dir = 0; b_in = 18'h1_5A5A; #1;
        if (a_out !== 18'h1_5A5A) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x16863: %0d errors", errors);
        $display("PASS: tb_ttl_74x16863");
        $finish;
    end
endmodule
