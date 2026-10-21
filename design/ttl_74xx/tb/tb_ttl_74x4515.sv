`timescale 1ns/1ps
module tb_ttl_74x4515;
    logic le, en_n;
    logic [3:0] d;
    logic [15:0] y_n;
    ttl_74x4515 dut(.*);
    int errors;
    initial begin
        errors = 0;
        le = 1; en_n = 0; d = 4'd11; #1;
        if (y_n !== ~(16'b1 << 11)) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x4515: %0d errors", errors);
        $display("PASS: tb_ttl_74x4515");
        $finish;
    end
endmodule
