`timescale 1ns/1ps
module tb_ttl_74x607;
    logic sel, le;
    logic [7:0] a, b, y;
    ttl_74x607 dut(.*);
    int errors;
    initial begin
        errors=0; le=1;
        a=8'hAA; b=8'h55; sel=0; #1; if (y !== 8'hAA) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x607: %0d errors", errors);
        $display("PASS: tb_ttl_74x607");
        $finish;
    end
endmodule
