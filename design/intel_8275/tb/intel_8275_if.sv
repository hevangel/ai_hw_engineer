interface intel_8275_if(input logic clk);
    logic rst_n=0, cclk_en=0, cs_n=1, rd_n=1, wr_n=1, a0=0;
    logic [7:0] db_in=0, db_out;
    logic db_oe, dack_n=1, lpen=0, drq, irq;
    logic [6:0] cc;
    logic [3:0] lc;
    logic [1:0] la,gpa;
    logic hrtc,vrtc,vsp,lten,rvv,hlgt;
endinterface
