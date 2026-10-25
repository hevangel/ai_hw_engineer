`timescale 1ns/1ps
module tb_ttl_74x962;
    logic clk, serial_in, serial_out;
    logic [1:0] mode;
    logic [7:0] q_a, q_b;
    ttl_74x962 dut(.*);
    int errors;
    task tick; #1; clk = 1; #1; clk = 0; endtask
    initial begin
        errors = 0;
        clk = 0; mode = 2'b00; serial_in = 0;
        // shift in 8'hA5 (MSB first)
        mode = 2'b01;
        serial_in = 1; tick;
        serial_in = 0; tick;
        serial_in = 1; tick;
        serial_in = 0; tick;
        serial_in = 0; tick;
        serial_in = 1; tick;
        serial_in = 0; tick;
        serial_in = 1; tick;
        if (q_a !== 8'hA5) errors++;
        // transfer A -> B
        mode = 2'b10; tick;
        if (q_b !== 8'hA5) errors++;
        // shift again to differentiate A vs B
        mode = 2'b01; serial_in = 0; tick; tick;
        if (q_a == q_b) errors++;
        // exchange
        mode = 2'b11; tick;
        if (q_b !== 8'h94) errors++;  // 8'hA5 shifted left twice
        if (errors != 0) $fatal(1, "tb_ttl_74x962: %0d errors", errors);
        $display("PASS: tb_ttl_74x962");
        $finish;
    end
endmodule
