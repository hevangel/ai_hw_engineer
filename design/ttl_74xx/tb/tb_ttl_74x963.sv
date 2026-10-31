`timescale 1ns/1ps
module tb_ttl_74x963;
    logic clk, serial_in, serial_out;
    logic [1:0] mode;
    logic [7:0] q_a, q_b;
    ttl_74x963 dut(.*);
    int errors;
    task tick; #1; clk = 1; #1; clk = 0; endtask
    initial begin
        errors = 0;
        clk = 0; mode = 2'b11; serial_in = 0;
        tick;
        if (q_a !== 8'h00 || q_b !== 8'h00) errors++;
        // shift in 8 ones
        mode = 2'b01; serial_in = 1;
        for (int i = 0; i < 8; i++) tick;
        if (q_a !== 8'hFF) errors++;
        // transfer
        mode = 2'b10; tick;
        if (q_b !== 8'hFF) errors++;
        // sync clear
        mode = 2'b11; tick;
        if (q_a !== 8'h00 || q_b !== 8'h00) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x963: %0d errors", errors);
        $display("PASS: tb_ttl_74x963");
        $finish;
    end
endmodule
