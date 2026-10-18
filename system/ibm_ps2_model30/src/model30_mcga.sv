`timescale 1ns/1ps
// IBM Model 30 TR, video registers pp.1-44..1-62 and font tables pp.1-65ff.
// External storage holds display RAM and the separate 512-character font RAM.
module model30_mcga (
    input logic clk,rst_n,selected,read_strobe,write_strobe,
    input logic [4:0] address,
    input logic [7:0] wdata,
    output logic [7:0] rdata,mode,border,
    output logic [1:0] graphics_mode,
    output logic video_irq,
    input logic [5:0] debug_index,
    output logic [7:0] debug_crtc,
    input logic [9:0] debug_dac_index,
    output logic [5:0] debug_dac,
    output logic [15:0] font_source,
    input logic [7:0] font_read,
    output logic font_write,
    output logic [12:0] font_address,
    output logic [7:0] font_data
);
    logic [7:0] crtc[0:20];
    logic [5:0] dac[0:767];
    logic [5:0] index;
    // IBM TR p.1-61: PEL mask must remain FF; mask operations are not
    // supported on Model 30. Preserve register readback, not VGA masking.
    logic [7:0] dac_mask,dac_read_addr,dac_write_addr;
    logic [1:0] dac_read_component,dac_write_component;
    logic dac_read_mode,irq_latch;
    logic [17:0] raster;
    logic vsync,old_vsync;
    logic [7:0] ext_mode;
    logic loading,font_pending,font_phase;
    logic [7:0] font_entry,font_character;
    logic [3:0] font_line;
    logic [1:0] font_block;
    logic font_page;
    // IBM TR p.1-55: bit 4 independently selects 640x200 mode 6.
    // Original BIOS/BASICA writes 18h, with the 320x200 bit 1 clear.
    assign graphics_mode=crtc[16][0] ? 2'd3 : crtc[16][1] ? 2'd2 : (mode[4] || mode[1]) ? 2'd1 : 2'd0;
    // ASSUMPTION A1: nominal frame timing; analog raster electrical timing is
    // outside the platform. 70 Hz text/CGA/13h and 60 Hz 11h are observable.
    assign vsync=raster>=(graphics_mode==2 ? 18'd125000:18'd108000);
    assign video_irq=selected && irq_latch && crtc[17][4] && !crtc[17][5];
    assign debug_crtc=debug_index<21 ? crtc[debug_index[4:0]]:8'hff;
    assign debug_dac=debug_dac_index<768 ? dac[debug_dac_index]:6'b0;
    assign font_source={1'b0,font_block,13'b0}+{3'b0,font_line,9'b0}+{7'b0,font_entry,1'b0}+
        {15'b0,font_phase};
    assign font_write=loading && font_phase;
    assign font_address={font_page,font_character,font_line};
    assign font_data=font_read;
    always_comb begin
        rdata=8'hff;
        case(address)
            5'h06:rdata=dac_mask;
            5'h07:rdata=dac_read_mode ? 8'h03:8'h00;
            5'h08:rdata=dac_write_addr;
            5'h09:rdata={2'b0,dac[{dac_read_addr,1'b0}+{2'b0,dac_read_addr}+{8'b0,dac_read_component}]};
            5'h14:rdata={2'b0,index};
            5'h15:begin
                if(index==16) rdata={mode[0],1'b0,(graphics_mode==2 || graphics_mode==1 && mode[4] || graphics_mode==0 && mode[0]),
                    1'b1,graphics_mode==0,(graphics_mode==1 || graphics_mode==3),graphics_mode==2,graphics_mode==3};
                else if(index==17) rdata=(crtc[17]&8'hbf)|{1'b0,irq_latch,6'b0};
                else if(index==18 && crtc[17][7]) rdata=8'h02;
                else if(index<21) rdata=crtc[index[4:0]];
            end
            5'h18:rdata=mode;
            5'h19:rdata=border;
            5'h1a:rdata={4'b0,vsync,2'b0,(raster%18'd254)>18'd202};
            5'h1d:rdata=ext_mode;
            default:rdata=8'hff;
        endcase
    end
    always_ff @(posedge clk) begin
        if(!rst_n) begin
            index<=0;mode<=0;border<=0;dac_mask<=8'hff;dac_read_addr<=0;dac_write_addr<=0;
            dac_read_component<=0;dac_write_component<=0;dac_read_mode<=0;
            irq_latch<=0;raster<=0;old_vsync<=0;ext_mode<=0;
            loading<=0;font_pending<=0;font_phase<=0;font_entry<=0;font_character<=0;
            font_line<=0;font_block<=0;font_page<=0;
            for(integer i=0;i<21;i=i+1) crtc[i]<=0;
            for(integer i=0;i<768;i=i+1) dac[i]<=0;
        end else begin
            raster<=raster>=(graphics_mode==2 ? 18'd133332:18'd114285) ? 18'b0:raster+18'd1;
            old_vsync<=vsync;
            if(vsync && !old_vsync) begin
                irq_latch<=1;
                if(font_pending) begin loading<=1;font_pending<=0;font_phase<=0;font_entry<=0;font_line<=0;end
            end
            if(loading) begin
                if(!font_phase) begin font_character<=font_read;font_phase<=1;end
                else if(font_line==15) begin
                    font_line<=0;font_phase<=0;font_entry<=font_entry+8'd1;
                    if(font_entry==crtc[20]) begin loading<=0;crtc[18][7]<=0;end
                end else font_line<=font_line+4'd1;
            end
            if(selected && read_strobe && address==9) begin
                if(dac_read_component==2) begin dac_read_component<=0;dac_read_addr<=dac_read_addr+8'd1;end
                else dac_read_component<=dac_read_component+2'd1;
            end
            if(selected && write_strobe) case(address)
                5'h06:dac_mask<=wdata;
                5'h07:begin dac_read_addr<=wdata;dac_read_component<=0;dac_read_mode<=1;end
                5'h08:begin dac_write_addr<=wdata;dac_write_component<=0;dac_read_mode<=0;end
                5'h09:begin
                    dac[{dac_write_addr,1'b0}+{2'b0,dac_write_addr}+{8'b0,dac_write_component}]<=wdata[5:0];
                    if(dac_write_component==2) begin dac_write_component<=0;dac_write_addr<=dac_write_addr+8'd1;end
                    else dac_write_component<=dac_write_component+2'd1;
                end
                5'h14:index<=wdata[5:0];
                5'h15:if(index<21 && !(index<=9 && crtc[16][7])) begin
                    case(index)
                        6'd9,6'd11,6'd14:crtc[index[4:0]]<=wdata&8'h0f;
                        6'd10:crtc[10]<=wdata&8'h2f;
                        6'd16:crtc[16]<=wdata&8'h9b;
                        6'd17:begin crtc[17]<=wdata&8'hb0;if(!wdata[4]) irq_latch<=0;end
                        6'd18:begin
                            crtc[18]<=wdata&8'hf7;
                            if(!wdata[7]) font_pending<=0;
                            else if(!crtc[18][7]) begin
                                font_block<=crtc[19][5:4];font_page<=wdata[5];
                                if(wdata[6]) begin loading<=1;font_phase<=0;font_entry<=0;font_line<=0;end
                                else font_pending<=1;
                            end
                        end
                        default:crtc[index[4:0]]<=wdata;
                    endcase
                end
                5'h18:mode<=wdata&8'h3f;
                5'h19:border<=wdata&8'h3f;
                5'h1d:ext_mode<=wdata&8'h84;
                default:begin end
            endcase
        end
    end
endmodule
