`timescale 1ns/1ps
module tb_ttl_74x527;
    logic [7:0] p;
    logic [3:0] q, qref;
    logic match;
    ttl_74x527 #(.PATTERN(8'hA5)) dut(.*);
    int errors;
    initial begin
        errors=0;
        p=8'hA5; q=4'h3; qref=4'h3; #1; if (!match) errors++;
        p=8'hA5; q=4'h3; qref=4'h4; #1; if (match) errors++;
        p=8'h00; q=4'h3; qref=4'h3; #1; if (match) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x527: %0d errors", errors);
        $display("PASS: tb_ttl_74x527");
        $finish;
    end
endmodule
