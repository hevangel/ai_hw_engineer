`timescale 1ns/1ps
module tb_74ls175;
    logic [40:1] d;
    tri [40:1] p;
    assign p[1] = d[1];
    assign p[4] = d[4];
    assign p[5] = d[5];
    assign p[8] = d[8];
    assign p[9] = d[9];
    assign p[12] = d[12];
    assign p[13] = d[13];
    assign p[16] = d[16];
    a2_74ls175 dut(.p1(p[1]),.p2(p[2]),.p3(p[3]),.p4(p[4]),.p5(p[5]),.p6(p[6]),.p7(p[7]),.p8(p[8]),.p9(p[9]),.p10(p[10]),.p11(p[11]),.p12(p[12]),.p13(p[13]),.p14(p[14]),.p15(p[15]),.p16(p[16]));
    initial begin
        d = 0;
        d[16] = 1;
        d[1]=0; #1; d[1]=1;
        for(int i=0;i<16;i++) begin
            {d[13],d[12],d[5],d[4]}=4'(i); d[9]=0; #1; d[9]=1; #1;
            if({p[15],p[10],p[7],p[2]} !== 4'(i)) $fatal(1,"parallel data %0d",i);
        end
        d[1]=0; #1;
        if({p[15],p[10],p[7],p[2]} !== 0) $fatal(1,"asynchronous reset");
        if({p[14],p[11],p[6],p[3]} !== 4'hf) $fatal(1,"complement outputs");
        $display("PASS tb_74ls175");
        $finish;
    end
endmodule
