`timescale 1ns/1ps
module tb_ttl_74x16646;
    logic [15:0] a_in, b_in;
    logic [1:0] oe_n, dir, clkab, clkba, sab, sba;
    logic [15:0] a_out, b_out;
    logic [1:0] a_drive, b_drive;
    ttl_74x16646 dut(.*);
    initial begin
        a_in=16'hA55A; b_in=16'hC369; oe_n=0; dir=2'b10; clkab=0; clkba=0; sab=0; sba=0; #1;
        if (a_drive !== 2'b01 || b_drive !== 2'b10 || a_out[7:0] !== 8'h69 || b_out[15:8] !== 8'hA5)
            $fatal(1,"independent bank directions");
        clkab=2'b10; clkba=2'b01; #1; clkab=0; clkba=0;
        a_in=16'h3C96; b_in=16'h5AA5; sab=2'b10; sba=2'b01; #1;
        if (b_out[15:8] !== 8'hA5 || a_out[7:0] !== 8'h69) $fatal(1,"stored data selected per direction");
        dir=0; sba=0; #1;
        if (a_drive !== 2'b11 || b_drive !== 0 || a_out !== 16'h5AA5) $fatal(1,"B-to-A real-time mode");
        oe_n=2'b11; #1;
        if (a_drive !== 0 || b_drive !== 0 || a_out !== 0 || b_out !== 0) $fatal(1,"OE isolates both banks");
        $display("PASS: tb_ttl_74x16646");
        $finish;
    end
endmodule
