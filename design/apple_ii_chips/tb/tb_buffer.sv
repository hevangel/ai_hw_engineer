`timescale 1ns/1ps
module tb_buffer;
    logic [40:1] d;
    tri [40:1] p;
    assign p[1] = d[1];
    assign p[2] = d[2];
    assign p[4] = d[4];
    assign p[6] = d[6];
    assign p[8] = d[8];
    assign p[10] = d[10];
    assign p[12] = d[12];
    assign p[14] = d[14];
    assign p[15] = d[15];
    assign p[16] = d[16];
    a2_8t97_appleii dut(.p1(p[1]),.p2(p[2]),.p3(p[3]),.p4(p[4]),.p5(p[5]),.p6(p[6]),.p7(p[7]),.p8(p[8]),.p9(p[9]),.p10(p[10]),.p11(p[11]),.p12(p[12]),.p13(p[13]),.p14(p[14]),.p15(p[15]),.p16(p[16]));
    initial begin
        d = 0;
        d[16] = 1;
        {d[14],d[12],d[10],d[6],d[4],d[2]}=6'b101010;
        d[1]=0; d[15]=0; #1;
        if ({p[13],p[11],p[9],p[7],p[5],p[3]} !== 6'b101010) $fatal(1,"buffer data");
        d[1]=1; #1;
        if ({p[13],p[11],p[9],p[7],p[5],p[3]} !== 6'b10zzzz) $fatal(1,"disable four");
        d[1]=0; d[15]=1; #1;
        if ({p[13],p[11],p[9],p[7],p[5],p[3]} !== 6'bzz1010) $fatal(1,"disable two");
        $display("PASS tb_buffer");
        $finish;
    end
endmodule
