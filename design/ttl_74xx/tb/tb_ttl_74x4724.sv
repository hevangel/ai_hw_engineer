`timescale 1ns/1ps
module tb_ttl_74x4724;
    logic clr_n, le_n, d_in;
    logic [2:0] addr;
    logic [7:0] q;
    ttl_74x4724 dut(.*);
    int errors;
    initial begin
        errors = 0;
        clr_n = 1; le_n = 1; d_in = 0; addr = 0; #1;
        clr_n = 0; #1;
        if (q !== 8'b0) errors++;
        clr_n = 1;
        addr = 3'd3; d_in = 1; le_n = 0; #1;
        if (q[3] !== 1) errors++;
        addr = 3'd5; d_in = 1; #1;
        if (q[5] !== 1 || q[3] !== 1) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x4724: %0d errors", errors);
        $display("PASS: tb_ttl_74x4724");
        $finish;
    end
endmodule
