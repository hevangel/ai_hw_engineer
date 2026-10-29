`timescale 1ns/1ps
module tb_ttl_74x604;
    logic sel, le, oe_n, hiz;
    logic [7:0] a, b, y;
    ttl_74x604 dut(.*);
    int errors;
    initial begin
        errors=0; oe_n=0; le=1;
        a=8'h11; b=8'h22; sel=0; #1; if (y !== 8'h11) errors++;
        sel=1; #1; if (y !== 8'h22) errors++;
        le=0; a=8'hFF; b=8'hFF; #1; if (y !== 8'h22) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x604: %0d errors", errors);
        $display("PASS: tb_ttl_74x604");
        $finish;
    end
endmodule
