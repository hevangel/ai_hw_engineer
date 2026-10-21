`timescale 1ns/1ps
module tb_ttl_74x598;
    logic clk_lat, clk_shift, srclr_n, shift_load_n, sin, qh;
    logic [7:0] d, q;
    ttl_74x598 dut(.*);
    task automatic tl; clk_lat=0; #1; clk_lat=1; #1; clk_lat=0; #1; endtask
    task automatic ts; clk_shift=0; #1; clk_shift=1; #1; clk_shift=0; #1; endtask
    int errors;
    initial begin
        errors=0; clk_lat=0; clk_shift=0; sin=0;
        srclr_n=1; #1; srclr_n=0; #1; srclr_n=1;
        d=8'h81; tl;
        shift_load_n=0; ts;
        if (q !== 8'h81) errors++;
        shift_load_n=1; sin=1; ts;
        if (q !== 8'h03) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x598: %0d errors", errors);
        $display("PASS: tb_ttl_74x598");
        $finish;
    end
endmodule
