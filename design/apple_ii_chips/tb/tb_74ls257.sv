`timescale 1ns/1ps
module tb_74ls257;
    logic [40:1] d;
    tri [40:1] p;
    assign p[1] = d[1];
    assign p[2] = d[2];
    assign p[3] = d[3];
    assign p[5] = d[5];
    assign p[6] = d[6];
    assign p[8] = d[8];
    assign p[10] = d[10];
    assign p[11] = d[11];
    assign p[13] = d[13];
    assign p[14] = d[14];
    assign p[15] = d[15];
    assign p[16] = d[16];
    a2_74ls257 dut(.p1(p[1]),.p2(p[2]),.p3(p[3]),.p4(p[4]),.p5(p[5]),.p6(p[6]),.p7(p[7]),.p8(p[8]),.p9(p[9]),.p10(p[10]),.p11(p[11]),.p12(p[12]),.p13(p[13]),.p14(p[14]),.p15(p[15]),.p16(p[16]));
    initial begin
        d = 0;
        d[16] = 1;
        begin
            logic [13:0] vectors [0:1023];
            $readmemb("tb/74ls257.mem",vectors);
            for(int i=0; i<1024; i++) begin
                {d[15],d[14],d[13],d[11],d[10],d[6],d[5],d[3],d[2],d[1]}=vectors[i][13:4];
                #1;
                if ({p[12],p[9],p[7],p[4]} !== vectors[i][3:0]) $fatal(1,"74LS257 pins case %0d",i);
            end
        end
        $display("PASS tb_74ls257");
        $finish;
    end
endmodule
