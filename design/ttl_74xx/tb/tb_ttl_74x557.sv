`timescale 1ns/1ps
module tb_ttl_74x557;
    logic [7:0] a, b;
    logic [15:0] product;
    ttl_74x557 dut(.*);
    int errors;
    initial begin
        errors=0;
        a=8'd15; b=8'd17; #1; if (product !== 16'd255) errors++;
        a=8'hFF; b=8'hFF; #1; if (product !== 16'hFE01) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x557: %0d errors", errors);
        $display("PASS: tb_ttl_74x557");
        $finish;
    end
endmodule
