`timescale 1ns/1ps
module tb_ttl_74456;
    logic [3:0] a, b, sum;
    logic cin, cout;
    ttl_74456 dut(.a(a), .b(b), .cin(cin), .sum(sum), .cout(cout));
    int errors;
    initial begin
        errors = 0;
        a=4'd5; b=4'd3; cin=0; #1; if (sum !== 4'd8 || cout !== 0) errors++;
        a=4'd8; b=4'd5; cin=0; #1; if (sum !== 4'd3 || cout !== 1) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74456: %0d errors", errors);
        $display("PASS: tb_ttl_74456");
        $finish;
    end
endmodule
