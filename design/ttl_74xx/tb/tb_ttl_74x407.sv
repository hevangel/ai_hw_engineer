`timescale 1ns/1ps
module tb_ttl_74x407;
    logic le, oe_n;
    logic [7:0] d, q;
    ttl_74x407 dut(.le(le), .oe_n(oe_n), .d(d), .q(q));
    int errors;
    initial begin
        errors = 0;
        le=1; oe_n=0; d=8'h5A; #1;
        if (q !== 8'h5A) errors++;
        oe_n=1; #1; if (q !== 0) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x407: %0d errors", errors);
        $display("PASS: tb_ttl_74x407");
        $finish;
    end
endmodule
