`timescale 1ns/1ps
module tb_ttl_74x2853;
    logic le_err, clr_n, oea_n, oeb_n;
    logic [7:0] a_in, b_in, a_out, b_out;
    logic parity_in, parity_out, err_n;
    logic a_oe_n, b_oe_n, parity_oe_n;
    ttl_74x2853 dut(.*);
    int errors;
    initial begin
        errors = 0;
        le_err = 0; oea_n = 1; oeb_n = 0;
        a_in = 8'hC3; b_in = 0; parity_in = 0;
        clr_n = 1; #1; clr_n = 0; #1; clr_n = 1; #1;
        if (b_out !== 8'hC3) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x2853: %0d errors", errors);
        $display("PASS: tb_ttl_74x2853");
        $finish;
    end
endmodule
