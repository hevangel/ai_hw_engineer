`timescale 1ns/1ps
module tb_ttl_74x1640;
    logic dir, oe_n;
    logic [7:0] a_in, b_in, a_out, b_out;
    logic a_hiz, b_hiz;
    ttl_74x1640 dut(.*);
    int errors;
    initial begin
        errors = 0;
        oe_n = 0; dir = 1; a_in = 8'h0F; #1;
        if (b_out !== 8'hF0) errors++;
        if (b_hiz !== 0 || a_hiz !== 1) errors++;
        oe_n = 0; dir = 0; b_in = 8'h0F; #1;
        if (a_out !== 8'hF0) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x1640: %0d errors", errors);
        $display("PASS: tb_ttl_74x1640");
        $finish;
    end
endmodule
