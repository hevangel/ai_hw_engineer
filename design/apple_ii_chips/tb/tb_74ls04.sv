`timescale 1ns/1ps
module tb_74ls04;
    logic [40:1] d;
    tri [40:1] p;
    assign p[1] = d[1];
    assign p[3] = d[3];
    assign p[5] = d[5];
    assign p[7] = d[7];
    assign p[9] = d[9];
    assign p[11] = d[11];
    assign p[13] = d[13];
    assign p[14] = d[14];
    a2_74ls04 dut(.p1(p[1]),.p2(p[2]),.p3(p[3]),.p4(p[4]),.p5(p[5]),.p6(p[6]),.p7(p[7]),.p8(p[8]),.p9(p[9]),.p10(p[10]),.p11(p[11]),.p12(p[12]),.p13(p[13]),.p14(p[14]));
    initial begin
        d = 0;
        d[14] = 1;
        begin
            logic [11:0] vectors [0:63];
            $readmemb("tb/74ls04.mem",vectors);
            for(int i=0; i<64; i++) begin
                {d[13],d[11],d[9],d[5],d[3],d[1]}=vectors[i][11:6];
                #1;
                if ({p[12],p[10],p[8],p[6],p[4],p[2]} !== vectors[i][5:0]) $fatal(1,"74LS04 pins case %0d",i);
            end
        end
        $display("PASS tb_74ls04");
        $finish;
    end
endmodule
