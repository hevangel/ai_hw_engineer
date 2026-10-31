`timescale 1ns/1ps
module tb_ttl_74x540;
    logic g1_n, g2_n, hiz;
    logic [7:0] a, y_n;
    ttl_74x540 dut(.*);
    int errors;
    initial begin
        errors=0; g1_n=0; g2_n=0; a=8'h5A; #1;
        if (y_n !== 8'hA5) errors++;
        g1_n=1; #1; if (hiz !== 1) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x540: %0d errors", errors);
        $display("PASS: tb_ttl_74x540");
        $finish;
    end
endmodule
