`timescale 1ns/1ps
module tb_ttl_74x933;
    logic [6:0] expected, address;
    logic match;
    ttl_74x933 dut(.*);
    int errors;
    initial begin
        errors = 0;
        for (int e = 0; e < 128; e += 13) begin
            for (int a = 0; a < 128; a += 11) begin
                expected = e[6:0]; address = a[6:0]; #1;
                if (match !== (expected == address)) errors++;
            end
        end
        if (errors != 0) $fatal(1, "tb_ttl_74x933: %0d errors", errors);
        $display("PASS: tb_ttl_74x933");
        $finish;
    end
endmodule
