`timescale 1ns/1ps
module tb_ttl_74x458;
    logic [3:0] a, y;
    logic zero_force;
    ttl_74x458 dut(.a(a), .zero_force(zero_force), .y(y));
    int errors;
    initial begin
        errors = 0;
        zero_force=0;
        for (int i = 0; i < 10; i++) begin
            a = i[3:0]; #1;
            if (y !== 4'(9-i)) errors++;
        end
        zero_force=1; #1; if (y !== 0) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x458: %0d errors", errors);
        $display("PASS: tb_ttl_74x458");
        $finish;
    end
endmodule
