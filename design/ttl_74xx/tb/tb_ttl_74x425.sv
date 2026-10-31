`timescale 1ns/1ps
module tb_ttl_74x425;
    logic [3:0] a, oe_n, y;
    ttl_74x425 dut(.a(a), .oe_n(oe_n), .y(y));
    int errors;
    initial begin
        errors = 0;
        a=4'hA; oe_n=4'h0; #1; if (y !== 4'hA) errors++;
        oe_n=4'hF; #1; if (y !== 0) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x425: %0d errors", errors);
        $display("PASS: tb_ttl_74x425");
        $finish;
    end
endmodule
