`timescale 1ns/1ps
module tb_ttl_74x4049;
    logic [5:0] a, y;
    ttl_74x4049 dut(.*);
    int errors;
    initial begin
        errors = 0;
        a = 6'b101010; #1;
        if (y !== 6'b010101) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x4049: %0d errors", errors);
        $display("PASS: tb_ttl_74x4049");
        $finish;
    end
endmodule
