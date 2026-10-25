`timescale 1ns/1ps
module tb_ttl_74x385;
    logic [3:0] a, b, s;
    logic cin, sub_n, cout;
    ttl_74x385 dut(.a(a), .b(b), .cin(cin), .sub_n(sub_n), .s(s), .cout(cout));
    int errors;
    initial begin
        errors = 0;
        sub_n=1; a=4'd5; b=4'd3; cin=0; #1;
        if (s !== 4'd8) errors++;
        sub_n=0; a=4'd5; b=4'd3; cin=0; #1;
        if (s !== 4'd2) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x385: %0d errors", errors);
        $display("PASS: tb_ttl_74x385");
        $finish;
    end
endmodule
