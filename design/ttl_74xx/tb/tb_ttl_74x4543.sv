`timescale 1ns/1ps
module tb_ttl_74x4543;
    logic le_n, bl, ph;
    logic [3:0] d;
    logic [6:0] seg;
    ttl_74x4543 dut(.*);
    int errors;
    initial begin
        errors = 0;
        le_n = 0; bl = 0; ph = 0; d = 4'd8; #1;
        if (seg !== 7'b1111111) errors++;
        ph = 1; #1;
        if (seg !== 7'b0000000) errors++;
        bl = 1; ph = 0; #1;
        if (seg !== 7'b0) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x4543: %0d errors", errors);
        $display("PASS: tb_ttl_74x4543");
        $finish;
    end
endmodule
