`timescale 1ns/1ps
module tb_ttl_74x537;
    logic [3:0] a;
    logic oe_n, hiz;
    logic [9:0] y_n;
    ttl_74x537 dut(.*);
    int errors;
    initial begin
        errors=0; oe_n=0;
        a=4'd0; #1; if (y_n !== 10'b11_1111_1110) errors++;
        a=4'd5; #1; if (y_n[5] !== 0) errors++;
        a=4'd9; #1; if (y_n[9] !== 0) errors++;
        a=4'd12; #1; if (y_n !== 10'b11_1111_1111) errors++;
        oe_n=1; #1; if (hiz !== 1) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x537: %0d errors", errors);
        $display("PASS: tb_ttl_74x537");
        $finish;
    end
endmodule
