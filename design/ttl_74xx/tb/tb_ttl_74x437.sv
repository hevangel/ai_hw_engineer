`timescale 1ns/1ps
module tb_ttl_74x437;
    logic [3:0] a, y;
    ttl_74x437 dut(.a(a), .y(y));
    int errors;
    initial begin
        errors = 0;
        a=4'h5; #1; if (y !== 4'h5) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x437: %0d errors", errors);
        $display("PASS: tb_ttl_74x437");
        $finish;
    end
endmodule
