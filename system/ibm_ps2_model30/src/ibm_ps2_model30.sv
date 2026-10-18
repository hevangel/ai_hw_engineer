`timescale 1ns/1ps
module ibm_ps2_model30 (
    input logic clk,dma_clk,rst_n,cold_rst_n,
    input logic nv_write,
    input logic [4:0] nv_address,
    input logic [7:0] nv_data,
    output logic [7:0] nv_read,
    input logic fixed_present,
    input logic [7:0] hd_media_rdata,
    input logic hd_check_valid,
    output logic [16:0] hd_media_sector,
    output logic [9:0] hd_media_address,
    output logic hd_media_read,hd_media_write,hd_busy,
    output logic [7:0] hd_media_wdata,
    input logic [15:0] mem_rdata,
    output logic [19:0] mem_addr,
    output logic [15:0] mem_wdata,
    output logic [1:0] mem_write,
    input logic key_valid,mouse_valid,
    input logic [7:0] key_code,mouse_code,
    output logic key_ready,mouse_ready,
    output logic [1:0] scan_set,
    input logic [1:0] disk_present,disk_protected,disk_changed,
    input logic [3:0] disk_track0,
    input logic media_index,media_header,media_valid,media_end,media_slot,
    input logic [7:0] media_c,media_h,media_r,media_n,media_data,
    output logic media_active,media_writing,media_format,
    output logic [1:0] media_unit,
    output logic media_head,
    output logic [3:0] disk_step,disk_direction,
    output logic media_tx_valid,
    output logic [7:0] media_tx_data,
    output logic sector_begin,sector_end,
    output logic [7:0] sector_c,sector_h,sector_r,sector_n,
    output logic [7:0] cga_mode,cga_palette,
    output logic [1:0] graphics_mode,
    input logic [5:0] crtc_debug_index,
    output logic [7:0] crtc_debug_data,
    input logic [9:0] dac_debug_index,
    output logic [5:0] dac_debug_data,
    output logic [15:0] font_source,
    input logic [7:0] font_read,
    output logic font_write,
    output logic [12:0] font_address,
    output logic [7:0] font_data,
    output logic speaker,speaker_enabled,
    output logic halted,fault,retired,
    output logic [127:0] regs,
    output logic [63:0] segs,
    output logic [15:0] ip,flags,
    output logic [2:0] queue_count,
    output logic [63:0] cycle_count,instruction_count,
    output logic [31:0] dma_count,refresh_count,irq_count,
    output logic [7:0] floppy_dor,
    output logic floppy_250,
    output logic bus_strobe,bus_write,bus_io,bus_intack,
    output logic [19:0] bus_addr,
    output logic [7:0] bus_data,bus_read_data
);
    logic [15:0] ad_out,ad_in;
    logic [3:0] address_high;
    logic bhe_n,owned,ready;
    logic [2:0] phase,status;
    logic [1:0] rqgt_out,rqgt_enable,rqgt_input;
    logic [1:0] lanes;
    logic inta_active;
    logic ad_oe,address_oe,bhe_oe,rd_n,wr_n,m_io,dt_r,den_n,ale,inta_n,hlda,lock_n;
    logic [1:0] qs;
    logic pic_int,pic_oe,pit_oe,dma_oe,fdc_oe;
    logic [7:0] pic_data,pit_data,dma_data,fdc_data,hdc_data,hdc_dma_data;
    logic hdc_select,hdc_irq,hdc_drq;
    logic dma_io_ready,dma_io_active,dma_io_read,dma_io_write;
    logic [15:0] dma_io_response;
    logic [3:0] dma_io_address;
    logic [7:0] dma_io_data;
    logic [7:0] key_data,key_diagnostic;
    logic key_irq,key_nmi,rtc_irq,rtc_mask,video_irq;
    logic [7:0] rtc_data,mcga_data;
    logic [7:0] port61,planar,ram_control,icw1,icw2;
    logic expect_icw2;
    logic [7:0] uart[0:7];
    logic [7:0] uart_dll,uart_dlm,uart_receive;
    logic uart_full,uart_irq,uart_tx_irq;
    logic [7:0] uart_modem;
    logic [3:0] uart_delta;
    logic [7:0] lpt_data,lpt_control;
    logic io_read,io_write,pic_select,pit_select,dma_select,fdc_select,video_select,rtc_select;
    logic [2:0] pit_out;
    logic pit_clock,refresh_clock;
    logic [23:0] pit_phase;
    logic [2:0] us_divider;
    logic us_tick;
    logic [6:0] refresh_divider;
    logic refresh_pending;
    logic [3:0] grant_delay;
    typedef enum logic [2:0] {FREE,REQUEST,WAIT_GRANT,GRANTED,RELEASE,COOLDOWN} ownership_t;
    ownership_t ownership;
    logic bus_owned;
    logic dma_hrq,dma_valid,dma_addr_oe,dma_adstb,dma_aen;
    logic dma_memr_n,dma_memw_n,dma_ior_n,dma_iow_n,dma_eop_n;
    logic [3:0] dma_dack;
    logic [1:0] dma_channel;
    logic [15:0] dma_address;
    logic [3:0] page[0:3];
    logic [3:0] fdc_step,fdc_direction;
    logic [2:1] floppy_ccr;
    assign floppy_250=floppy_ccr[1];
    logic floppy_step_latch,floppy_direction,floppy_read_latch,floppy_write_latch,floppy_enable_latch;
    logic selected_motor;
    logic fdc_irq,fdc_drq,fdc_mfm,fdc_load,fdc_deleted;
    logic [2:0] unused_cas,unused_cas_oe;
    logic unused_en,unused_en_oe;
    logic [19:0] mapped_address;
    logic ram_selected,video_selected,rom_selected;
    logic [15:0] memory_read;
    logic [63:0] retire_count;
    logic [15:0] cpu_ax,cpu_cx,cpu_dx,cpu_bx,cpu_sp,cpu_bp,cpu_si,cpu_di;
    logic [15:0] cpu_es,cpu_cs,cpu_ss,cpu_ds;
    assign {cpu_di,cpu_si,cpu_bp,cpu_sp,cpu_bx,cpu_dx,cpu_cx,cpu_ax}=regs;
    assign {cpu_ds,cpu_ss,cpu_cs,cpu_es}=segs;
    assign bus_owned=ownership==GRANTED;
    // A single low pulse requests the bus; the CPU's output pulse grants it.
    // Release is another low pulse on the same maximum-mode RQ/GT line.
    assign rqgt_input=ownership==REQUEST || ownership==RELEASE ? 2'b10:2'b11;
    intel_8086_chip cpu(.clk(clk),.reset_i(!rst_n),.min_mode_i(1'b0),.ready_i(ready),
        .intr_i(pic_int && ownership==FREE),.nmi_i(key_nmi),.test_n_i(1'b0),.hold_i(1'b0),
        .rqgt_n_i(rqgt_input),.ad_i(ad_in),.ad_o(ad_out),.ad_oe_o(ad_oe),
        .address_status_o(address_high),.address_status_oe_o(address_oe),
        .bhe_status_n_o(bhe_n),.bhe_oe_o(bhe_oe),.rd_n_o(rd_n),.wr_n_o(wr_n),
        .m_io_o(m_io),.dt_r_o(dt_r),.den_n_o(den_n),.ale_o(ale),.inta_n_o(inta_n),
        .control_oe_o(owned),.hlda_o(hlda),.rqgt_n_o(rqgt_out),.rqgt_oe_o(rqgt_enable),
        .status_o(status),.phase_o(phase),.qs_o(qs),.lock_n_o(lock_n),
        .halted_o(halted),.fault_o(fault),.retire_o(retired),.regs_o(regs),.segs_o(segs),
        .ip_o(ip),.flags_o(flags),.queue_count_o(queue_count));
    model30_bus bus(.clk(clk),.rst_n(rst_n),.phase(phase),.status(status),
        .ad_out(ad_out),.address_high(address_high),.bhe_n(bhe_n),.owned(owned),
        .dma_ready(dma_io_ready),.dma_response(dma_io_response),
        .ready(ready),.ad_in(ad_in),.address(bus_addr),.lanes(lanes),
        .writing(bus_write),.io(bus_io),.intack(bus_intack),.strobe(bus_strobe),
        .inta_active(inta_active),.byte_data(bus_data),.byte_read(bus_read_data),.memory_read(memory_read));
    assign io_read=bus_strobe && bus_io && !bus_write;
    assign io_write=bus_strobe && bus_io && bus_write;
    assign dma_select=bus_io && bus_addr[15:5]==0;
    assign pic_select=bus_io && bus_addr[15:5]==1;
    assign pit_select=bus_io && bus_addr[15:5]==2;
    assign fdc_select=planar[3] && !bus_owned && bus_io && bus_addr[15:1]==15'h1fa;
    assign video_select=planar[2] && bus_io && bus_addr[15:5]==11'h1e;
    assign hdc_select=fixed_present && planar[0] && !bus_owned && bus_io && bus_addr[15:3]==13'h064;
    assign rtc_select=bus_io && (bus_addr[15:4]==12'h00b || bus_addr[15:4]==12'h00e);
    assign us_tick=us_divider==7;
    assign selected_motor=!floppy_dor[1] && (floppy_dor[0] ? floppy_dor[5]:floppy_dor[4]);
    assign speaker=port61[1] && pit_out[2];
    assign speaker_enabled=port61[1] && port61[0];
    assign uart_modem=uart[4][4] ? {uart[4][3],uart[4][2],uart[4][0],uart[4][1],4'b0}:8'h00;
    assign uart_irq=planar[4] && uart[4][3] && ((uart_full && uart[1][0]) ||
        (uart_tx_irq && uart[1][1]) || (|uart_delta && uart[1][3]));
    assign instruction_count=retire_count+{63'b0,retired};
    // RAM controls disable individual 64K regions; remap excludes the failed
    // lower 128K and moves physical 20000..9FFFF to logical 00000..7FFFF.
    assign mapped_address=bus_owned ? {page[dma_channel],dma_address}:bus_addr;
    assign ram_selected=mapped_address<20'ha0000 &&
        !(ram_control[0] && mapped_address>=20'h80000) &&
        !(mapped_address>=20'h40000 && ram_control[3'(mapped_address[19:16]-4'd3)]);
    assign video_selected=planar[2] && ((graphics_mode==0 &&
        (mapped_address[19:16]==4'ha || mapped_address[19:15]==5'b10111)) ||
        (graphics_mode==1 && mapped_address[19:15]==5'b10111) ||
        (graphics_mode>=2 && mapped_address[19:16]==4'ha));
    assign rom_selected=mapped_address[19:16]==4'hf;
    assign mem_addr=ram_selected && ram_control[0] ? mapped_address+20'h20000 :
        video_selected && mapped_address[19:15]==5'b10111 ?
        {4'ha,1'b1,mapped_address[14:0]}:mapped_address;
    assign memory_read=ram_selected || video_selected || rom_selected ? mem_rdata:16'hffff;
    assign mem_wdata=bus_owned ? (dma_channel==3 ? {hdc_dma_data,hdc_dma_data}:{fdc_data,fdc_data}):ad_out;
    assign mem_write=(!rst_n || !(ram_selected || video_selected)) ? 2'b0 :
        bus_owned ? ((dma_valid && !dma_memw_n && !dma_clk) ? (mem_addr[0] ? 2'b10:2'b01):2'b0) :
        (bus_strobe && !bus_io && !bus_intack && bus_write ? lanes:2'b0);
    model30_dma_bridge dma_bridge(.clk(clk),.dma_clk(dma_clk),.rst_n(rst_n),
        .phase(phase),.selected(dma_select),.writing(bus_write),.address(bus_addr),
        .lanes(lanes),.wdata(ad_out),.ready(dma_io_ready),.response(dma_io_response),
        .active(dma_io_active),.device_read(dma_io_read),.device_write(dma_io_write),
        .device_address(dma_io_address),.device_data(dma_io_data),.device_response(dma_data));
    intel_8237 dma(.clk(dma_clk),.rst_n(rst_n),.cs_n(!dma_io_active),
        .ior_n(!dma_io_read),.iow_n(!dma_io_write),.reg_addr(dma_io_address),.data_i(dma_io_data),
        .data_o(dma_data),.data_oe(dma_oe),.dreq({hdc_drq,fdc_drq && floppy_dor[3],2'b0}),
        .dack(dma_dack),.hrq(dma_hrq),.hlda(bus_owned),.ready(1'b1),.eop_n(1'b1),
        .eop_out_n(dma_eop_n),.dma_addr(dma_address),.addr_oe(dma_addr_oe),
        .adstb(dma_adstb),.aen(dma_aen),.memr_n(dma_memr_n),.memw_n(dma_memw_n),
        .dma_ior_n(dma_ior_n),.dma_iow_n(dma_iow_n),.transfer_valid(dma_valid),.transfer_channel(dma_channel));
    intel_8259 pic(.clk(clk),.rst_n(rst_n),.cs_n(!pic_select),.rd_n(!io_read),
        .wr_n(!io_write),.a0(bus_addr[0]),.data_i(bus_data),.data_o(pic_data),.data_oe(pic_oe),
        .ir(key_diagnostic|{1'b0,fdc_irq && floppy_dor[3],hdc_irq,uart_irq,1'b0,video_irq,key_irq || rtc_irq && !rtc_mask,pit_out[0]}),
        .int_o(pic_int),.inta_n(!inta_active),.cas_i(3'b0),.cas_o(unused_cas),
        .cas_oe(unused_cas_oe),.sp_n_i(1'b1),.en_n_o(unused_en),.en_n_oe(unused_en_oe));
    intel_8253_8254 #(.IS_8254(0)) pit(.clk(clk),.rst_n(rst_n),.cs_n(!pit_select),
        .rd_n(!io_read),.wr_n(!io_write),.addr(bus_addr[1:0]),.data_i(bus_data),
        .data_o(pit_data),.data_oe(pit_oe),.counter_clk_i({pit_clock,refresh_clock,pit_clock}),
        .gate_i({port61[0],2'b11}),.out_o(pit_out));
    model30_keyboard keyboard(.clk(clk),.rst_n(rst_n),.read_strobe(io_read && bus_addr[15:8]==0),
        .write_strobe(io_write && bus_addr[15:8]==0),
        .address(bus_addr[7:0]),.wdata(bus_data),.icw1(icw1),.icw2(icw2),.rdata(key_data),
        .diagnostic_irqs(key_diagnostic),.irq(key_irq),.nmi(key_nmi),
        .key_valid(key_valid),.key_code(key_code),.key_ready(key_ready),.scan_set(scan_set),
        .mouse_valid(mouse_valid),.mouse_code(mouse_code),.mouse_ready(mouse_ready),.rtc_irq(rtc_irq));
    model30_rtc rtc(.clk(clk),.cold_rst_n(cold_rst_n),.us_tick(us_tick),.selected(rtc_select),
        .reading(io_read),.writing(io_write),.address({bus_addr[7:4]==4'hb,bus_addr[3:0]}),
        .wdata(bus_data),.rdata(rtc_data),.irq(rtc_irq),.nv_write(nv_write && !rst_n),
        .nv_address(nv_address),.nv_data(nv_data),.nv_read(nv_read));
    model30_mcga video(.clk(clk),.rst_n(rst_n),.selected(video_select),.read_strobe(io_read),
        .write_strobe(io_write),.address(bus_addr[4:0]),.wdata(bus_data),.rdata(mcga_data),
        .mode(cga_mode),.border(cga_palette),.graphics_mode(graphics_mode),.video_irq(video_irq),
        .debug_index(crtc_debug_index),.debug_crtc(crtc_debug_data),
        .debug_dac_index(dac_debug_index),.debug_dac(dac_debug_data),
        .font_source(font_source),.font_read(font_read),.font_write(font_write),
        .font_address(font_address),.font_data(font_data));
    assign disk_step=(|fdc_step) ? (4'b0001<<floppy_dor[1:0]):4'b0;
    assign disk_direction={4{|(fdc_step&fdc_direction)}};
    intel_8272 #(.RQM_DELAY_US(24),.MS_US(2000),.CLOCK_SCALE(2)) fdc(
        .clk(clk),.rst_n(rst_n && floppy_dor[2]),.us_tick(us_tick),
        .cs_n(!fdc_select),.rd_n(bus_owned ? dma_ior_n:!io_read),
        .wr_n(bus_owned ? dma_iow_n:!io_write),.dack_n(dma_dack[2]),.a0(bus_addr[0]),
        .tc(!dma_eop_n && dma_channel==2),.db_in(bus_owned ? (mem_addr[0] ? mem_rdata[15:8]:mem_rdata[7:0]):bus_data),
        .db_out(fdc_data),.db_oe(fdc_oe),.irq(fdc_irq),.drq(fdc_drq),.ready(4'b1111),
        .write_protect({4{floppy_dor[1] ? 1'b0:disk_protected[floppy_dor[0]]}}),
        .track0({4{disk_track0[floppy_dor[1:0]]}}),.two_sided(4'b1111),.fault(4'b0),
        .step(fdc_step),.direction(fdc_direction),.unit(media_unit),.head(media_head),
        .mfm(fdc_mfm),.head_load(fdc_load),.media_active(media_active),.media_write(media_writing),.media_format(media_format),
        .index_pulse(media_index),.header_valid(media_header),.header_c(media_c),.header_h(media_h),
        .header_r(media_r),.header_n(media_n),.header_deleted(1'b0),.header_missing_data(1'b0),
        .header_crc_error(1'b0),.media_byte_valid(media_valid),.media_byte(media_data),
        .media_end(media_end),.media_crc_error(1'b0),.write_slot(media_slot),
        .sector_begin(sector_begin),.sector_end(sector_end),.tx_valid(media_tx_valid),
        .tx_byte(media_tx_data),.sector_c(sector_c),.sector_h(sector_h),.sector_r(sector_r),.sector_n(sector_n),.sector_deleted(fdc_deleted));
    model30_fixed_disk fixed_disk(.clk(clk),.rst_n(rst_n),.cold_rst_n(cold_rst_n),
        .present(fixed_present && planar[0]),.selected(hdc_select),.reading(io_read),.writing(io_write),
        .address(bus_addr[2:0]),.wdata(bus_data),.rdata(hdc_data),
        .dma_dack_n(dma_dack[3]),.dma_ior_n(bus_owned ? dma_ior_n:1'b1),
        .dma_iow_n(bus_owned ? dma_iow_n:1'b1),.terminal_count(!dma_eop_n && dma_channel==3),
        .dma_wdata(mem_addr[0] ? mem_rdata[15:8]:mem_rdata[7:0]),.dma_rdata(hdc_dma_data),
        .drq(hdc_drq),.irq(hdc_irq),.busy(hd_busy),.media_sector(hd_media_sector),
        .media_address(hd_media_address),.media_rdata(hd_media_rdata),.media_check_valid(hd_check_valid),
        .media_read(hd_media_read),.media_write(hd_media_write),.media_wdata(hd_media_wdata));
    always_comb begin
        bus_read_data=8'hff;
        if(bus_intack) bus_read_data=pic_data[2:0]==1 ? 8'h71:pic_data;
        else if(pic_oe) bus_read_data=pic_data;
        else if(pit_oe) bus_read_data=pit_data;
        else if(dma_oe) bus_read_data=dma_data;
        else if(fdc_oe) bus_read_data=fdc_data;
        else if(hdc_select) bus_read_data=hdc_data;
        else if(video_select) bus_read_data=mcga_data;
        else if(rtc_select) bus_read_data=rtc_data;
        else if(bus_addr[15:4]==6) case(bus_addr[3:0])
            4'h1:bus_read_data=port61;
            4'h2:bus_read_data={2'b0,pit_out[2],2'b0,!fixed_present,2'b01};
            4'h5:bus_read_data=planar;
            4'hb:bus_read_data=ram_control;
            default:bus_read_data=key_data;
        endcase
        else if(bus_addr[15:0]==16'ha0) bus_read_data=key_data;
        else if(bus_addr[15:0]==16'ha1) bus_read_data={7'b1111111,rtc_mask};
        else if(bus_addr[15:0]==16'h81) bus_read_data={4'hf,page[2]};
        else if(bus_addr[15:0]==16'h82) bus_read_data={4'hf,page[3]};
        else if(bus_addr[15:0]==16'h83) bus_read_data={4'hf,page[1]};
        else if(bus_addr[15:0]==16'h87) bus_read_data={4'hf,page[0]};
        else if(bus_addr[15:3]==13'h07f && planar[4]) case(bus_addr[2:0])
            3'd0:bus_read_data=uart[3][7] ? uart_dll:uart_receive;
            3'd1:bus_read_data=uart[3][7] ? uart_dlm:uart[1];
            3'd2:bus_read_data=uart_full && uart[1][0] ? 8'h04 : uart_tx_irq && uart[1][1] ? 8'h02 :
                |uart_delta && uart[1][3] ? 8'h00:8'h01;
            3'd5:bus_read_data={7'b0110000,uart_full};
            3'd6:bus_read_data=uart_modem|{4'b0,uart_delta};
            default:bus_read_data=uart[bus_addr[2:0]];
        endcase
        else if(bus_addr[15:3]==13'h06f && planar[1]) case(bus_addr[2:0])
            3'd0:bus_read_data=lpt_data;
            3'd1:bus_read_data=8'hd8;
            3'd2:bus_read_data=lpt_control|8'he0;
            default:begin end
        endcase
        else if(bus_addr[15:0]==16'h3f0 && planar[3]) bus_read_data={fdc_irq,fdc_drq,floppy_step_latch,
            disk_track0[floppy_dor[1:0]],!media_head,media_index,
            (!floppy_dor[1] && disk_protected[floppy_dor[0]]),!floppy_direction};
        else if(bus_addr[15:0]==16'h3f1 && planar[3]) bus_read_data={(!disk_present[1]),
            floppy_dor[1:0]!=1,floppy_dor[1:0]!=0,floppy_write_latch,floppy_read_latch,floppy_enable_latch,
            floppy_dor[1:0]!=3,floppy_dor[1:0]!=2};
        // IBM TR pp.1-80..1-82: active-low disk change, unlike PC/AT DIR.
        // The documented diagnostic latches clear on the DIR read (A5,
        // corroborated by independent 86Box FDC and original POST F000:0EEE).
        else if(bus_addr[15:0]==16'h3f7 && planar[3]) bus_read_data=selected_motor ?
            {(!disk_changed[floppy_dor[0]] && disk_present[floppy_dor[0]]),3'b0,floppy_dor[3],floppy_ccr,1'b0}:8'h00;
    end
    always_ff @(posedge clk) begin
        if(!rst_n) begin
            cycle_count<=0;retire_count<=0;dma_count<=0;refresh_count<=0;irq_count<=0;
            port61<=0;planar<=8'h9f;ram_control<=0;rtc_mask<=1;icw1<=0;icw2<=0;expect_icw2<=0;
            floppy_dor<=0;floppy_ccr<=0;floppy_step_latch<=0;floppy_direction<=0;
            floppy_read_latch<=0;floppy_write_latch<=0;floppy_enable_latch<=0;
            pit_phase<=0;pit_clock<=0;us_divider<=0;
            refresh_divider<=0;refresh_clock<=0;refresh_pending<=0;ownership<=FREE;grant_delay<=0;
            uart_dll<=0;uart_dlm<=0;uart_receive<=0;uart_full<=0;uart_tx_irq<=0;uart_delta<=0;lpt_data<=0;lpt_control<=0;
            for(integer i=0;i<4;i=i+1) page[i]<=0;
            for(integer i=0;i<8;i=i+1) uart[i]<=0;
        end else begin
            cycle_count<=cycle_count+64'd1;if(retired) retire_count<=retire_count+64'd1;
            us_divider<=us_divider+3'd1;
            if(pit_phase>=24'd5613636) begin pit_phase<=pit_phase-24'd5613636;pit_clock<=!pit_clock;end
            else pit_phase<=pit_phase+24'd2386364;
            refresh_divider<=refresh_divider==124 ? 7'b0:refresh_divider+7'd1;
            if(refresh_divider==124) refresh_pending<=1;
            refresh_clock<=0;
            case(ownership)
                FREE:if(dma_hrq || refresh_pending) ownership<=REQUEST;
                REQUEST:ownership<=WAIT_GRANT;
                WAIT_GRANT:if(rqgt_enable[0] && !rqgt_out[0]) begin ownership<=GRANTED;grant_delay<=9;end
                GRANTED:begin
                    if(grant_delay!=0) begin
                        grant_delay<=grant_delay-4'd1;
                        if(grant_delay==1 && refresh_pending) begin
                            refresh_pending<=0;refresh_clock<=1;refresh_count<=refresh_count+32'd1;
                        end
                    end else if(!dma_hrq && refresh_pending) grant_delay<=9;
                    else if(!owned && !dma_hrq && !refresh_pending) ownership<=RELEASE;
                end
                RELEASE:begin ownership<=COOLDOWN;grant_delay<=3;end
                COOLDOWN:if(grant_delay!=0) grant_delay<=grant_delay-4'd1;else ownership<=FREE;
                default:ownership<=FREE;
            endcase
            if(dma_valid && !dma_clk) dma_count<=dma_count+32'd1;
            if(bus_strobe && bus_intack) irq_count<=irq_count+32'd1;
            if(|fdc_step) begin floppy_step_latch<=1;floppy_direction<=|(fdc_step&fdc_direction);end
            if(media_valid) floppy_read_latch<=1;
            if(media_tx_valid) floppy_write_latch<=1;
            if(media_writing) floppy_enable_latch<=1;
            if(io_read && bus_addr[15:0]==16'h3f7) begin
                floppy_step_latch<=0;floppy_read_latch<=0;floppy_write_latch<=0;floppy_enable_latch<=0;
            end
            if(io_write) begin
                if(pic_select && !bus_addr[0] && bus_data[4]) begin icw1<=bus_data;expect_icw2<=1;end
                else if(pic_select && bus_addr[0] && expect_icw2) begin icw2<=bus_data;expect_icw2<=0;end
                case(bus_addr[15:0])
                    16'h61:port61<=bus_data&8'h33;
                    16'h65:planar<=bus_data&8'h9f;
                    16'h6b:ram_control<=bus_data&8'h7f;
                    // ASSUMPTION A6: Jan87 TR p.1-13 prints 80/81/82; the
                    // unchanged Feb87 BIOS POST at 015D and disk DMA at 191B
                    // use 81/82/83/87. Independent 86Box dma.c agrees with ROM.
                    16'h81:page[2]<=bus_data[3:0];
                    16'h82:page[3]<=bus_data[3:0];
                    16'h83:page[1]<=bus_data[3:0];
                    16'h87:page[0]<=bus_data[3:0];
                    16'ha1:rtc_mask<=bus_data[0];
                    16'h3f2:if(planar[3]) floppy_dor<=bus_data;
                    16'h3f7:if(planar[3]) floppy_ccr<=bus_data[2:1];
                    default:begin end
                endcase
                if(bus_addr[15:3]==13'h07f && planar[4]) begin
                    if(bus_addr[2:0]==0) begin
                        if(uart[3][7]) uart_dll<=bus_data;
                        else begin
                            uart_tx_irq<=1;
                            if(uart[4][4]) begin uart_receive<=bus_data;uart_full<=1;end
                        end
                    end else if(bus_addr[2:0]==1 && uart[3][7]) uart_dlm<=bus_data;
                    else begin
                        uart[bus_addr[2:0]]<=bus_data;
                        if(bus_addr[2:0]==1 && bus_data[1] && !uart[1][1]) uart_tx_irq<=1;
                        if(bus_addr[2:0]==4) begin
                            uart_delta<=uart_delta|{(uart_modem[7]^(bus_data[4] && bus_data[3])),
                                (uart_modem[6] && !(bus_data[4] && bus_data[2])),
                                (uart_modem[5]^(bus_data[4] && bus_data[0])),
                                (uart_modem[4]^(bus_data[4] && bus_data[1]))};
                        end
                    end
                end
                if(bus_addr[15:0]==16'h378 && planar[1]) lpt_data<=bus_data;
                if(bus_addr[15:0]==16'h37a && planar[1]) lpt_control<=bus_data;
            end
            if(io_read && bus_addr[15:0]==16'h3f8 && !uart[3][7]) uart_full<=0;
            if(io_read && bus_addr[15:0]==16'h3fa && bus_read_data==2) uart_tx_irq<=0;
            if(io_read && bus_addr[15:0]==16'h3fe) uart_delta<=0;
        end
    end
    logic unused_signals;
    assign unused_signals=^{1'b0,ad_oe,address_oe,bhe_oe,rd_n,wr_n,m_io,dt_r,den_n,ale,inta_n,hlda,lock_n,qs,
        dma_addr_oe,dma_adstb,dma_aen,dma_memr_n,dma_dack[3],dma_dack[1:0],fdc_mfm,fdc_load,fdc_deleted,
        unused_cas,unused_cas_oe,unused_en,unused_en_oe,
        cpu_ax,cpu_cx,cpu_dx,cpu_bx,cpu_sp,cpu_bp,cpu_si,cpu_di,cpu_es,cpu_cs,cpu_ss,cpu_ds};
endmodule
