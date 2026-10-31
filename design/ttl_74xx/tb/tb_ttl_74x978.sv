`timescale 1ns/1ps
module tb_ttl_74x978;
    logic clk, clr_n, oe_n, test_n, scan_in;
    logic [7:0] d, q;
    logic scan_out, hiz;
    ttl_74x978 dut(.*);
    int errors;
    task tick; #1; clk = 1; #1; clk = 0; endtask
    initial begin
        errors = 0;
        clk = 0; oe_n = 0; test_n = 1; scan_in = 0; d = 0;
        clr_n = 1; #1; clr_n = 0; #1; clr_n = 1; #1;
        if (q !== 8'h00) errors++;
        // parallel load
        d = 8'h3C; tick;
        if (q !== 8'h3C) errors++;
        // scan shift: load eight 1s, then check scan_out & q
        test_n = 0; scan_in = 1;
        for (int i = 0; i < 8; i++) tick;
        if (q !== 8'hFF) errors++;
        if (scan_out !== 1'b1) errors++;
        // shift 0s in
        scan_in = 0;
        for (int i = 0; i < 8; i++) tick;
        if (q !== 8'h00) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x978: %0d errors", errors);
        $display("PASS: tb_ttl_74x978");
        $finish;
    end
endmodule
