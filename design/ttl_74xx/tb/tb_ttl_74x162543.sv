`timescale 1ns/1ps
module tb_ttl_74x162543;
    logic [15:0] a_in, b_in;
    logic [1:0] ceab_n, leab_n, oeab_n, ceba_n, leba_n, oeba_n;
    logic [15:0] a_out, b_out;
    logic [1:0] a_drive, b_drive;
    ttl_74x162543 dut(.*);
    initial begin
        a_in=0; b_in=0; ceab_n=2'b00; leab_n=2'b00; oeab_n=2'b00;
        ceba_n=2'b11; leba_n=2'b11; oeba_n=2'b11;
        a_in=16'hA55A; #1;
        if (b_out !== 16'hA55A || b_drive !== 2'b11) $fatal(1,"A-to-B transparent mode");
        leab_n=2'b11; a_in=16'h3C69; #1;
        if (b_out !== 16'hA55A) $fatal(1,"A-to-B closed latch holds");
        leab_n=2'b10; #1;
        if (b_out[7:0] !== 8'h69 || b_out[15:8] !== 8'hA5) $fatal(1,"independent section latches");
        ceab_n[0]=1; #1;
        if (b_drive[0] || b_out[7:0] !== 8'h00 || !b_drive[1]) $fatal(1,"CE gates only its section");
        ceab_n=2'b11; oeab_n=2'b11; ceba_n=2'b00; leba_n=2'b00; oeba_n=2'b00;
        b_in=16'h96E1; #1;
        if (a_out !== 16'h96E1 || a_drive !== 2'b11) $fatal(1,"B-to-A transparent mode");
        leba_n=2'b11; b_in=16'h0000; #1;
        if (a_out !== 16'h96E1) $fatal(1,"B-to-A latch holds");
        $display("PASS: tb_ttl_74x162543");
        $finish;
    end
endmodule
