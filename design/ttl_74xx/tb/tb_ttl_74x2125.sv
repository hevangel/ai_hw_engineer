`timescale 1ns/1ps
module tb_ttl_74x2125;
    logic [3:0] a, oe_n, y;
    ttl_74x2125 dut(.*);
    int errors;
    initial begin
        errors = 0;
        oe_n = 4'b0000; a = 4'b1010; #1;
        if (y !== 4'b1010) errors++;
        oe_n = 4'b1111; #1;
        if (y !== 4'b0000) errors++;
        oe_n = 4'b0101; a = 4'b1111; #1;
        if (y !== 4'b1010) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x2125: %0d errors", errors);
        $display("PASS: tb_ttl_74x2125");
        $finish;
    end
endmodule
