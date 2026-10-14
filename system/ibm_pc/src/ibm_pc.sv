`timescale 1ns/1ps
// IBM 5150 motherboard, CGA and diskette-adapter digital wiring.
// RAM/ROM storage and decoded media live across explicit external interfaces.
module ibm_pc (
    input logic clk, rst_n,
    input logic [7:0] mem_rdata,
    output logic [19:0] mem_addr,
    output logic [7:0] mem_wdata,
    output logic mem_write,
    input logic key_valid,
    input logic [7:0] key_code,
    output logic key_ready,
    input logic [1:0] disk_present, disk_protected,
    input logic [3:0] disk_track0,
    input logic media_index, media_header, media_valid, media_end, media_slot,
    input logic [7:0] media_c, media_h, media_r, media_n, media_data,
    output logic media_active, media_writing, media_format,
    output logic [1:0] media_unit,
    output logic media_head,
    output logic [3:0] disk_step, disk_direction,
    output logic media_tx_valid,
    output logic [7:0] media_tx_data,
    output logic sector_begin, sector_end,
    output logic [7:0] sector_c, sector_h, sector_r, sector_n,
    output logic [7:0] cga_mode, cga_palette,
    input logic [4:0] crtc_debug_index,
    output logic [7:0] crtc_debug_data,
    output logic speaker, speaker_enabled,
    output logic halted, fault, retired,
    output logic [127:0] regs,
    output logic [63:0] segs,
    output logic [15:0] ip, flags,
    output logic [2:0] queue_count,
    output logic [63:0] cycle_count, instruction_count,
    output logic [31:0] dma_count, refresh_count, irq_count,
    output logic [7:0] floppy_dor,
    output logic bus_strobe, bus_write, bus_io, bus_intack,
    output logic [19:0] bus_addr,
    output logic [7:0] bus_data, bus_read_data
);
    logic eu_req, eu_write, eu_fetch, eu_first, eu_io, eu_ack, eu_ready;
    logic [19:0] eu_addr;
    logic [1:0] eu_be, eu_seg;
    logic [15:0] eu_wdata, eu_rdata;
    logic locked, redirect, suspend_fetch, inhibit_grant, cpu_hlda, esc;
    logic [5:0] esc_opcode;
    logic [19:0] esc_address;
    logic fetching, hlda, inta_active;
    logic [7:0] read_data;
    logic pic_int, pic_oe, pit_oe, ppi_oe, dma_oe, fdc_oe;
    logic [7:0] pic_data, pit_data, ppi_data, dma_data, fdc_data;
    logic [2:0] pit_out;
    logic [1:0] pit_divider;
    logic [22:0] us_phase;
    logic us_tick;
    logic [7:0] ppi_a, ppi_b, ppi_c, ppi_aoe, ppi_boe, ppi_coe;
    logic [7:0] key_latch;
    logic key_irq, old_pb6;
    logic [19:0] key_clock_low;
    logic [15:0] key_reset_delay;
    logic refresh_pending, old_refresh;
    logic dma_hrq, dma_valid, dma_addr_oe, dma_adstb, dma_aen;
    logic dma_memr_n, dma_memw_n, dma_ior_n, dma_iow_n, dma_eop_n;
    logic [3:0] dma_dack;
    logic [1:0] dma_channel;
    logic [15:0] dma_address;
    logic [3:0] page [0:3];
    logic fdc_irq, fdc_drq, fdc_mfm, fdc_load, fdc_deleted;
    logic pic_select, pit_select, ppi_select, dma_select, cga_select, fdc_select;
    logic io_read, io_write, mem_selected, mem_writable;
    logic [7:0] crtc [0:31];
    logic [4:0] crtc_index;
    logic [16:0] video_clock;
    logic [7:0] video_status, port_c_input;
    logic nmi_enabled;
    logic [2:0] unused_cas, unused_cas_oe;
    logic unused_en, unused_en_oe;
    logic [3:0] drive_ready;
    logic [3:0] fdc_step, fdc_direction;
    logic [63:0] retire_count;

    intel_8086 cpu(.clk(clk),.rst_n(rst_n),.bus_ready_i(eu_ready),.bus_rdata_i(eu_rdata),
        .intr_i(pic_int && !dma_hrq && !hlda),.nmi_i(1'b0),.hold_i(1'b0),.test_n_i(1'b0),
        .bus_req_o(eu_req),.bus_write_o(eu_write),.bus_fetch_o(eu_fetch),.bus_first_o(eu_first),
        .bus_io_o(eu_io),.bus_intack_o(eu_ack),.bus_addr_o(eu_addr),.bus_be_o(eu_be),
        .bus_segment_o(eu_seg),.bus_wdata_o(eu_wdata),.halted_o(halted),.fault_o(fault),
        .retire_o(retired),.lock_o(locked),.hlda_o(cpu_hlda),.redirect_o(redirect),
        .prefetch_suspend_o(suspend_fetch),.arbitration_inhibit_o(inhibit_grant),
        .esc_valid_o(esc),.esc_opcode_o(esc_opcode),.esc_address_o(esc_address),
        .regs_o(regs),.segs_o(segs),.ip_o(ip),.flags_o(flags));
    ibm_pc_bus bus(.clk(clk),.rst_n(rst_n),.eu_req(eu_req),.eu_write(eu_write),
        .eu_fetch(eu_fetch),.eu_intack(eu_ack),.eu_addr(eu_addr),.eu_be(eu_be),
        .eu_wdata(eu_wdata),.eu_io(eu_io),.flush(redirect),.suspend_fetch(suspend_fetch || halted),
        .inhibit_grant(inhibit_grant),.locked(locked),.cs(segs[31:16]),.ip(ip),
        .eu_ready(eu_ready),.eu_rdata(eu_rdata),.hold_req(dma_hrq),.hlda(hlda),
        .strobe(bus_strobe),.writing(bus_write),.io(bus_io),.intack(bus_intack),.inta_active(inta_active),
        .fetching(fetching),.address(bus_addr),.wdata(bus_data),.rdata(read_data),.queue_count(queue_count));
    assign io_read=bus_strobe && bus_io && !bus_write;
    assign io_write=bus_strobe && bus_io && bus_write;
    // IBM planar decodes A9:A5; A4 and unused lower address bits are aliases.
    assign dma_select=bus_io && bus_addr[9:4]==0;
    assign pic_select=bus_io && bus_addr[9:5]==1;
    assign pit_select=bus_io && bus_addr[9:5]==2;
    assign ppi_select=bus_io && bus_addr[9:5]==3;
    assign cga_select=bus_io && bus_addr[9:4]==6'h3d;
    assign fdc_select=!hlda && bus_io && bus_addr[9:1]==9'h1fa;
    // IBM page latches: port 81 -> channel 2, 82 -> channel 3, 83 -> channel 1.
    assign mem_addr=hlda ? {page[dma_channel==0 ? 2'd0:dma_channel==1 ? 2'd3:
        dma_channel==2 ? 2'd1:2'd2],dma_address}:bus_addr;
    assign mem_selected=mem_addr<20'h10000 || mem_addr[19:15]==5'b10111 || mem_addr>=20'hf6000;
    assign mem_writable=mem_addr<20'h10000 || mem_addr[19:15]==5'b10111;
    assign mem_wdata=hlda ? fdc_data:bus_data;
    assign mem_write=rst_n && mem_writable && (hlda ? dma_valid && !dma_memw_n :
        bus_strobe && !bus_io && !bus_intack && bus_write);
    assign key_ready=!key_irq && !ppi_b[7] && ppi_b[6] && key_reset_delay==0;
    assign speaker=ppi_b[1] && pit_out[2];
    assign speaker_enabled=ppi_b[1] && ppi_b[0];
    assign us_tick=us_phase>=23'd3772727;
    // The PC adapter has no drive READY input: the controller sees READY high.
    // Disk presence/motor selection affect recorded media, not this input pin.
    assign drive_ready=4'b1111;
    // The IBM adapter's DOR selects the physical drive; the FDC's US outputs
    // identify command status and do not replace that external select latch.
    assign disk_step=(|fdc_step) ? (4'b0001<<floppy_dor[1:0]):4'b0;
    assign disk_direction={4{|(fdc_step & fdc_direction)}};
    // ASSUMPTION A3: static storage retains bytes; real refresh DMA still runs.
    intel_8237 dma(.clk(clk),.rst_n(rst_n),.cs_n(!dma_select),
        .ior_n(!io_read),.iow_n(!io_write),.reg_addr(bus_addr[3:0]),.data_i(bus_data),
        .data_o(dma_data),.data_oe(dma_oe),.dreq({1'b0,fdc_drq && floppy_dor[3],1'b0,refresh_pending}),
        .dack(dma_dack),.hrq(dma_hrq),.hlda(hlda),.ready(1'b1),.eop_n(1'b1),
        .eop_out_n(dma_eop_n),.dma_addr(dma_address),.addr_oe(dma_addr_oe),
        .adstb(dma_adstb),.aen(dma_aen),.memr_n(dma_memr_n),.memw_n(dma_memw_n),
        .dma_ior_n(dma_ior_n),.dma_iow_n(dma_iow_n),.transfer_valid(dma_valid),.transfer_channel(dma_channel));
    intel_8259 pic(.clk(clk),.rst_n(rst_n),.cs_n(!pic_select),.rd_n(!io_read),
        .wr_n(!io_write),.a0(bus_addr[0]),.data_i(bus_data),.data_o(pic_data),.data_oe(pic_oe),
        .ir({1'b0,fdc_irq && floppy_dor[3],4'b0,key_irq,pit_out[0]}),.int_o(pic_int),
        .inta_n(!inta_active),.cas_i(3'b0),.cas_o(unused_cas),
        .cas_oe(unused_cas_oe),.sp_n_i(1'b1),.en_n_o(unused_en),.en_n_oe(unused_en_oe));
    intel_8253_8254 #(.IS_8254(0)) pit(.clk(clk),.rst_n(rst_n),.cs_n(!pit_select),
        .rd_n(!io_read),.wr_n(!io_write),.addr(bus_addr[1:0]),.data_i(bus_data),
        .data_o(pit_data),.data_oe(pit_oe),.counter_clk_i({3{pit_divider[1]}}),
        .gate_i({ppi_b[0],2'b11}),.out_o(pit_out));
    // Cassette OUT is timer 2, independent of the speaker data-enable bit.
    // With no external tape, the board's diagnostic wrap reads that waveform.
    assign port_c_input={2'b0,pit_out[2],pit_out[2],4'b0};
    intel_8255 ppi(.clk(clk),.reset(!rst_n),.cs_n(!ppi_select),.rd_n(!io_read),
        .wr_n(!io_write),.addr(bus_addr[1:0]),.data_i(bus_data),.data_o(ppi_data),.data_oe(ppi_oe),
        .port_a_i(ppi_b[7] ? 8'h6f:key_latch),.port_a_o(ppi_a),.port_a_oe(ppi_aoe),
        .port_b_i(8'b0),.port_b_o(ppi_b),.port_b_oe(ppi_boe),
        .port_c_i(port_c_input),.port_c_o(ppi_c),.port_c_oe(ppi_coe));
    // ASSUMPTION A2: external decoded media, with controller/DMA in real RTL.
    intel_8272 #(.RQM_DELAY_US(24),.MS_US(2000),.CLOCK_SCALE(2)) fdc(
        .clk(clk),.rst_n(rst_n && floppy_dor[2]),.us_tick(us_tick),
        .cs_n(!fdc_select),.rd_n(hlda ? dma_ior_n:!io_read),
        .wr_n(hlda ? dma_iow_n:!io_write),.dack_n(dma_dack[2]),.a0(bus_addr[0]),
        .tc(!dma_eop_n && dma_channel==2),.db_in(hlda ? mem_rdata:bus_data),
        .db_out(fdc_data),.db_oe(fdc_oe),.irq(fdc_irq),.drq(fdc_drq),
        .ready(drive_ready),.write_protect({4{floppy_dor[1] ? 1'b0:disk_protected[floppy_dor[0]]}}),
        .track0({4{disk_track0[floppy_dor[1:0]]}}),
        .two_sided(4'b0),.fault(4'b0),.step(fdc_step),.direction(fdc_direction),
        .unit(media_unit),.head(media_head),.mfm(fdc_mfm),.head_load(fdc_load),
        .media_active(media_active),.media_write(media_writing),.media_format(media_format),
        .index_pulse(media_index),.header_valid(media_header),.header_c(media_c),.header_h(media_h),
        .header_r(media_r),.header_n(media_n),.header_deleted(1'b0),.header_missing_data(1'b0),
        .header_crc_error(1'b0),.media_byte_valid(media_valid),.media_byte(media_data),
        .media_end(media_end),.media_crc_error(1'b0),.write_slot(media_slot),
        .sector_begin(sector_begin),.sector_end(sector_end),.tx_valid(media_tx_valid),
        .tx_byte(media_tx_data),.sector_c(sector_c),.sector_h(sector_h),.sector_r(sector_r),
        .sector_n(sector_n),.sector_deleted(fdc_deleted));
    assign crtc_debug_data=crtc[crtc_debug_index];
    assign bus_read_data=read_data;
    // Include the currently visible retirement pulse in the debug snapshot.
    assign instruction_count=retire_count+{63'b0,retired};
    assign video_status={4'b0,video_clock>=17'd73000,2'b0,(video_clock%17'd303)>=17'd240};
    always_comb begin
        read_data=8'hff;
        if(bus_intack) read_data=pic_data;
        else if(!bus_io) read_data=mem_selected ? mem_rdata:8'hff;
        else if(pic_oe) read_data=pic_data;
        else if(pit_oe) read_data=pit_data;
        else if(ppi_oe) read_data=ppi_data;
        else if(dma_oe) read_data=dma_data;
        else if(fdc_oe) read_data=fdc_data;
        else if(cga_select) begin
            if(bus_addr[3:1]<4 && bus_addr[0]) read_data=crtc[crtc_index];
            else if(bus_addr[3:0]==10) read_data=video_status;
        end
    end
    always_ff @(posedge clk) begin
        if(!rst_n) begin
            pit_divider<=0; us_phase<=0; cycle_count<=0; retire_count<=0;
            dma_count<=0; refresh_count<=0; irq_count<=0;
            floppy_dor<=0; cga_mode<=0; cga_palette<=0; crtc_index<=0;
            key_latch<=0; key_irq<=0; old_pb6<=0; key_clock_low<=0; key_reset_delay<=0;
            refresh_pending<=0; old_refresh<=0; video_clock<=0; nmi_enabled<=0;
            for(integer i=0;i<4;i=i+1) page[i]<=0;
            for(integer i=0;i<32;i=i+1) crtc[i]<=0;
        end else begin
            cycle_count<=cycle_count+64'd1;
            if(retired) retire_count<=retire_count+64'd1;
            pit_divider<=pit_divider+2'd1;
            us_phase<=us_tick ? us_phase-23'd3772727:us_phase+23'd1000000;
            video_clock<=video_clock==17'd79544 ? 17'b0:video_clock+17'd1;
            if(dma_valid) begin
                dma_count<=dma_count+32'd1;
                if(dma_channel==0) refresh_count<=refresh_count+32'd1;
            end
            if(bus_strobe && bus_intack) irq_count<=irq_count+32'd1;
            old_refresh<=pit_out[1];
            if(pit_out[1] && !old_refresh) refresh_pending<=1;
            if(!dma_dack[0]) refresh_pending<=0;
            // ASSUMPTION A4: external keyboard presents completed scan codes.
            old_pb6<=ppi_b[6];
            if(!ppi_b[6] && key_clock_low!=20'hfffff) key_clock_low<=key_clock_low+20'd1;
            if(ppi_b[6]) key_clock_low<=0;
            if(ppi_b[6] && !old_pb6 && key_clock_low>=20'd100000) key_reset_delay<=1000;
            if(key_reset_delay!=0) begin
                key_reset_delay<=key_reset_delay-16'd1;
                if(key_reset_delay==1) begin key_latch<=8'haa; key_irq<=1; end
            end
            if(ppi_b[7]) begin key_latch<=0; key_irq<=0; end
            else if(key_valid && key_ready) begin key_latch<=key_code; key_irq<=1; end
            if(io_write && bus_addr[9:5]==4) page[bus_addr[1:0]]<=bus_data[3:0];
            if(io_write && bus_addr[9:5]==5) nmi_enabled<=bus_data[7];
            if(io_write && bus_addr[9:0]==10'h3f2) floppy_dor<=bus_data;
            if(io_write && cga_select) begin
                if(bus_addr[3:1]<4) begin
                    if(!bus_addr[0]) crtc_index<=bus_data[4:0];
                    else crtc[crtc_index]<=bus_data;
                end else if(bus_addr[3:0]==8) cga_mode<=bus_data;
                else if(bus_addr[3:0]==9) cga_palette<=bus_data;
            end
        end
    end
    logic unused_signals;
    assign unused_signals=&{1'b0,eu_first,eu_seg,cpu_hlda,esc,esc_opcode,esc_address,fetching,
        ppi_a,ppi_c,ppi_aoe,ppi_boe,ppi_coe,dma_addr_oe,dma_adstb,dma_aen,dma_memr_n,
        fdc_mfm,fdc_load,fdc_deleted,nmi_enabled,unused_cas,unused_cas_oe,unused_en,unused_en_oe,
        ppi_b[5:2],dma_dack[3],dma_dack[1],disk_present};
endmodule
