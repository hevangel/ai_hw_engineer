`timescale 1ns/1ps
module tb_ttl_74x4075;
    logic [2:0] a, b, c, y;
    ttl_74x4075 dut(.*);
    int errors;
    initial begin
        errors = 0;
        a = 0; b = 3'b010; c = 3'b001; #1;
        if (y !== 3'b110) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x4075: %0d errors", errors);
        $display("PASS: tb_ttl_74x4075");
        $finish;
    end
endmodule
