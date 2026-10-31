`timescale 1ns/1ps
module tb_ttl_74x162646;
    logic [15:0] a_in, b_in;
    logic [1:0] oe_n, dir, clkab, clkba, sab, sba;
    logic [15:0] a_out, b_out;
    logic [1:0] a_drive, b_drive;
    ttl_74x162646 dut(.*);
    initial begin
        a_in=16'hA55A; b_in=16'hC369; oe_n=2'b00; dir=2'b11;
        clkab=0; clkba=0; sab=0; sba=0; #1;
        if (b_drive !== 2'b11 || b_out !== 16'hA55A || a_drive !== 0) $fatal(1,"A-to-B real-time");
        clkab=2'b01; #1; clkab=0; sab=2'b01; a_in=16'h3C69; #1;
        if (b_out[7:0] !== 8'h5A || b_out[15:8] !== 8'h3C) $fatal(1,"section-one stored, section-two real-time");
        dir=2'b00; sba=0; #1;
        if (a_drive !== 2'b11 || a_out !== 16'hC369 || b_drive !== 0) $fatal(1,"B-to-A real-time");
        clkba=2'b10; #1; clkba=0; sba=2'b10; b_in=16'h96E1; #1;
        if (a_out[15:8] !== 8'hC3 || a_out[7:0] !== 8'hE1) $fatal(1,"independent B-to-A register/select");
        dir=2'b01; sab=0; sba=0; #1;
        if (a_drive !== 2'b10 || b_drive !== 2'b01) $fatal(1,"per-section direction controls");
        oe_n=2'b11; #1;
        if (a_drive !== 0 || b_drive !== 0 || a_out !== 0 || b_out !== 0) $fatal(1,"output isolation");
        $display("PASS: tb_ttl_74x162646");
        $finish;
    end
endmodule
