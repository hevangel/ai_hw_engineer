`timescale 1ns/1ps
// Full-duplex serial cable: 8237 channels 0/2 feed Tx A/B, 1/3 drain Rx B/A.
module tb_dma_link;
    localparam int N=24;
    logic clk=0,rst_n=0,run_link=0;
    always #5 clk=~clk;
    logic [1:0] cs=3,rd=3,wr=3;
    logic [1:0] a[0:1]; logic [7:0] di[0:1],dout[0:1];
    logic [1:0] td,tdrq,rdrq,tirq,rirq;
    logic [4:0] phase=0;
    logic tx_tick,rx_tick;
    logic [7:0] memory[0:255];
    logic dma_cs=1,dma_rd=1,dma_wr=1;
    logic [3:0] reg_addr=0,dack,dreq;
    logic [7:0] dma_di=0,dma_do;
    logic dma_oe,hrq,hlda=0,addr_oe,adstb,aen,memr_n,memw_n,dior_n,diow_n,eop_n,valid;
    logic [15:0] dma_addr;
    logic [1:0] channel;
    int transfers=0,checks=0;
    assign tx_tick=run_link && phase==0;
    assign rx_tick=run_link && phase==4;
    assign dreq={rdrq[0],tdrq[1],rdrq[1],tdrq[0]};
    always_ff @(posedge clk) begin
        hlda<=rst_n && hrq;
        if (!rst_n || !run_link) phase<=0; else phase<=phase+1'b1;
        if (rst_n && valid) begin
            transfers<=transfers+1;
            if (!memw_n) begin
                if (channel==1) memory[dma_addr[7:0]]<=dout[1];
                else if (channel==3) memory[dma_addr[7:0]]<=dout[0];
                else $fatal(1,"unexpected DMA write channel");
            end
        end
    end
    intel_8237 dma (
        .clk(clk),.rst_n(rst_n),.cs_n(dma_cs),.ior_n(dma_rd),.iow_n(dma_wr),
        .reg_addr(reg_addr),.data_i(dma_di),.data_o(dma_do),.data_oe(dma_oe),
        .dreq(dreq),.dack(dack),.hrq(hrq),.hlda(hlda),.ready(1'b1),
        .eop_n(1'b1),.eop_out_n(eop_n),.dma_addr(dma_addr),.addr_oe(addr_oe),
        .adstb(adstb),.aen(aen),.memr_n(memr_n),.memw_n(memw_n),
        .dma_ior_n(dior_n),.dma_iow_n(diow_n),.transfer_valid(valid),.transfer_channel(channel)
    );
    for (genvar i=0;i<2;i++) begin: chips
        localparam int TXCH=i==0?0:2;
        localparam int RXCH=i==0?3:1;
        logic doe,dpll,rts,flagdet;
        logic [3:0] pb;
        intel_8273 chip (
            .clk(clk),.rst_n(rst_n),.cs_n(cs[i]),
            .rd_n(!dack[RXCH]?dior_n:rd[i]),.wr_n(!dack[TXCH]?diow_n:wr[i]),
            .addr(a[i]),.data_i(!dack[TXCH]?memory[dma_addr[7:0]]:di[i]),
            .data_o(dout[i]),.data_oe(doe),.tx_dack_n(dack[TXCH]),.rx_dack_n(dack[RXCH]),
            .tx_drq(tdrq[i]),.rx_drq(rdrq[i]),.tx_int(tirq[i]),.rx_int(rirq[i]),
            .tx_tick(tx_tick),.rx_tick(rx_tick),.tx_sample_tick(rx_tick),.clk32_tick(1'b0),
            .rxd(td[1-i]),.txd(td[i]),.dpll_tick(dpll),.cts_n(1'b0),.cd_n(1'b0),
            .port_a(3'd0),.port_b(pb),.rts_n(rts),.flag_det_n(flagdet)
        );
    end
    task automatic tick(input int n=1);
        repeat(n) begin @(posedge clk); @(negedge clk); end
    endtask
    task automatic check(input bit ok,input string msg);
        checks++; if (!ok) $fatal(1,"%s",msg);
    endtask
    task automatic dma_put(input logic [3:0] address,input logic [7:0] value);
        dma_cs=0; reg_addr=address; dma_di=value; dma_wr=0; tick();
        dma_cs=1; dma_wr=1; tick();
    endtask
    task automatic dma_channel(input logic [1:0] c,input logic [7:0] base,input bit rx);
        dma_put(12,0); dma_put({1'b0,c,1'b0},base); dma_put({1'b0,c,1'b0},0);
        dma_put({1'b0,c,1'b1},8'(N-1)); dma_put({1'b0,c,1'b1},0);
        dma_put(11,(rx?8'h44:8'h48)|{6'b0,c});
        dma_put(10,{6'b0,c});
    endtask
    task automatic put(input int bank,input logic [1:0] address,input logic [7:0] value);
        cs[bank]=0; a[bank]=address; di[bank]=value; wr[bank]=0; tick();
        cs[bank]=1; wr[bank]=1; tick();
    endtask
    task automatic get(input int bank,input logic [1:0] address,output logic [7:0] value);
        cs[bank]=0; a[bank]=address; rd[bank]=0; #1; value=dout[bank];
        tick(); cs[bank]=1; rd[bank]=1; tick();
    endtask
    initial begin
        logic [7:0] value;
        int timeout;
        a[0]=0; a[1]=0; di[0]=0; di[1]=0;
        for(int i=0;i<256;i++) memory[i]=8'ha5;
        for(int i=0;i<N;i++) begin memory[16+i]=8'(i*17); memory[80+i]=8'hff^8'(i*29); end
        tick(4); rst_n=1; tick(4);
        dma_put(13,0);
        dma_channel(0,16,0); dma_channel(1,208,1);
        dma_channel(2,80,0); dma_channel(3,144,1);
        for(int bank=0;bank<2;bank++) begin
            put(bank,0,8'h91); put(bank,1,8'h24);
            put(bank,0,8'ha0); put(bank,1,1); // NRZI on both endpoints.
            put(bank,0,8'hc0); put(bank,1,8'(N)); put(bank,1,0);
        end
        for(int bank=0;bank<2;bank++) begin
            put(bank,0,8'hc8); put(bank,1,8'(N)); put(bank,1,0);
            put(bank,1,8'h42+8'(bank)); put(bank,1,8'h13);
        end
        tick(16); run_link=1; timeout=0;
        while (!(tirq==3 && rirq==3 && transfers==4*N)) begin
            tick(); timeout++;
            if (timeout>20000) $fatal(1,"DMA cable timeout tx=%b rx=%b transfers=%0d",tirq,rirq,transfers);
        end
        run_link=0; tick(4);
        for(int i=0;i<N;i++) begin
            check(memory[208+i]===memory[16+i],"A -> B DMA memory");
            check(memory[144+i]===memory[80+i],"B -> A DMA memory");
        end
        check(memory[207]==8'ha5 && memory[232]==8'ha5 &&
              memory[143]==8'ha5 && memory[168]==8'ha5,"DMA buffer guards");
        for(int bank=0;bank<2;bank++) begin
            get(bank,2,value); check(value==8'h0d,"serial Tx result");
            get(bank,3,value); check(value==8'he0,"serial Rx CRC result");
            get(bank,3,value); check(value==8'(N),"Rx count");
            get(bank,3,value); check(value==0,"Rx high count");
            get(bank,3,value); check(value==8'h43-8'(bank),"Rx buffered address");
            get(bank,3,value); check(value==8'h13,"Rx buffered control");
        end
        dma_cs=0; reg_addr=8; dma_rd=0; #1;
        check(dma_oe && dma_do[3:0]==4'hf,"all four real DMA terminal counts");
        check(transfers==96 && tdrq==0 && rdrq==0,"exact transfers and drained handshakes");
        $display("8273 DMA LINK PASSED checks=%0d transfers=%0d",checks,transfers); $finish;
    end
    initial begin #10000000; $fatal(1,"DMA link timeout"); end
endmodule
