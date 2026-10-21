`timescale 1ns/1ps
module tb_ttl_74x594;
    logic clk_shift, srclr_n, clk_lat, rclr_n, sin;
    logic [7:0] q;
    ttl_74x594 dut(.*);
    task automatic ts; clk_shift=0; #1; clk_shift=1; #1; clk_shift=0; #1; endtask
    task automatic tl; clk_lat=0; #1; clk_lat=1; #1; clk_lat=0; #1; endtask
    int errors;
    initial begin
        errors=0; clk_shift=0; clk_lat=0; sin=0;
        srclr_n=1; rclr_n=1; #1; srclr_n=0; rclr_n=0; #1; srclr_n=1; rclr_n=1;
        sin=1; ts; sin=0; ts; sin=1; ts; sin=1; ts;
        sin=0; ts; sin=1; ts; sin=0; ts; sin=1; ts;
        tl;
        if (q !== 8'b10110101) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x594: %0d errors q=%b", errors, q);
        $display("PASS: tb_ttl_74x594");
        $finish;
    end
endmodule
