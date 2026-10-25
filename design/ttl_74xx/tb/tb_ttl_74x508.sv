`timescale 1ns/1ps
module tb_ttl_74x508;
    logic [7:0] a, b;
    logic mul_div_n;
    logic [15:0] result;
    ttl_74x508 dut(.*);
    int errors;
    initial begin
        errors=0;
        a=13; b=17; mul_div_n=1; #1; if (result !== 16'd221) errors++;
        a=200; b=7; mul_div_n=0; #1; if (result !== 16'd28) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x508: %0d errors", errors);
        $display("PASS: tb_ttl_74x508");
        $finish;
    end
endmodule
