`timescale 1ns/1ps
module tb_ttl_74x1020;
    logic [3:0] a1, a2;
    logic y1, y2;
    ttl_74x1020 dut(.*);
    int errors;
    initial begin
        errors = 0;
        for (int v = 0; v < 16; v++) begin
            a1 = v[3:0]; a2 = v[3:0]; #1;
            if (y1 !== ~&a1 || y2 !== ~&a2) errors++;
        end
        if (errors != 0) $fatal(1, "tb_ttl_74x1020: %0d errors", errors);
        $display("PASS: tb_ttl_74x1020");
        $finish;
    end
endmodule
