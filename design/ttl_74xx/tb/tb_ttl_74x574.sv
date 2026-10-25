`timescale 1ns/1ps
module tb_ttl_74x574;
    logic clk, oe_n, hiz;
    logic [7:0] d, q;
    ttl_74x574 dut(.*);
    task automatic tick; clk=0; #1; clk=1; #1; clk=0; #1; endtask
    int errors;
    initial begin
        errors=0; oe_n=0; d=8'h81; tick;
        if (q !== 8'h81) errors++;
        d=8'h7E; tick; if (q !== 8'h7E) errors++;
        oe_n=1; #1; if (hiz !== 1) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x574: %0d errors", errors);
        $display("PASS: tb_ttl_74x574");
        $finish;
    end
endmodule
