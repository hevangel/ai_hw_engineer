`timescale 1ns/1ps
module apple_iie #(
    parameter bit EXTERNAL_CPU=0,
    parameter ROM_FILE="work/rom.hex"
)(
    input logic clk14, power_n, rst_n,
    input logic [6:0] key_data,
    input logic key_down,
    input logic [15:0] external_addr,
    input logic [7:0] external_data,
    input logic external_we,
    input logic [15:0] debug_addr,
    input logic debug_aux,
    output logic [7:0] debug_data,
    output logic bus_clk,
    output logic [15:0] bus_addr, pc,
    output logic [7:0] bus_data, write_data,
    output logic bus_we, fetch, fault,
    output logic [15:0] video_addr,
    output logic [7:0] video_main, video_aux,
    output logic video_visible, video_graphics, video_80col,
    output logic [2:0] video_line,
    output logic [1:0] video_font_main, video_font_aux,
    output logic speaker, cassette,
    output logic phi0, q3, pras_n, pcas_n, ldps_n,
    output logic keyboard_pending,
    output logic main_selected, aux_selected,
    output logic [15:0] physical_addr
);
    logic m7, phi1, vid7m, s80vid_n, iou_clk;
    logic [7:0] mmu_ra, iou_ra, cpu_column, cpu_row, video_row;
    logic ramen_n,en80_n,romen1_n,romen2_n,cxxxout,kbd_n,rw245;
    logic mmu_md7,mmu_oe,iou_md7,iou_oe;
    logic kstrb,akd,h0,sega,segb,vc,wndw_n,sync_n,clrgat_n,ra9_n,ra10_n;
    logic an0,an1,an2,an3;
    logic [6:0] keyboard;
    logic [1:0] character_modes;
    logic [7:0] floating_data;
    logic [7:0] ram [0:131071];
    logic [7:0] rom [0:16383];
    logic [7:0] unused_status,unused_a,unused_x,unused_y,unused_s;
    // ASSUMPTION A2: master power reset is distinct from synchronous CPU reset.
    assign bus_clk=!phi0;
    assign iou_clk=phi0;
    always_ff @(posedge clk14) begin
        if(!power_n) m7<=0;
        else m7<=!m7;
    end
    apple_iie_pal pal(.clk14(clk14),.rst_n(power_n),.m7(m7),.ramen_n(ramen_n),
        .s80vid_n(s80vid_n),.entmg_n(1'b1),.ldps_n(ldps_n),.vid7m(vid7m),
        .phi1(phi1),.phi0(phi0),.q3(q3),.pcas_n(pcas_n),.pras_n(pras_n));
    generate if(EXTERNAL_CPU) begin: external_driver
        assign bus_addr=external_addr;
        assign write_data=external_data;
        assign bus_we=external_we;
        assign pc=0;
        assign fetch=0;
        assign fault=0;
        assign {unused_status,unused_a,unused_x,unused_y,unused_s}=0;
    end else begin: authored_cpu
        mos_6502 cpu(.clk(bus_clk),.rst_n(rst_n),.bus_addr(bus_addr),
            .bus_data_i(bus_data),.bus_data_o(write_data),.bus_we(bus_we),
            .irq_n(1'b1),.nmi_n(1'b1),.fetch_o(fetch),.fault_o(fault),.pc_o(pc),
            .status_o(unused_status),.a_o(unused_a),.x_o(unused_x),.y_o(unused_y),.s_o(unused_s));
    end endgenerate
    apple_iie_mmu mmu(.clk(bus_clk),.rst_n(rst_n),.a(bus_addr),.rw(!bus_we),
        .pras_n(pras_n),.inh_n(1'b1),.dma_n(1'b1),.ra(mmu_ra),
        .ramen_n(ramen_n),.en80_n(en80_n),.romen1_n(romen1_n),.romen2_n(romen2_n),
        .cxxxout(cxxxout),.kbd_n(kbd_n),.md7(mmu_md7),.md7_oe(mmu_oe),.rw245(rw245));
    // ASSUMPTION A1: normalize the cycle-level IOU's decoder sampling window.
    apple_iie_iou iou(.clk(iou_clk),.rst_n(rst_n),.phi0(1'b1),.q3(1'b0),
        .pras_n(pras_n),.rw(!bus_we),.c0xx_n(bus_addr[15:8]!=8'hc0),
        .a6(bus_addr[6]),.vid6(character_modes[0]),.vid7(character_modes[1]),
        .ikstrb(key_down),.iakd(key_down),.kstrb(kstrb),.akd(akd),
        .ra_sense(mmu_ra[6:0]),.ra_o(iou_ra),.h0(h0),.sega(sega),.segb(segb),
        .vc(vc),.gr(video_graphics),.wndw_n(wndw_n),.sync_n(sync_n),
        .clrgat_n(clrgat_n),.ra9_n(ra9_n),.ra10_n(ra10_n),.s80vid_n(s80vid_n),
        .spkr(speaker),.casso(cassette),.an0(an0),.an1(an1),.an2(an2),.an3(an3),
        .md7_oe(iou_oe),.md7(iou_md7));
    always_ff @(negedge clk14) begin
        if(!power_n) begin cpu_column<=0; cpu_row<=0; video_row<=0; end
        else begin
            if(!pras_n) cpu_column<=mmu_ra;
            else begin cpu_row<=mmu_ra; video_row<=iou_ra; end
        end
    end
    apple_iie_address cpu_address(.row_address(cpu_row),.column_address(cpu_column),
                                  .physical_address(physical_addr));
    apple_iie_address display_address(.row_address(video_row),.column_address(iou_ra),
                                      .physical_address(video_addr));
    assign main_selected=!ramen_n;
    assign aux_selected=!en80_n;
    assign debug_data=ram[{debug_aux,debug_addr}];
    assign video_main=ram[{1'b0,video_addr}];
    assign video_aux=ram[{1'b1,video_addr}];
    assign video_visible=!wndw_n;
    assign video_80col=!s80vid_n;
    assign video_line={vc,segb,sega};
    // PAL 80-column load windows select auxiliary then main character data.
    assign character_modes=video_80col && phi0 ? video_aux[7:6] : video_main[7:6];
    assign video_font_main={ra10_n,ra9_n};
    always_ff @(negedge clk14) begin
        if(!power_n) video_font_aux<=0;
        else if(!ldps_n && phi0) video_font_aux<={ra10_n,ra9_n};
    end
    // This is a debug observation of the IOU's C000 strobe, not an extra flag.
    assign keyboard_pending=(bus_addr[15:4]==12'hc00 && iou_oe && iou_md7);
    always_ff @(posedge bus_clk) begin
        if(!rst_n) keyboard<=0;
        else if(key_down) keyboard<=key_data;
        if(rst_n && bus_we && (main_selected || aux_selected))
            ram[{aux_selected,physical_addr}]<=write_data;
    end
    always_ff @(negedge phi0) begin
        if(!rst_n) floating_data<=0;
        else floating_data<=video_main;
    end
    always_comb begin
        bus_data=floating_data;
        if(main_selected || aux_selected) bus_data=ram[{aux_selected,physical_addr}];
        else if(!romen1_n || !romen2_n) bus_data=rom[bus_addr[13:0]];
        else if(!kbd_n) bus_data={1'b0,keyboard};
        else if(bus_addr>=16'hc060 && bus_addr<=16'hc06f) bus_data[7]=0;
        else if(bus_addr>=16'hc100 && bus_addr<16'hd000) bus_data=8'hff;
        if(mmu_oe) bus_data[7]=mmu_md7;
        if(iou_oe) bus_data[7]=iou_md7;
    end
    initial begin
        if(ROM_FILE!="") $readmemh(ROM_FILE,rom);
`ifndef SYNTHESIS
        // ASSUMPTION A3: reproducible simulation RAM; not a power-on guarantee.
        for(int i=0;i<131072;i++) ram[i]=0;
`endif
    end
    // Named observer reduction avoids silently leaving required chip pins open.
    logic unused_pins;
    assign unused_pins=^{phi1,vid7m,cxxxout,rw245,kstrb,akd,h0,sync_n,clrgat_n,
                        ra9_n,ra10_n,an0,an1,an2,an3,unused_status,unused_a,unused_x,
                        unused_y,unused_s,external_addr,external_data,external_we};
endmodule
