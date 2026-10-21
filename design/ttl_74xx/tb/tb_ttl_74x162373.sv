`timescale 1ns/1ps
module tb_ttl_74x162373;
    logic le, oe_n;
    logic [15:0] d, q;
    ttl_74x162373 dut(.*);
    int errors;
    initial begin
        errors = 0;
        oe_n = 0; le = 1; d = 16'h5A5A; #1;
        if (q !== 16'h5A5A) errors++;
        le = 0; d = 0; #1;
        if (q !== 16'h5A5A) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x162373: %0d errors", errors);
        $display("PASS: tb_ttl_74x162373");
        $finish;
    end
endmodule
