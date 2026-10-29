`timescale 1ns/1ps
module tb_ttl_74x1803;
    logic [3:0] a, y;
    ttl_74x1803 dut(.*);
    int errors;
    initial begin
        errors = 0;
        for (int v = 0; v < 16; v++) begin
            a = v[3:0]; #1;
            if (y !== a) errors++;
        end
        if (errors != 0) $fatal(1, "tb_ttl_74x1803: %0d errors", errors);
        $display("PASS: tb_ttl_74x1803");
        $finish;
    end
endmodule
