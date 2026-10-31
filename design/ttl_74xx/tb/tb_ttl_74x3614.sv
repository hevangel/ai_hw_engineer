`timescale 1ns/1ps
module tb_ttl_74x3614;
    logic rst_n;
    logic wclk_ab, wr_n_ab, rclk_ab, rd_n_ab;
    logic wclk_ba, wr_n_ba, rclk_ba, rd_n_ba;
    logic [35:0] din_ab, dout_ab, din_ba, dout_ba;
    logic ef_n_ab, ff_n_ab, ef_n_ba, ff_n_ba;
    ttl_74x3614 dut(.*);
    int errors;
    initial begin
        errors = 0;
        wclk_ab = 0; rclk_ab = 0; wr_n_ab = 1; rd_n_ab = 1; din_ab = 0;
        wclk_ba = 0; rclk_ba = 0; wr_n_ba = 1; rd_n_ba = 1; din_ba = 0;
        rst_n = 1; #1; rst_n = 0; #1; rst_n = 1; #1;
        if (ef_n_ab !== 0) errors++;
        din_ab = 36'd17; wr_n_ab = 0;
        #1; wclk_ab = 1; #1; wclk_ab = 0; wr_n_ab = 1; #1;
        if (dout_ab !== 36'd17) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x3614: %0d errors", errors);
        $display("PASS: tb_ttl_74x3614");
        $finish;
    end
endmodule
