`timescale 1ns/1ps
module tb_ttl_74x16952;
    logic [15:0] a_in, b_in;
    logic [1:0] clkenab_n, clkab, oeab_n, clkenba_n, clkba, oeba_n;
    logic [15:0] a_out, b_out;
    logic [1:0] a_drive, b_drive;
    ttl_74x16952 dut(.*);
    initial begin
        a_in=16'hA55A; b_in=16'hC369; clkenab_n=2'b00; clkab=0; oeab_n=0;
        clkenba_n=2'b00; clkba=0; oeba_n=0; #1;
        clkab=2'b01; #1; clkab=0; #1;
        if (b_drive[0] !== 1'b1 || b_out[7:0] !== 8'h5A) $fatal(1,"enabled rising edge registers A");
        a_in[7:0]=8'h96; clkenab_n[0]=1; clkab[0]=1; #1; clkab[0]=0; #1;
        if (b_out[7:0] !== 8'h5A) $fatal(1,"disabled clock-enable holds register");
        clkba=2'b10; #1; clkba=0; #1;
        if (a_drive[1] !== 1'b1 || a_out[15:8] !== 8'hC3) $fatal(1,"independent B-to-A section register");
        oeba_n[1]=1; #1;
        if (a_drive[1] || a_out[15:8] !== 8'h00 || !a_drive[0]) $fatal(1,"independent output enable");
        $display("PASS: tb_ttl_74x16952");
        $finish;
    end
endmodule
