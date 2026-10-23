`timescale 1ns/1ps
module tb_ttl_74x485;
    logic [5:0] bin;
    logic [7:0] bcd;
    ttl_74x485 dut(.bin(bin), .bcd(bcd));
    int errors;
    initial begin
        errors = 0;
        bin=6'd25; #1; if (bcd !== 8'h25) errors++;
        bin=6'd63; #1; if (bcd !== 8'h63) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x485: %0d errors", errors);
        $display("PASS: tb_ttl_74x485");
        $finish;
    end
endmodule
