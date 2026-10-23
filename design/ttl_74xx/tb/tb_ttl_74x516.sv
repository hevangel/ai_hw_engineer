`timescale 1ns/1ps
module tb_ttl_74x516;
    logic [15:0] a, b;
    logic mul_div_n;
    logic [31:0] result;
    ttl_74x516 dut(.*);
    int errors;
    initial begin
        errors=0;
        a=16'd1234; b=16'd5678; mul_div_n=1; #1;
        if (result !== 32'd7006652) errors++;
        a=16'd50000; b=16'd123; mul_div_n=0; #1;
        if (result !== 32'd406) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x516: %0d errors", errors);
        $display("PASS: tb_ttl_74x516");
        $finish;
    end
endmodule
