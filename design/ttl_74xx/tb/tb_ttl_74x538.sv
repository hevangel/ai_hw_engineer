`timescale 1ns/1ps
module tb_ttl_74x538;
    logic [2:0] a;
    logic g1, g2a_n, g2b_n, hiz;
    logic [7:0] y_n;
    ttl_74x538 dut(.*);
    int errors;
    initial begin
        errors=0; g1=1; g2a_n=0; g2b_n=0;
        a=3'd3; #1; if (y_n !== 8'hF7) errors++;
        a=3'd7; #1; if (y_n !== 8'h7F) errors++;
        g1=0; #1; if (hiz !== 1) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x538: %0d errors", errors);
        $display("PASS: tb_ttl_74x538");
        $finish;
    end
endmodule
