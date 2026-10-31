`timescale 1ns/1ps
module tb_ttl_74x605;
    logic sel, le;
    logic [7:0] a, b, y;
    ttl_74x605 dut(.*);
    int errors;
    initial begin
        errors=0; le=1;
        a=8'h0F; b=8'hF0; sel=0; #1; if (y !== 8'h0F) errors++;
        sel=1; #1; if (y !== 8'hF0) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x605: %0d errors", errors);
        $display("PASS: tb_ttl_74x605");
        $finish;
    end
endmodule
