`timescale 1ns/1ps
module tb_ttl_74s416;
    logic cs_n, dir;
    logic [3:0] a_in, b_in, a_out, b_out;
    logic a_oe_n, b_oe_n;
    ttl_74s416 dut(.cs_n(cs_n), .dir(dir), .a_in(a_in), .b_in(b_in), .a_out(a_out), .b_out(b_out), .a_oe_n(a_oe_n), .b_oe_n(b_oe_n));
    int errors;
    initial begin
        errors = 0;
        b_in = 0;
        cs_n=0; dir=1; a_in=4'hA; #1; if (b_out !== 4'hA) errors++;
        cs_n=1; #1; if (b_out !== 0) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74s416: %0d errors", errors);
        $display("PASS: tb_ttl_74s416");
        $finish;
    end
endmodule
