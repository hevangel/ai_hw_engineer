`timescale 1ns/1ps
module tb_ttl_74x826;
    logic clk, clr_n, clken_n, oe_n;
    logic [7:0] d, q;
    logic q_oe_n;
    ttl_74x826 dut(.*);
    int errors;
    task automatic tick;
        clk = 0; #1; clk = 1; #1;
    endtask
    initial begin
        errors = 0;
        clk = 0; clr_n = 0; clken_n = 0; oe_n = 0; d = 0;
        #1; if (q !== 0) errors++;
        clr_n = 1; d = 8'h0F; tick();
        if (q !== 8'hF0) errors++;
        d = 8'h55; tick();
        if (q !== 8'hAA) errors++;
        clr_n = 0; #1; if (q !== 0) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x826: %0d errors", errors);
        $display("PASS: tb_ttl_74x826");
        $finish;
    end
endmodule
