`timescale 1ns/1ps
module tb_latch;
    logic [40:1] d;
    tri [40:1] p;
    assign p[1] = d[1];
    assign p[2] = d[2];
    assign p[3] = d[3];
    assign p[8] = d[8];
    assign p[13] = d[13];
    assign p[14] = d[14];
    assign p[15] = d[15];
    assign p[16] = d[16];
    a2_74ls259 dut(.p1(p[1]),.p2(p[2]),.p3(p[3]),.p4(p[4]),.p5(p[5]),.p6(p[6]),.p7(p[7]),.p8(p[8]),.p9(p[9]),.p10(p[10]),.p11(p[11]),.p12(p[12]),.p13(p[13]),.p14(p[14]),.p15(p[15]),.p16(p[16]));
    initial begin
        d = 0;
        d[16] = 1;
        d[15]=0; d[14]=1; #1;
        if ({p[12:9],p[7:4]} !== 0) $fatal(1,"clear");
        d[15]=1; d[14]=0; d[13]=1;
        for(int i=0; i<8; i++) begin
            d[3:1]=3'(i); #1;
            if ({p[12:9],p[7:4]} !== 8'((1<<(i+1))-1)) $fatal(1,"addressable set");
        end
        d[14]=1; d[13]=0; #1;
        if ({p[12:9],p[7:4]} !== 8'hff) $fatal(1,"hold");
        d[15]=0; d[14]=0; d[13]=1; d[3:1]=3; #1;
        if ({p[12:9],p[7:4]} !== 8'h08) $fatal(1,"demux mode");
        $display("PASS tb_latch");
        $finish;
    end
endmodule
