`timescale 1ns/1ps
module tb_ttl_74x334;
    logic [11:0] in;
    logic [5:0]  out;
    ttl_74x334 dut(.in(in), .out(out));
    int errors;
    initial begin
        errors = 0;
        for (int i = 0; i < 16; i++) begin in = 12'($random); #1; if (out !== 0) errors++; end
        if (errors != 0) $fatal(1, "tb_ttl_74x334: %0d errors", errors);
        $display("PASS: tb_ttl_74x334");
        $finish;
    end
endmodule
