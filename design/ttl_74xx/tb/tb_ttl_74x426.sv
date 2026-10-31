`timescale 1ns/1ps
module tb_ttl_74x426;
    logic [3:0] a, oe, y;
    ttl_74x426 dut(.a(a), .oe(oe), .y(y));
    int errors;
    initial begin
        errors = 0;
        a=4'h5; oe=4'hF; #1; if (y !== 4'h5) errors++;
        oe=0; #1; if (y !== 0) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x426: %0d errors", errors);
        $display("PASS: tb_ttl_74x426");
        $finish;
    end
endmodule
