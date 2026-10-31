`timescale 1ns/1ps
module tb_ttl_74460;
    logic oe_n;
    logic [3:0] a, y;
    ttl_74460 dut(.oe_n(oe_n), .a(a), .y(y));
    int errors;
    initial begin
        errors = 0;
        a=4'hA; oe_n=0; #1; if (y !== 4'hA) errors++;
        oe_n=1; #1; if (y !== 0) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74460: %0d errors", errors);
        $display("PASS: tb_ttl_74460");
        $finish;
    end
endmodule
