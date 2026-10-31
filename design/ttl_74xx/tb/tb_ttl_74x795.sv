`timescale 1ns/1ps
module tb_ttl_74x795;
    logic [7:0] a, y;
    logic oe_n;
    ttl_74x795 dut(.*);
    int errors;
    initial begin
        errors = 0;
        oe_n = 1; a = 8'hFF; #1;
        if (y !== 0) errors++;
        oe_n = 0;
        for (int v = 0; v < 256; v++) begin
            a = v[7:0]; #1;
            if (y !== v[7:0]) errors++;
        end
        if (errors != 0) $fatal(1, "tb_ttl_74x795: %0d errors", errors);
        $display("PASS: tb_ttl_74x795");
        $finish;
    end
endmodule
