`timescale 1ns/1ps
module tb_ttl_74x2648;
    logic g_n, dir, sab, sba, cab, cba;
    logic [7:0] a_in, b_in, a_out, b_out;
    logic a_oe_n, b_oe_n;
    ttl_74x2648 dut(.*);
    int errors;
    initial begin
        errors = 0;
        g_n = 0; dir = 1; sab = 0; sba = 0; cab = 0; cba = 0;
        a_in = 8'h0F; b_in = 0; #1;
        if (b_out !== 8'hF0) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x2648: %0d errors", errors);
        $display("PASS: tb_ttl_74x2648");
        $finish;
    end
endmodule
