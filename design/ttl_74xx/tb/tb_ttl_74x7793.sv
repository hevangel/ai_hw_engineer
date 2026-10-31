`timescale 1ns/1ps
module tb_ttl_74x7793;
    logic le, oe_n;
    logic [7:0] d, q, q_rb;
    logic hiz;
    ttl_74x7793 dut(.*);
    int errors;
    initial begin
        errors = 0;
        le = 1; oe_n = 0; d = 8'h5C; #1;
        if (q !== 8'h5C || q_rb !== 8'h5C) errors++;
        oe_n = 1; #1;
        if (hiz !== 1 || q_rb !== 8'h5C) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x7793: %0d errors", errors);
        $display("PASS: tb_ttl_74x7793");
        $finish;
    end
endmodule
