`timescale 1ns/1ps
module tb_ttl_74x355;
    logic le, oe_n;
    logic [2:0] s;
    logic [7:0] d;
    logic y;
    ttl_74x355 dut(.le(le), .oe_n(oe_n), .s(s), .d(d), .y(y));
    int errors;
    initial begin
        errors = 0;
        le=1; oe_n=0; d=8'b10101010; s=3'd0; #1;
        if (y !== 0) errors++;
        s=3'd1; #1;
        if (y !== 1) errors++;
        oe_n=1; #1; if (y !== 0) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x355: %0d errors", errors);
        $display("PASS: tb_ttl_74x355");
        $finish;
    end
endmodule
