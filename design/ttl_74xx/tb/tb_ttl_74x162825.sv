`timescale 1ns/1ps
module tb_ttl_74x162825;
    logic [17:0] a, y;
    logic oe1_n, oe2_n;
    ttl_74x162825 dut(.*);
    int errors;
    initial begin
        errors = 0;
        oe1_n = 0; oe2_n = 0; a = 18'h2_ABCD; #1;
        if (y !== 18'h2_ABCD) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x162825: %0d errors", errors);
        $display("PASS: tb_ttl_74x162825");
        $finish;
    end
endmodule
