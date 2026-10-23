`timescale 1ns/1ps
module tb_ttl_74x2373;
    logic oe_n, le;
    logic [7:0] d, q;
    ttl_74x2373 dut(.*);
    int errors;
    initial begin
        errors = 0;
        oe_n = 0; le = 1; d = 8'h5A; #1;
        if (q !== 8'h5A) errors++;
        le = 0; d = 0; #1;
        if (q !== 8'h5A) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x2373: %0d errors", errors);
        $display("PASS: tb_ttl_74x2373");
        $finish;
    end
endmodule
