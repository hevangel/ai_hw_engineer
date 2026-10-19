`timescale 1ns/1ps
module tb_dram;
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
    assign p[11] = d[11];
    assign p[12] = d[12];
    assign p[13] = d[13];
    assign p[15] = d[15];
    assign p[16] = d[16];
    a2_4116 dut(.p1(p[1]),.p2(p[2]),.p3(p[3]),.p4(p[4]),.p5(p[5]),.p6(p[6]),.p7(p[7]),.p8(p[8]),.p9(p[9]),.p10(p[10]),.p11(p[11]),.p12(p[12]),.p13(p[13]),.p14(p[14]),.p15(p[15]),.p16(p[16]));
    initial begin
        d = 0;
        d[1] = 1;
        d[8] = 1;
        d[9] = 1;
        d[4]=1; d[15]=1; d[3]=1; #2;
        if (p[14] !== 1'bz) $fatal(1,"unselected DRAM must release bus");
        // Write all 128 rows at different column addresses, detect aliasing.
        for(int i=0; i<128; i++) begin
            {d[13],d[5],d[6],d[7],d[12],d[11],d[10]}=7'(i);
            #1; d[4]=0; #1;
            {d[13],d[5],d[6],d[7],d[12],d[11],d[10]}=7'(127-i);
            d[3]=0; d[2]=1'(i); #1; d[15]=0; #1;
            if(p[14] !== 1'bz) $fatal(1,"early write must not drive data");
            d[15]=1; d[4]=1; d[3]=1; #1;
        end
        for(int i=0; i<128; i++) begin
            {d[13],d[5],d[6],d[7],d[12],d[11],d[10]}=7'(i);
            #1; d[4]=0; #1;
            {d[13],d[5],d[6],d[7],d[12],d[11],d[10]}=7'(127-i);
            #1; d[15]=0; #1;
            if(p[14] !== 1'(i)) $fatal(1,"DRAM read row %0d",i);
            // RAS may release before CAS; output stays latched until CAS rises.
            d[4]=1; #1;
            if(p[14] !== 1'(i)) $fatal(1,"output retention");
            d[15]=1; #1;
        end
        // Read-modify-write must retain the old output until CAS releases.
        {d[13],d[5],d[6],d[7],d[12],d[11],d[10]}=0;
        #1; d[4]=0; #1;
        {d[13],d[5],d[6],d[7],d[12],d[11],d[10]}=127;
        #1; d[15]=0; #1; d[2]=1; d[3]=0; #1;
        if(p[14] !== 0) $fatal(1,"late write output");
        d[15]=1; d[3]=1; #1; d[15]=0; #1;
        if(p[14] !== 1) $fatal(1,"late write data");
        $display("PASS tb_dram");
        $finish;
    end
endmodule
