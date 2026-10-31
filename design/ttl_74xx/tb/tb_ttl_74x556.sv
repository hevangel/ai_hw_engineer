`timescale 1ns/1ps
module tb_ttl_74x556;
    logic [15:0] a, b;
    logic [31:0] product;
    ttl_74x556 dut(.*);
    int errors;
    initial begin
        errors=0;
        a=16'd1000; b=16'd2000; #1; if (product !== 32'd2000000) errors++;
        a=16'h0; b=16'hFFFF; #1; if (product !== 0) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x556: %0d errors", errors);
        $display("PASS: tb_ttl_74x556");
        $finish;
    end
endmodule
