`timescale 1ns/1ps
module tb_ttl_74x964;
    logic clk, clr_n, serial_in, serial_out;
    logic [1:0] mode;
    logic [7:0] q_a, q_b;
    ttl_74x964 dut(.*);
    int errors;
    task tick; #1; clk = 1; #1; clk = 0; endtask
    initial begin
        errors = 0;
        clk = 0; mode = 2'b00; serial_in = 0;
        clr_n = 1; #1; clr_n = 0; #1; clr_n = 1; #1;
        if (q_a !== 8'h00 || q_b !== 8'h00) errors++;
        // shift in 1010...
        mode = 2'b01;
        for (int i = 0; i < 8; i++) begin
            serial_in = i[0];
            tick;
        end
        if (q_a !== 8'h55) errors++;
        // async clear
        clr_n = 0; #1;
        if (q_a !== 8'h00) errors++;
        clr_n = 1;
        // sync clear
        mode = 2'b01; serial_in = 1;
        for (int i = 0; i < 4; i++) tick;
        if (q_a !== 8'h0F) errors++;
        mode = 2'b11; tick;
        if (q_a !== 8'h00 || q_b !== 8'h00) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x964: %0d errors", errors);
        $display("PASS: tb_ttl_74x964");
        $finish;
    end
endmodule
