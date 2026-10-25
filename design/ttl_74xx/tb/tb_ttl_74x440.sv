`timescale 1ns/1ps
module tb_ttl_74x440;
    logic oe_n;
    logic [1:0] dir;
    logic [3:0] a_in, b_in, a_out, b_out;
    ttl_74x440 dut(.oe_n(oe_n), .dir(dir), .a_in(a_in), .b_in(b_in), .a_out(a_out), .b_out(b_out));
    int errors;
    initial begin
        errors = 0;
        b_in=0;
        oe_n=0; dir=2'b00; a_in=4'hA; #1; if (b_out !== 4'hA) errors++;
        dir=2'b01; b_in=4'h5; a_in=0; #1; if (a_out !== 4'h5) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x440: %0d errors", errors);
        $display("PASS: tb_ttl_74x440");
        $finish;
    end
endmodule
