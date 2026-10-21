`timescale 1ns/1ps
module tb_ttl_74x484;
    logic [7:0] bcd;
    logic [5:0] bin;
    ttl_74x484 dut(.bcd(bcd), .bin(bin));
    int errors;
    initial begin
        errors = 0;
        bcd=8'h25; #1; if (bin !== 6'd25) errors++;
        bcd=8'h39; #1; if (bin !== 6'd39) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x484: %0d errors", errors);
        $display("PASS: tb_ttl_74x484");
        $finish;
    end
endmodule
