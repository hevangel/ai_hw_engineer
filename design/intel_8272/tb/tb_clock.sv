`timescale 1ns/1ps
// Intel timing note: multiply specified 8 MHz intervals by two at 4 MHz.
module tb_clock;
    logic clk=0;
    initial forever #5 clk=~clk;
    intel_8272_if bus(clk);
    intel_8272 #(.RQM_DELAY_US(24),.MS_US(2000),.CLOCK_SCALE(2)) dut (
        .clk(clk),.rst_n(bus.rst_n),.us_tick(bus.us_tick),
        .cs_n(bus.cs_n),.rd_n(bus.rd_n),.wr_n(bus.wr_n),.dack_n(bus.dack_n),
        .a0(bus.a0),.tc(bus.tc),.db_in(bus.db_in),.db_out(bus.db_out),
        .db_oe(bus.db_oe),.irq(bus.irq),.drq(bus.drq),
        .ready(bus.ready),.write_protect(bus.write_protect),.track0(bus.track0),
        .two_sided(bus.two_sided),.fault(bus.fault),.step(bus.step),.direction(bus.direction),
        .unit(bus.unit),.head(bus.head),.mfm(bus.mfm),.head_load(bus.head_load),
        .media_active(bus.media_active),.media_write(bus.media_write),.media_format(bus.media_format),
        .index_pulse(bus.index_pulse),.header_valid(bus.header_valid),
        .header_c(bus.header_c),.header_h(bus.header_h),.header_r(bus.header_r),.header_n(bus.header_n),
        .header_deleted(bus.header_deleted),.header_missing_data(bus.header_missing_data),
        .header_crc_error(bus.header_crc_error),.media_byte_valid(bus.media_byte_valid),
        .media_byte(bus.media_byte),.media_end(bus.media_end),.media_crc_error(bus.media_crc_error),
        .write_slot(bus.write_slot),.sector_begin(bus.sector_begin),.sector_end(bus.sector_end),
        .tx_valid(bus.tx_valid),.tx_byte(bus.tx_byte),.sector_c(bus.sector_c),
        .sector_h(bus.sector_h),.sector_r(bus.sector_r),.sector_n(bus.sector_n),
        .sector_deleted(bus.sector_deleted));
    logic [7:0] value;
    logic [55:0] result;
    integer steps=0;
    always_ff @(posedge clk) if(bus.rst_n && bus.step[0]) steps<=steps+1;
    initial begin
        bus.reset();bus.ready=15;bus.tick(1300);
        bus.check(!bus.irq,"4 MHz initial scan is not complete at the 8 MHz interval");
        bus.tick(1300);bus.check(bus.irq,"4 MHz initial READY batch completes");
        for(integer drive=0;drive<4;drive++) begin
            bus.cpu_put(8'h08);bus.cpu_get(value);bus.check(value==8'hc0+8'(drive),"scaled reset-ready unit");
            bus.cpu_get(value);bus.check(value==0,"scaled initial cylinder");
        end
        bus.cpu_put(3);bus.cpu_put(8'hf1);bus.cpu_put(0);bus.tick(30);
        bus.command9(8'h46);bus.tick(30);bus.header();bus.disk_byte(8'h5a);
        bus.tick(13);bus.check(bus.drq && !bus.irq,"4 MHz byte survives the 8 MHz deadline");
        bus.data_get(value,0,1);bus.check(value==8'h5a,"scaled byte content");
        bus.disk_end();bus.result7(result);bus.check(result==56'h00000004000100,"scaled read result");
        bus.command9(8'h46);bus.tick(30);bus.header();bus.disk_byte(8'h35);
        bus.dack_n=0;bus.tick(25);bus.rd_n=0;bus.tc=1;bus.tick();
        bus.rd_n=1;bus.tc=0;bus.dack_n=1;bus.tick();bus.disk_end();
        bus.result7(result);bus.check(result==56'h00000004000100,"service on 26us deadline is accepted");
        bus.command9(8'h46);bus.tick(30);bus.header();bus.disk_byte(8'h35);bus.tick(26);
        bus.result7(result);bus.check(result==56'h40100003000100,"unserviced 26us request overruns");
        bus.cpu_put(8'h0f);bus.cpu_put(0);bus.cpu_put(1);bus.tick(1990);
        bus.check(steps==0,"4 MHz SRT does not step before 2ms");bus.tick(40);
        bus.check(steps==1 && bus.irq,"4 MHz SRT emits one step after 2ms");
        bus.cpu_put(8'h08);bus.cpu_get(value);bus.check(value==8'h20,"scaled seek status");
        bus.cpu_get(value);bus.check(value==1,"scaled seek cylinder");
        $display("8272 4MHZ CLOCK PASSED checks=%0d",bus.checks);$finish;
    end
endmodule
