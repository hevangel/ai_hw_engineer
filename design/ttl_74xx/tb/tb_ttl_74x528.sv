`timescale 1ns/1ps
module tb_ttl_74x528;
    logic [11:0] p;
    logic match;
    ttl_74x528 #(.PATTERN(12'h123)) dut(.*);
    int errors;
    initial begin
        errors=0;
        p=12'h123; #1; if (!match) errors++;
        p=12'h124; #1; if (match) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x528: %0d errors", errors);
        $display("PASS: tb_ttl_74x528");
        $finish;
    end
endmodule
