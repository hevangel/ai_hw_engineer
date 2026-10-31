`timescale 1ns/1ps
module tb_ttl_74x436;
    logic [3:0] a, y;
    ttl_74x436 dut(.a(a), .y(y));
    int errors;
    initial begin
        errors = 0;
        a=4'hA; #1; if (y !== 4'hA) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x436: %0d errors", errors);
        $display("PASS: tb_ttl_74x436");
        $finish;
    end
endmodule
