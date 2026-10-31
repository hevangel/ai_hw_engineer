`timescale 1ns/1ps
module tb_ttl_74x449;
    logic oe_n, dir;
    logic [3:0] a_in, b_in, a_out, b_out;
    ttl_74x449 dut(.oe_n(oe_n), .dir(dir), .a_in(a_in), .b_in(b_in), .a_out(a_out), .b_out(b_out));
    int errors;
    initial begin
        errors = 0;
        b_in=0;
        oe_n=0; dir=1; a_in=4'h5; #1; if (b_out !== 4'h5) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x449: %0d errors", errors);
        $display("PASS: tb_ttl_74x449");
        $finish;
    end
endmodule
