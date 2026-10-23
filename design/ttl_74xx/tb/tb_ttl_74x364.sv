`timescale 1ns/1ps
module tb_ttl_74x364;
    logic clk, oe_n;
    logic [7:0] d, q;
    ttl_74x364 dut(.clk(clk), .oe_n(oe_n), .d(d), .q(q));
    task automatic tick; clk=0; #1; clk=1; #1; clk=0; #1; endtask
    int errors;
    initial begin
        errors = 0;
        clk=0; oe_n=0; d=8'hAB; tick;
        if (q !== 8'hAB) errors++;
        oe_n=1; #1; if (q !== 0) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x364: %0d errors", errors);
        $display("PASS: tb_ttl_74x364");
        $finish;
    end
endmodule
