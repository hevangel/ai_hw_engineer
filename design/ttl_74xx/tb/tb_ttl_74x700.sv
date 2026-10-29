`timescale 1ns/1ps
module tb_ttl_74x700;
    logic [7:0] a, y;
    logic oe1_n, oe2_n;
    ttl_74x700 dut(.*);
    int errors;
    initial begin
        errors = 0;
        oe1_n = 1; oe2_n = 1; a = 8'hAA; #1;
        if (y !== 8'h00) errors++;
        oe1_n = 0; oe2_n = 0;
        for (int v = 0; v < 256; v++) begin
            a = v[7:0]; #1;
            if (y !== ~v[7:0]) errors++;
        end
        oe1_n = 1; oe2_n = 0; a = 8'hFF; #1;
        if (y[3:0] !== 4'h0 || y[7:4] !== 4'h0) errors++;
        oe1_n = 0; oe2_n = 1; a = 8'hFF; #1;
        if (y[3:0] !== 4'h0 || y[7:4] !== 4'h0) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x700: %0d errors", errors);
        $display("PASS: tb_ttl_74x700");
        $finish;
    end
endmodule
