`timescale 1ns/1ps
module tb_dff;
    logic [40:1] d;
    tri [40:1] p;
    assign p[1] = d[1];
    assign p[2] = d[2];
    assign p[3] = d[3];
    assign p[4] = d[4];
    assign p[7] = d[7];
    assign p[10] = d[10];
    assign p[11] = d[11];
    assign p[12] = d[12];
    assign p[13] = d[13];
    assign p[14] = d[14];
    a2_74ls74 dut(.p1(p[1]),.p2(p[2]),.p3(p[3]),.p4(p[4]),.p5(p[5]),.p6(p[6]),.p7(p[7]),.p8(p[8]),.p9(p[9]),.p10(p[10]),.p11(p[11]),.p12(p[12]),.p13(p[13]),.p14(p[14]));
    initial begin
        d = 0;
        d[14] = 1;
        d[1]=0; d[4]=1; d[13]=1; d[10]=1; #1;
        if({p[5],p[6]} !== 2'b01) $fatal(1,"clear");
        d[2]=1; d[1]=1; #1;
        if({p[5],p[6]} !== 2'b01) $fatal(1,"release does not clock");
        d[3]=1; #1;
        if({p[5],p[6]} !== 2'b10) $fatal(1,"clock capture");
        d[1]=0; d[4]=0; #1;
        if({p[5],p[6]} !== 2'b11) $fatal(1,"both async controls");
        d[1]=1; #1;
        if({p[5],p[6]} !== 2'b10) $fatal(1,"release clear while preset asserted");
        d[2]=0; d[4]=1; #1;
        if({p[5],p[6]} !== 2'b10) $fatal(1,"preset release does not clock high level");
        d[3]=0; #1; d[3]=1; #1;
        if({p[5],p[6]} !== 2'b01) $fatal(1,"next clock capture");
        $display("PASS tb_dff");
        $finish;
    end
endmodule
