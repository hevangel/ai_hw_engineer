`timescale 1ns/1ps
module tb_ttl_74x2238;
    logic rst_n;
    logic wclk_ab, wr_n_ab, rclk_ab, rd_n_ab;
    logic wclk_ba, wr_n_ba, rclk_ba, rd_n_ba;
    logic [8:0] din_ab, dout_ab, din_ba, dout_ba;
    logic ef_n_ab, ff_n_ab, ef_n_ba, ff_n_ba;
    ttl_74x2238 dut(.*);
    int errors;
    initial begin
        errors = 0;
        wclk_ab = 0; rclk_ab = 0; wr_n_ab = 1; rd_n_ab = 1; din_ab = 0;
        wclk_ba = 0; rclk_ba = 0; wr_n_ba = 1; rd_n_ba = 1; din_ba = 0;
        rst_n = 0; #2; rst_n = 1; #2;
        if (ef_n_ab !== 0) errors++;
        din_ab = 9'h0AB; wr_n_ab = 0;
        #1; wclk_ab = 1; #1; wclk_ab = 0; wr_n_ab = 1; #1;
        if (ef_n_ab !== 1) errors++;
        if (dout_ab !== 9'h0AB) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x2238: %0d errors", errors);
        $display("PASS: tb_ttl_74x2238");
        $finish;
    end
endmodule
