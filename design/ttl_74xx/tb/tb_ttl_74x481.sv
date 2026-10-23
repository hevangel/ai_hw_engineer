`timescale 1ns/1ps
module tb_ttl_74x481;
    logic [3:0] a, b, f;
    logic [2:0] f_sel;
    logic cin, cout;
    ttl_74x481 dut(.a(a), .b(b), .f_sel(f_sel), .cin(cin), .f(f), .cout(cout));
    int errors;
    initial begin
        errors = 0;
        a=4'd3; b=4'd5; cin=0;
        f_sel=3'd0; #1; if (f !== 4'd8) errors++;
        f_sel=3'd2; #1; if (f !== (a & b)) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x481: %0d errors", errors);
        $display("PASS: tb_ttl_74x481");
        $finish;
    end
endmodule
