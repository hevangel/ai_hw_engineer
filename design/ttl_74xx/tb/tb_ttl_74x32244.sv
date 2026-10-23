`timescale 1ns/1ps
module tb_ttl_74x32244;
    logic [31:0] a, y;
    logic oe1_n, oe2_n, oe3_n, oe4_n;
    ttl_74x32244 dut(.*);
    int errors;
    initial begin
        errors = 0;
        oe1_n = 0; oe2_n = 0; oe3_n = 0; oe4_n = 0;
        a = 32'hCAFE_F00D; #1;
        if (y !== a) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x32244: %0d errors", errors);
        $display("PASS: tb_ttl_74x32244");
        $finish;
    end
endmodule
