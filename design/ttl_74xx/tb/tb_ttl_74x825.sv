`timescale 1ns/1ps
module tb_ttl_74x825;
    logic clk, clr_n, clken_n, oe_n;
    logic [7:0] d, q;
    logic q_oe_n;
    ttl_74x825 dut(.*);
    int errors;
    task automatic tick;
        clk = 0; #1; clk = 1; #1;
    endtask
    initial begin
        errors = 0;
        clk = 0; clr_n = 0; clken_n = 0; oe_n = 0; d = 0;
        #1; if (q !== 0) errors++;
        clr_n = 1; d = 8'hA5; tick();
        if (q !== 8'hA5) errors++;
        clken_n = 1; d = 8'h00; tick();
        if (q !== 8'hA5) errors++;
        clken_n = 0; d = 8'h33; tick();
        if (q !== 8'h33) errors++;
        clr_n = 0; #1; if (q !== 0) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x825: %0d errors", errors);
        $display("PASS: tb_ttl_74x825");
        $finish;
    end
endmodule
