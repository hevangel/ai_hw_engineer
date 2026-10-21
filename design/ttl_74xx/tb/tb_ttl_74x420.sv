`timescale 1ns/1ps
module tb_ttl_74x420;
    logic [31:0] data;
    logic [6:0] check;
    ttl_74x420 dut(.data(data), .check(check));
    int errors;
    initial begin
        errors = 0;
        data=0; #1; if (check !== 0) errors++;
        data=32'hFFFFFFFF; #1; if (check[5] !== 0) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x420: %0d errors", errors);
        $display("PASS: tb_ttl_74x420");
        $finish;
    end
endmodule
