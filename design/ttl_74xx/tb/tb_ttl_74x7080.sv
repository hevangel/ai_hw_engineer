`timescale 1ns/1ps
module tb_ttl_74x7080;
    logic [15:0] d;
    logic parity_in, sum_even, sum_odd;
    ttl_74x7080 dut(.*);
    int errors;
    initial begin
        errors = 0;
        d = 16'h0000; parity_in = 0; #1;
        if (sum_even !== 1 || sum_odd !== 0) errors++;
        d = 16'h0001; #1;
        if (sum_even !== 0 || sum_odd !== 1) errors++;
        d = 16'hFFFF; parity_in = 1; #1;
        if (sum_even !== 0 || sum_odd !== 1) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x7080: %0d errors", errors);
        $display("PASS: tb_ttl_74x7080");
        $finish;
    end
endmodule
