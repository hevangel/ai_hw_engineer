`timescale 1ns/1ps
// Planar clock-domain bridge: CPU register cycles remain pending until the
// 4 MHz 8237 samples them. The 8086 stays in Tw; no programming strobe is lost
// when CPU and DMA clock edges coincide. Words serialize over two DMA edges.
module model30_dma_bridge (
    input logic clk,dma_clk,rst_n,
    input logic [2:0] phase,
    input logic selected,writing,
    input logic [19:0] address,
    input logic [1:0] lanes,
    input logic [15:0] wdata,
    output logic ready,
    output logic [15:0] response,
    output logic active,device_read,device_write,
    output logic [3:0] device_address,
    output logic [7:0] device_data,
    input logic [7:0] device_response
);
    logic request_toggle,ack_toggle,started;
    logic [3:0] request_address;
    logic [1:0] request_lanes;
    logic [15:0] request_data;
    logic request_write,second;
    assign active=request_toggle!=ack_toggle;
    assign device_read=active && !request_write;
    assign device_write=active && request_write;
    assign device_address=request_address+{3'b0,second};
    assign device_data=second || request_lanes==2 ? request_data[15:8]:request_data[7:0];
    assign ready=started && !active;
    always_ff @(posedge clk) begin
        if(!rst_n) begin
            request_toggle<=0;started<=0;request_address<=0;request_lanes<=0;request_data<=0;request_write<=0;
        end else begin
            if(phase==1) started<=0;
            if(phase==2 && selected && !started) begin
                request_toggle<=!request_toggle;started<=1;
                request_address<=address[3:0];request_lanes<=lanes;request_data<=wdata;request_write<=writing;
            end
        end
    end
    always_ff @(posedge dma_clk) begin
        if(!rst_n) begin ack_toggle<=0;response<=0;second<=0;end
        else if(active) begin
            if(second || request_lanes==2) response[15:8]<=device_response;
            else response[7:0]<=device_response;
            if(request_lanes==3 && !second) second<=1;
            else begin ack_toggle<=request_toggle;second<=0;end
        end
    end
endmodule
