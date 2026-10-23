`timescale 1ns/1ps
module tb_ttl_74x337;
    logic [7:0] a, y;
    ttl_74x337 dut(.a(a), .y(y));
    int errors;
    initial begin
        errors = 0;
        for (int i = 0; i < 16; i++) begin a = 8'($random); #1; if (y !== a) errors++; end
        if (errors != 0) $fatal(1, "tb_ttl_74x337: %0d errors", errors);
        $display("PASS: tb_ttl_74x337");
        $finish;
    end
endmodule
