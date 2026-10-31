`timescale 1ns/1ps
module tb_ttl_74x432;
    logic md, stb, cs_n;
    logic [7:0] d, q;
    ttl_74x432 dut(.md(md), .stb(stb), .cs_n(cs_n), .d(d), .q(q));
    int errors;
    initial begin
        errors = 0;
        md=1; stb=0; cs_n=0; d=8'hAA; #1;
        if (q !== 8'hAA) errors++;
        cs_n=1; #1; if (q !== 0) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x432: %0d errors", errors);
        $display("PASS: tb_ttl_74x432");
        $finish;
    end
endmodule
