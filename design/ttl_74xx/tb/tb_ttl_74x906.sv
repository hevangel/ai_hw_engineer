`timescale 1ns/1ps
module tb_ttl_74x906;
    logic [5:0] a, y;
    ttl_74x906 dut(.*);
    int errors;
    initial begin
        errors = 0;
        for (int v = 0; v < 64; v++) begin
            a = v[5:0]; #1;
            if (y !== a) errors++;
        end
        if (errors != 0) $fatal(1, "tb_ttl_74x906: %0d errors", errors);
        $display("PASS: tb_ttl_74x906");
        $finish;
    end
endmodule
