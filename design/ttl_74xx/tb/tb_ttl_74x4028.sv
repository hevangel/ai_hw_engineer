`timescale 1ns/1ps
module tb_ttl_74x4028;
    logic [3:0] d;
    logic [9:0] q;
    ttl_74x4028 dut(.*);
    int errors;
    initial begin
        errors = 0;
        for (int i = 0; i < 10; i++) begin
            d = i[3:0]; #1;
            if (q !== (10'b1 << i)) errors++;
        end
        d = 4'd11; #1;
        if (q !== 10'b0) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x4028: %0d errors", errors);
        $display("PASS: tb_ttl_74x4028");
        $finish;
    end
endmodule
