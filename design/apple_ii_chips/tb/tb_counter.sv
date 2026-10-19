`timescale 1ns/1ps
module tb_counter;
    logic [40:1] d;
    tri [40:1] p;
    assign p[1] = d[1];
    assign p[2] = d[2];
    assign p[3] = d[3];
    assign p[4] = d[4];
    assign p[5] = d[5];
    assign p[6] = d[6];
    assign p[7] = d[7];
    assign p[8] = d[8];
    assign p[9] = d[9];
    assign p[10] = d[10];
    assign p[16] = d[16];
    a2_74ls161 dut(.p1(p[1]),.p2(p[2]),.p3(p[3]),.p4(p[4]),.p5(p[5]),.p6(p[6]),.p7(p[7]),.p8(p[8]),.p9(p[9]),.p10(p[10]),.p11(p[11]),.p12(p[12]),.p13(p[13]),.p14(p[14]),.p15(p[15]),.p16(p[16]));
    initial begin
        d = 0;
        d[16] = 1;
        d[1]=0; #1; d[1]=1; d[9]=1; d[7]=1; d[10]=1;
        for (int i=1; i<=32; i++) begin
            d[2]=0; #1; d[2]=1; #1;
            if ({p[11],p[12],p[13],p[14]} !== 4'(i)) $fatal(1,"count %0d",i);
            if (p[15] !== ((i%16)==15)) $fatal(1,"carry");
        end
        d[9]=0; {d[6],d[5],d[4],d[3]}=4'hb; d[7]=0;
        d[2]=0; #1; d[2]=1; #1;
        if ({p[11],p[12],p[13],p[14]} !== 4'hb) $fatal(1,"load overrides disabled count");
        d[9]=1; d[2]=0; #1; d[2]=1; #1;
        if ({p[11],p[12],p[13],p[14]} !== 4'hb) $fatal(1,"disabled hold");
        d[1]=0; #1;
        if ({p[11],p[12],p[13],p[14]} !== 0) $fatal(1,"asynchronous clear");
        $display("PASS tb_counter");
        $finish;
    end
endmodule
