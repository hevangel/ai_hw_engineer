`timescale 1ns/1ps
module tb_ttl_74x445;
    logic [3:0] bcd;
    logic [9:0] y_n, exp;
    ttl_74x445 dut(.bcd(bcd), .y_n(y_n));
    int errors;
    initial begin
        errors = 0;
        for (int i = 0; i < 16; i++) begin
            bcd = i[3:0]; #1;
            exp = 10'b1111111111;
            if (i < 10) exp[i] = 1'b0;
            if (y_n !== exp) errors++;
        end
        if (errors != 0) $fatal(1, "tb_ttl_74x445: %0d errors", errors);
        $display("PASS: tb_ttl_74x445");
        $finish;
    end
endmodule
