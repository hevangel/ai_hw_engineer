`timescale 1ns/1ps
module tb_ttl_74x4514;
    logic le, en_n;
    logic [3:0] d;
    logic [15:0] y;
    ttl_74x4514 dut(.*);
    int errors;
    initial begin
        errors = 0;
        le = 1; en_n = 0; d = 4'd5; #1;
        if (y !== (16'b1 << 5)) errors++;
        en_n = 1; #1;
        if (y !== 16'b0) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x4514: %0d errors", errors);
        $display("PASS: tb_ttl_74x4514");
        $finish;
    end
endmodule
