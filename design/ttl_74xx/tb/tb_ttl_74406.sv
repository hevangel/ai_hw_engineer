`timescale 1ns/1ps
module tb_ttl_74406;
    logic [2:0] a;
    logic en_n;
    logic [7:0] y_n;
    ttl_74406 dut(.a(a), .en_n(en_n), .y_n(y_n));
    int errors;
    initial begin
        errors = 0;
        a=3'd3; en_n=0; #1;
        if (y_n !== 8'hF7) errors++;
        en_n=1; #1;
        if (y_n !== 8'hFF) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74406: %0d errors", errors);
        $display("PASS: tb_ttl_74406");
        $finish;
    end
endmodule
