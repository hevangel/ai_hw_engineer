`timescale 1ns/1ps
module tb_ttl_74x2191;
    logic clk, load_n, ctr_en_n, d_u_n;
    logic [3:0] d, q;
    logic max_min, rco_n;
    ttl_74x2191 dut(.*);
    int errors;
    initial begin
        errors = 0;
        clk = 0; load_n = 1; ctr_en_n = 0; d_u_n = 0; d = 4'd5; #1;
        // Async load via negedge.
        load_n = 0; #1;
        if (q !== 4'd5) errors++;
        load_n = 1; #1;
        clk = 1; #1;
        if (q !== 4'd6) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x2191: %0d errors", errors);
        $display("PASS: tb_ttl_74x2191");
        $finish;
    end
endmodule
