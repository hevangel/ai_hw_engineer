`timescale 1ns/1ps
module tb_ttl_74x310;
    logic [7:0] a, y;
    logic oe_n;
    ttl_74x310 dut(.a(a), .oe_n(oe_n), .y(y));
    int errors;
    initial begin
        errors = 0;
        a=8'hA5; oe_n=0; #1;
        if (y !== ~8'hA5) errors++;
        oe_n=1; #1;
        if (y !== 0) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x310: %0d errors", errors);
        $display("PASS: tb_ttl_74x310");
        $finish;
    end
endmodule
