`timescale 1ns/1ps
interface intel_8273_if(input logic clk);
    logic rst_n=0,cs_n=1,rd_n=1,wr_n=1;
    logic [1:0] addr=0;
    logic [7:0] data_i=0,data_o;
    logic data_oe,tx_dack_n=1,rx_dack_n=1;
    logic tx_drq,rx_drq,tx_int,rx_int;
    logic tx_tick=0,rx_tick=0,tx_sample_tick=0,clk32_tick=0,rxd=1;
    logic txd,dpll_tick,cts_n=0,cd_n=0;
    logic [2:0] port_a=0;
    logic [3:0] port_b;
    logic rts_n,flag_det_n;
    int checks=0;
    bit monitor_enable=0;
    task automatic tick(input int n=1);
        repeat(n) begin @(posedge clk); @(negedge clk); end
    endtask
    task automatic check(input bit ok,input string message);
        checks++;
        if (!ok) $fatal(1,"%s at %0t",message,$time);
    endtask
    task automatic reset;
        rst_n=0; cs_n=1; rd_n=1; wr_n=1; tx_dack_n=1; rx_dack_n=1;
        tx_tick=0; rx_tick=0; tx_sample_tick=0; clk32_tick=0;
        rxd=1; cts_n=0; cd_n=0; port_a=0;
        tick(3); rst_n=1; tick(3);
    endtask
    task automatic put(input logic [1:0] a,input logic [7:0] d,input int hold=1);
        cs_n=0; addr=a; data_i=d; wr_n=0; tick(hold);
        wr_n=1; cs_n=1; tick();
    endtask
    task automatic get(input logic [1:0] a,output logic [7:0] d,input int hold=1);
        cs_n=0; addr=a; rd_n=0; #1; d=data_o;
        check(data_oe,"CPU read drives bus"); tick(hold);
        rd_n=1; cs_n=1; tick();
    endtask
    task automatic mask(input logic [7:0] op,input logic [7:0] d);
        put(0,op); put(1,d);
    endtask
    task automatic data_put(input logic [7:0] d,input int hold=1);
        tx_dack_n=0; data_i=d; tick(); check(!tx_drq,"Tx DACK drops request");
        wr_n=0; tick(hold); wr_n=1; tx_dack_n=1; tick();
    endtask
    task automatic data_get(output logic [7:0] d,input int hold=1);
        rx_dack_n=0; tick(); check(!rx_drq,"Rx DACK drops request");
        rd_n=0; #1; d=data_o; check(data_oe,"Rx data drives bus");
        tick(hold); check(data_o===d,"Rx data held throughout stretched DMA read");
        rd_n=1; rx_dack_n=1; tick();
    endtask
    task automatic transmit(input int n,input bit buffered=1,
        input logic [7:0] a=8'h42,c=8'h13,op=8'hc8);
        put(0,op); put(1,8'(n)); put(1,8'(n>>8));
        if (buffered && op!=8'hc9) begin put(1,a); put(1,c); end
        tick(4);
    endtask
    task automatic receive(input int n,input logic [7:0] op=8'hc0,
        input logic [7:0] a=8'h42,b=8'h43);
        put(0,op); put(1,8'(n)); put(1,8'(n>>8));
        if (op!=8'hc0) begin put(1,a); put(1,b); end
        tick(4);
    endtask
endinterface
