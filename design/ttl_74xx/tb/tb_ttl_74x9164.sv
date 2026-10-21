`timescale 1ns/1ps
module tb_ttl_74x9164;
    logic clk, clr_n, sin;
    logic [1:0] mode;
    logic [7:0] d, q;
    logic sout_r, sout_l;
    ttl_74x9164 dut(.*);
    int errors;
    task tick; #1; clk = 1; #1; clk = 0; endtask
    initial begin
        errors = 0;
        clk = 0; mode = 2'b00; sin = 0; d = 0;
        clr_n = 1; #1; clr_n = 0; #1; clr_n = 1; #1;
        // parallel load 8'h81
        mode = 2'b11; d = 8'h81; tick;
        if (q !== 8'h81) errors++;
        // shift right
        mode = 2'b01; sin = 0; tick;
        if (q !== 8'h40) errors++;
        // shift left
        mode = 2'b10; sin = 1; tick;
        if (q !== 8'h81) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x9164: %0d errors", errors);
        $display("PASS: tb_ttl_74x9164");
        $finish;
    end
endmodule
