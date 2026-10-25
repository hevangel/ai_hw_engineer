`timescale 1ns/1ps
module tb_ttl_74x16640;
    logic dir, oe_n;
    logic [15:0] a_in, b_in, a_out, b_out;
    logic a_hiz, b_hiz;
    ttl_74x16640 dut(.*);
    int errors;
    initial begin
        errors = 0;
        oe_n = 0; dir = 1; a_in = 16'h0F0F; b_in = 0; #1;
        if (b_out !== 16'hF0F0) errors++;
        oe_n = 0; dir = 0; b_in = 16'h0F0F; #1;
        if (a_out !== 16'hF0F0) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x16640: %0d errors", errors);
        $display("PASS: tb_ttl_74x16640");
        $finish;
    end
endmodule
