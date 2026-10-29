`timescale 1ns/1ps
module tb_ttl_74x2161;
    logic clk, clr_n, load_n, enp, ent;
    logic [3:0] d, q;
    logic rco;
    ttl_74x2161 dut(.*);
    int errors;
    initial begin
        errors = 0;
        clk = 0; clr_n = 0; load_n = 1; enp = 1; ent = 1; d = 0; #1;
        if (q !== 0) errors++;
        clr_n = 1;
        for (int i = 0; i < 16; i++) begin
            clk = 0; #1; clk = 1; #1;
        end
        if (q !== 0) errors++;  // wrapped through 16
        if (errors != 0) $fatal(1, "tb_ttl_74x2161: %0d errors", errors);
        $display("PASS: tb_ttl_74x2161");
        $finish;
    end
endmodule
