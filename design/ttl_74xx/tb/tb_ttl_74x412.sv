`timescale 1ns/1ps
module tb_ttl_74x412;
    logic md, stb, ds1, ds2_n, int_n;
    logic [7:0] d, q;
    ttl_74x412 dut(.md(md), .stb(stb), .ds1(ds1), .ds2_n(ds2_n), .d(d), .q(q), .int_n(int_n));
    int errors;
    initial begin
        errors = 0;
        md=1; stb=0; ds1=1; ds2_n=0; d=8'hAA; #1;
        if (q !== 8'hAA) errors++;
        md=0; d=8'h55; stb=1; #1;
        if (q !== 8'h55) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x412: %0d errors", errors);
        $display("PASS: tb_ttl_74x412");
        $finish;
    end
endmodule
