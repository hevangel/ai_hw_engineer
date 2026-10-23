`timescale 1ns/1ps
module tb_ttl_74x515;
    logic [8:0] addr;
    logic [1:0] sel;
    logic enable_n;
    logic [3:0] y_n;
    ttl_74x515 #(.PATTERN(9'b101010101)) dut(.*);
    int errors;
    initial begin
        errors=0;
        addr=9'b101010101; sel=2'b01; enable_n=0; #1;
        if (y_n !== 4'b1101) errors++;
        addr=9'b000000000; #1;
        if (y_n !== 4'b1111) errors++;
        addr=9'b101010101; enable_n=1; #1;
        if (y_n !== 4'b1111) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x515: %0d errors", errors);
        $display("PASS: tb_ttl_74x515");
        $finish;
    end
endmodule
