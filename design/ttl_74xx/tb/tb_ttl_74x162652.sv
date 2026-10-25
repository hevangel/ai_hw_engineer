`timescale 1ns/1ps
module tb_ttl_74x162652;
    logic [15:0] a_in, b_in;
    logic [1:0] oeab, oeba_n, clkab, clkba, sab, sba;
    logic [15:0] a_out, b_out;
    logic [1:0] a_drive, b_drive;
    ttl_74x162652 dut(.*);
    initial begin
        a_in=16'hA55A; b_in=16'hC369; oeab=2'b11; oeba_n=2'b00;
        clkab=0; clkba=0; sab=0; sba=0; #1;
        if (b_out !== 16'hA55A || a_out !== 16'hC369 || b_drive !== 2'b11 || a_drive !== 2'b11)
            $fatal(1,"independent simultaneous real-time paths");
        clkab=2'b01; clkba=2'b10; #1; clkab=0; clkba=0;
        sab=2'b01; sba=2'b10; a_in=16'h3C69; b_in=16'h96E1; #1;
        if (b_out[7:0] !== 8'h5A || b_out[15:8] !== 8'h3C ||
            a_out[15:8] !== 8'hC3 || a_out[7:0] !== 8'hE1)
            $fatal(1,"independent section selects and stored registers");
        oeab=0; oeba_n=2'b11; #1;
        if (a_drive !== 0 || b_drive !== 0 || a_out !== 0 || b_out !== 0) $fatal(1,"opposite enable polarities");
        $display("PASS: tb_ttl_74x162652");
        $finish;
    end
endmodule
