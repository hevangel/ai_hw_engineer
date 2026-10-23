`timescale 1ns/1ps
module tb_ttl_74x582;
    logic [3:0] a, b, s;
    logic cin, sub_n, cout;
    ttl_74x582 dut(.*);
    int errors;
    initial begin
        errors=0;
        // 7 + 5 = 12 (BCD: cout=1, s=2)
        a=4'd7; b=4'd5; cin=0; sub_n=1; #1;
        if (s !== 4'd2 || cout !== 1) errors++;
        // 3 + 4 = 7 (no carry)
        a=4'd3; b=4'd4; cin=0; sub_n=1; #1;
        if (s !== 4'd7 || cout !== 0) errors++;
        // 9 - 4 = 5 (sub_n=0; carry-in must be 1 for normal subtract)
        a=4'd9; b=4'd4; cin=1; sub_n=0; #1;
        if (s !== 4'd5 || cout !== 1) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x582: %0d errors", errors);
        $display("PASS: tb_ttl_74x582");
        $finish;
    end
endmodule
