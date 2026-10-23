`timescale 1ns/1ps
module tb_ttl_74x979;
    logic clk, clr_n, dir, oe_n;
    logic [8:0] a_in, b_in, a_out, b_out;
    logic parity_in, parity_out, err_n, hiz;
    ttl_74x979 dut(.*);
    int errors;
    task tick; #1; clk = 1; #1; clk = 0; endtask
    initial begin
        errors = 0;
        clk = 0; dir = 1; oe_n = 0;
        a_in = 9'h0; b_in = 9'h0; parity_in = 0;
        clr_n = 1; #1; clr_n = 0; #1; clr_n = 1; #1;
        if (err_n !== 1) errors++;
        // A->B transmit: data 9'h055 (popcount=4 -> even), parity_out should be 1 (odd parity)
        a_in = 9'h055; dir = 1; tick;
        if (b_out !== 9'h055) errors++;
        if (parity_out !== 1'b1) errors++;
        // B->A receive with correct parity: data 9'h0FF, popcount=8 even, expect odd parity bit=1
        dir = 0; b_in = 9'h0FF; parity_in = 1'b1; tick;
        if (a_out !== 9'h0FF) errors++;
        if (err_n !== 1) errors++;  // no error
        // B->A receive with WRONG parity: should latch error low
        b_in = 9'h001; parity_in = 1'b1; tick;  // popcount=1 odd, expected parity=0, but given 1
        if (err_n !== 0) errors++;
        // clear should reset err
        clr_n = 0; #1; clr_n = 1;
        if (err_n !== 1) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x979: %0d errors", errors);
        $display("PASS: tb_ttl_74x979");
        $finish;
    end
endmodule
