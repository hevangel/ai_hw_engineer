`timescale 1ns/1ps
module tb_ttl_74x414;
    logic [7:0] r_n;
    logic elr_n;
    logic [2:0] b, a;
    logic enable_out_n;
    ttl_74x414 dut(.r_n(r_n), .elr_n(elr_n), .b(b), .a(a), .enable_out_n(enable_out_n));
    int errors;
    initial begin
        errors = 0;
        r_n=8'b11011111; elr_n=1; b=3'd0; #1;
        if (a !== 3'd5) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x414: %0d errors", errors);
        $display("PASS: tb_ttl_74x414");
        $finish;
    end
endmodule
