`timescale 1ns/1ps
module tb_ttl_74x583;
    logic [3:0] a, b, s;
    logic cin, cout;
    ttl_74x583 dut(.*);
    int errors;
    initial begin
        errors=0;
        a=4'd8; b=4'd9; cin=0; #1; if (s !== 4'd7 || cout !== 1) errors++;
        a=4'd1; b=4'd2; cin=0; #1; if (s !== 4'd3 || cout !== 0) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x583: %0d errors", errors);
        $display("PASS: tb_ttl_74x583");
        $finish;
    end
endmodule
