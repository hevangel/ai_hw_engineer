`timescale 1ns/1ps
module tb_ttl_74x156;
    logic [1:0] a,g_n,c;
    logic [3:0] y0_n,y1_n,expected0,expected1;
    ttl_74x156 dut(.*);
    initial begin
        for(int v=0;v<64;v++) begin
            {a,g_n,c}=6'(v);#1;
            expected0=4'hf;expected1=4'hf;
            for(int line=0;line<4;line++) begin
                if(a==2'(line) && g_n[0]==0 && c[0]==1) expected0[line]=0;
                if(a==2'(line) && g_n[1]==0 && c[1]==0) expected1[line]=0;
            end
            if(y0_n!==expected0 || y1_n!==expected1) $fatal(1,"demux data gating");
        end
        $display("PASS: tb_ttl_74x156 (all address, strobe and data combinations)");
        $finish;
    end
endmodule
