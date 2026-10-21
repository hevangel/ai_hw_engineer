`timescale 1ns/1ps
module tb_ttl_74x306;
    logic oe_n, dir;
    logic [7:0] a_in, b_in, a_out, b_out;
    logic a_oe_n, b_oe_n;
    ttl_74x306 dut(.oe_n(oe_n), .dir(dir), .a_in(a_in), .b_in(b_in), .a_out(a_out), .b_out(b_out), .a_oe_n(a_oe_n), .b_oe_n(b_oe_n));
    int errors;
    initial begin
        errors = 0;
        oe_n=0; dir=1; a_in=8'h5A; b_in=0; #1;
        if (b_out !== 8'h5A) errors++;
        oe_n=1; #1;
        if (b_out !== 0) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x306: %0d errors", errors);
        $display("PASS: tb_ttl_74x306");
        $finish;
    end
endmodule
