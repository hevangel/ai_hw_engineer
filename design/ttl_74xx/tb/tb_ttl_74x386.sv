`timescale 1ns/1ps
module tb_ttl_74x386;
    logic [3:0] a, b, y;
    ttl_74x386 dut(.a(a), .b(b), .y(y));
    int errors;
    initial begin
        errors = 0;
        for (int i = 0; i < 256; i++) begin
            a = i[3:0]; b = i[7:4]; #1;
            if (y !== (a ^ b)) errors++;
        end
        if (errors != 0) $fatal(1, "tb_ttl_74x386: %0d errors", errors);
        $display("PASS: tb_ttl_74x386");
        $finish;
    end
endmodule
