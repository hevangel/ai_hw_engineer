`timescale 1ns/1ps
module tb_ttl_74x7597;
    logic clk, le, sh_en_n;
    logic [7:0] d;
    logic q_out;
    ttl_74x7597 dut(.*);
    int errors;
    task tick; #1; clk = 1; #1; clk = 0; endtask
    initial begin
        errors = 0;
        clk = 0; le = 1; sh_en_n = 1; d = 8'h81;
        tick;                 // load latch_q into sr
        sh_en_n = 0;          // start shifting
        if (q_out !== 1) errors++;     // MSB = 1
        for (int i = 0; i < 7; i++) tick;
        // after 7 shifts, sr = 8'b1000_0000 << 7 -> the original LSB at top
        if (errors != 0) $fatal(1, "tb_ttl_74x7597: %0d errors", errors);
        $display("PASS: tb_ttl_74x7597");
        $finish;
    end
endmodule
