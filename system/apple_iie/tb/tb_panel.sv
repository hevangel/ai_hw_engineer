`timescale 1ns/1ps
module tb_panel;
    import "DPI-C" function int panel_cycle(input int address,write_en,pc,visible,main_byte,aux_byte,graphics,line,font,aux_font,col80);
    import "DPI-C" function void panel_wave(input int phi0,q3,pras,pcas,ldps,address,we,data);
    logic clk14=0,power_n=0,rst_n=0,key_down=0;
    logic [6:0] key_data=0;
    wire bus_clk,we,fetch,fault,visible,graphics,col80,phi0,q3,pras,pcas,ldps;
    wire [15:0] address,pc;
    wire [7:0] data,main_byte,aux_byte;
    wire [2:0] line;
    wire [1:0] font,aux_font;
    apple_iie dut(.clk14(clk14),.power_n(power_n),.rst_n(rst_n),.key_data(key_data),.key_down(key_down),
        .external_addr(16'd0),.external_data(8'd0),.external_we(1'b0),.debug_addr(16'd0),.debug_aux(1'b0),
        .bus_clk(bus_clk),.bus_addr(address),.pc(pc),.bus_data(data),.bus_we(we),.fetch(fetch),.fault(fault),
        .video_main(main_byte),.video_aux(aux_byte),.video_visible(visible),.video_graphics(graphics),.video_80col(col80),
        .video_line(line),.video_font_main(font),.video_font_aux(aux_font),.phi0(phi0),.q3(q3),.pras_n(pras),.pcas_n(pcas),.ldps_n(ldps));
    // Exactly one testbench process calls DPI, even at board scale.
    initial begin
        bit previous;int old_address,old_we,code,reset_ticks;
        repeat(8)begin #5;clk14=1;#5;clk14=0;end
        power_n=1;
        repeat(56)begin #5;clk14=1;#5;clk14=0;end
        rst_n=1;reset_ticks=0;
        forever begin
            previous=bus_clk;old_address=int'(address);old_we=int'(we);
            #5;clk14=1;#1;
            if(rst_n&&fault)$fatal(1,"IIe panel CPU fault PC=%h",pc);
            if(!previous&&bus_clk&&rst_n)begin
                code=panel_cycle(old_address,old_we,int'(pc),int'(visible),int'(main_byte),int'(aux_byte),int'(graphics),int'(line),int'(font),int'(aux_font),int'(col80));
                key_data=7'(code);key_down=1'(code>>7);
                if((code&256)!=0)begin rst_n=0;reset_ticks=56;end
            end
            panel_wave(int'(phi0),int'(q3),int'(pras),int'(pcas),int'(ldps),int'(address),int'(we),int'(data));
            #4;clk14=0;
            if(reset_ticks>0)begin reset_ticks--;if(reset_ticks==0)rst_n=1;end
        end
    end
endmodule
