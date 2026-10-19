`timescale 1ns/1ps
module tb_74ls139;
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
    a2_74ls139 dut(.p1(p[1]),.p2(p[2]),.p3(p[3]),.p4(p[4]),.p5(p[5]),.p6(p[6]),.p7(p[7]),.p8(p[8]),.p9(p[9]),.p10(p[10]),.p11(p[11]),.p12(p[12]),.p13(p[13]),.p14(p[14]),.p15(p[15]),.p16(p[16]));
    initial begin
        d = 0;
        d[16] = 1;
        begin
            logic [13:0] vectors [0:63];
            $readmemb("tb/74ls139.mem",vectors);
            for(int i=0; i<64; i++) begin
                {d[15],d[14],d[13],d[3],d[2],d[1]}=vectors[i][13:8];
                #1;
                if ({p[12],p[11],p[10],p[9],p[7],p[6],p[5],p[4]} !== vectors[i][7:0]) $fatal(1,"74LS139 pins case %0d",i);
            end
        end
        $display("PASS tb_74ls139");
        $finish;
    end
endmodule
