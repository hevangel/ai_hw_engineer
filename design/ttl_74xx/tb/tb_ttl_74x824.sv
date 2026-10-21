`timescale 1ns/1ps
module tb_ttl_74x824;
    logic clk, clr_n, clken_n, oe_n;
    logic [8:0] d, q;
    logic q_oe_n;
    ttl_74x824 dut(.*);
    int errors;
    task automatic tick;
        clk = 0; #1; clk = 1; #1;
    endtask
    initial begin
        errors = 0;
        clk = 0; clr_n = 0; clken_n = 0; oe_n = 0; d = 0;
        #1;
        if (q !== 0) errors++;
        clr_n = 1; d = 9'h1A5; tick();
        if (q !== 9'b0_0101_1010) errors++;  // ~1A5 in 9 bits
        d = 9'h0AA; tick();
        if (q !== ~9'h0AA) errors++;
        clr_n = 0; #1; if (q !== 0) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x824: %0d errors", errors);
        $display("PASS: tb_ttl_74x824");
        $finish;
    end
endmodule
