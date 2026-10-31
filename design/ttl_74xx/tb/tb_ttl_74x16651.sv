`timescale 1ns/1ps
module tb_ttl_74x16651;
    logic [15:0] a_in, b_in;
    logic [1:0] oeab, oeba_n, clkab, clkba, sab, sba;
    logic [15:0] a_out, b_out;
    logic [1:0] a_drive, b_drive;
    ttl_74x16651 dut(.*);
    initial begin
        a_in=16'hA55A; b_in=16'hC369; oeab=2'b11; oeba_n=2'b00;
        clkab=0; clkba=0; sab=0; sba=0; #1;
        if (b_out !== ~16'hA55A || a_out !== ~16'hC369 || b_drive !== 2'b11 || a_drive !== 2'b11)
            $fatal(1,"both real-time directions and native OE polarities");
        clkab=2'b11; clkba=2'b11; #1; clkab=0; clkba=0;
        a_in=16'h3C96; b_in=16'h5AA5; sab=2'b01; sba=2'b10; #1;
        if (b_out[7:0] !== ~8'h5A || b_out[15:8] !== ~8'h3C ||
            a_out[15:8] !== ~8'hC3 ||
            a_out[7:0] !== ~8'hA5)
            $fatal(1,"independent bank stored selects");
        oeab=0; oeba_n=2'b11; #1;
        if (a_drive !== 0 || b_drive !== 0 || a_out !== 0 || b_out !== 0) $fatal(1,"disabled data masked");
        $display("PASS: tb_ttl_74x16651");
        $finish;
    end
endmodule
