`timescale 1ns/1ps
module tb_ttl_74x559;
    logic signed [7:0] a, b;
    logic mul_div_n;
    logic signed [15:0] result;
    ttl_74x559 dut(.*);
    int errors;
    initial begin
        errors=0;
        a=-8'sd10; b=8'sd3; mul_div_n=1; #1;
        if (result !== -16'sd30) errors++;
        a=8'sd100; b=8'sd4; mul_div_n=0; #1;
        if (result !== 16'sd25) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x559: %0d errors", errors);
        $display("PASS: tb_ttl_74x559");
        $finish;
    end
endmodule
