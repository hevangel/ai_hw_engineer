`timescale 1ns/1ps
module tb_ttl_74x990;
    logic le, oerb_n;
    logic [7:0] d_in, d_out, q;
    logic d_oe_n;
    ttl_74x990 dut(.*);
    int errors;
    initial begin
        errors = 0;
        oerb_n = 1; le = 1; d_in = 8'h5A; #1;
        if (q !== 8'h5A) errors++;
        le = 0; d_in = 8'h00; #1;
        if (q !== 8'h5A) errors++;
        oerb_n = 0; #1;
        if (d_out !== 8'h5A || d_oe_n !== 0) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x990: %0d errors", errors);
        $display("PASS: tb_ttl_74x990");
        $finish;
    end
endmodule
