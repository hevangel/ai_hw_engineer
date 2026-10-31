`timescale 1ns/1ps
module tb_ttl_74x350;
    logic [3:0] d, y;
    logic [1:0] shift_amt;
    logic din;
    ttl_74x350 dut(.d(d), .shift_amt(shift_amt), .din(din), .y(y));
    int errors;
    initial begin
        errors = 0;
        d=4'b1100; din=0;
        shift_amt=2'd0; #1; if (y !== 4'b1100) errors++;
        shift_amt=2'd1; #1; if (y !== 4'b0110) errors++;
        shift_amt=2'd2; #1; if (y !== 4'b0011) errors++;
        din=1; shift_amt=2'd2; #1; if (y !== 4'b1111) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x350: %0d errors", errors);
        $display("PASS: tb_ttl_74x350");
        $finish;
    end
endmodule
