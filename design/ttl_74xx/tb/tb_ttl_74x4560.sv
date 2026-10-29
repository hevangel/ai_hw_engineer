`timescale 1ns/1ps
module tb_ttl_74x4560;
    logic [3:0] a, b, s;
    logic cin, cout;
    ttl_74x4560 dut(.*);
    int errors;
    initial begin
        errors = 0;
        a = 4'd3; b = 4'd4; cin = 0; #1;
        if (s !== 4'd7 || cout !== 0) errors++;
        a = 4'd5; b = 4'd7; cin = 0; #1;
        if (s !== 4'd2 || cout !== 1) errors++;
        a = 4'd9; b = 4'd9; cin = 1; #1;
        if (s !== 4'd9 || cout !== 1) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x4560: %0d errors", errors);
        $display("PASS: tb_ttl_74x4560");
        $finish;
    end
endmodule
