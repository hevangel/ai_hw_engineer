`timescale 1ns/1ps
module tb_ttl_74x384;
    logic signed [7:0] a;
    logic b;
    logic signed [8:0] y;
    ttl_74x384 dut(.a(a), .b(b), .y(y));
    int errors;
    initial begin
        errors = 0;
        a=8'sd50; b=1; #1; if (y !== 9'sd50) errors++;
        a=-8'sd50; b=1; #1; if (y !== -9'sd50) errors++;
        b=0; #1; if (y !== 0) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x384: %0d errors", errors);
        $display("PASS: tb_ttl_74x384");
        $finish;
    end
endmodule
