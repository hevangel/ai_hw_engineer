`timescale 1ns/1ps
module tb_ttl_74x16244;
    logic [15:0] a, y;
    logic oe1_n, oe2_n, oe3_n, oe4_n;
    ttl_74x16244 dut(.*);
    int errors;
    initial begin
        errors = 0;
        oe1_n = 0; oe2_n = 0; oe3_n = 0; oe4_n = 0;
        a = 16'hC3A5; #1;
        if (y !== 16'hC3A5) errors++;
        oe1_n = 1; #1;
        if (y[3:0] !== 0 || y[15:4] !== 12'hC3A) errors++;
        oe1_n = 0; oe4_n = 1; #1;
        if (y[15:12] !== 0 || y[11:0] !== 12'h3A5) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x16244: %0d errors", errors);
        $display("PASS: tb_ttl_74x16244");
        $finish;
    end
endmodule
