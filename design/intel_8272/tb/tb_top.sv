`timescale 1ns/1ps
module tb_top;
    logic clk=0;
    initial forever #5 clk=~clk;
    intel_8272_if bus(clk);
    `include "dut.svh"
    logic [7:0] value;
    logic [55:0] res;
    integer seed=1, random_state, bytes_checked=0;
    integer pulse_counts[4]='{0,0,0,0};
    integer pulse_before[4];
    always_ff @(posedge clk) begin
        for (integer drive=0;drive<4;drive++)
            if (bus.rst_n && bus.step[drive]) pulse_counts[drive]<=pulse_counts[drive]+1;
    end
    function automatic logic [7:0] pattern(input integer offset);
        return 8'((offset*73+19) ^ (offset>>3));
    endfunction
    task automatic expect_result(input logic [7:0] s0,s1,s2,cc,hh,rr,nn);
        bus.result7(res);
        bus.check(res=={8'(s0),8'(s1),8'(s2),8'(cc),8'(hh),8'(rr),8'(nn)},
            $sformatf("result expected %014x got %014x",
            {8'(s0),8'(s1),8'(s2),8'(cc),8'(hh),8'(rr),8'(nn)},res));
    endtask
    task automatic read_sector(input integer size_code,input bit non_dma,deleted=0,
        input integer terminal_after=0,input bit bad_crc=0);
        integer length, limit;
        length=128<<size_code; limit=terminal_after==0 ? length : terminal_after;
        bus.command9(deleted ? 8'h4c : 8'h46,3,0,1,8'(size_code),1,0);
        bus.header(3,0,1,8'(size_code),deleted);
        for (integer k=0;k<length;k++) begin
            bus.disk_byte(pattern(k));
            if (k<limit) begin
                if (!non_dma) bus.check(bus.drq,$sformatf("read request k=%0d phase=%0d count=%0d size=%0d limit=%0d tc=%b",
                    k,dut.phase,dut.byte_count,dut.sector_size,dut.host_limit,dut.tc_seen));
                bus.data_get(value,non_dma,k==limit-1);
                bus.check(value==pattern(k),"independent media content"); bytes_checked++;
            end else bus.tick(2);
        end
        bus.disk_end(bad_crc);
        if (bad_crc) expect_result(8'h40,8'h20,8'h20,3,0,1,8'(size_code));
        else expect_result(0,0,0,4,0,1,8'(size_code));
    endtask
    task automatic scan(input logic [7:0] op,input logic [7:0] disk,host,expect_st2);
        bus.command9(op,3,0,1,0,1,1); bus.header();
        for (integer k=0;k<128;k++) begin
            bus.disk_byte(disk); bus.data_put(host,0,k==127);
        end
        bus.disk_end(); expect_result(0,0,expect_st2,4,0,1,0);
    endtask
    initial begin
        if ($value$plusargs("seed=%d",seed)) begin end
        random_state=seed;
        bus.startup();
        bus.cpu_put(8'hff,4); bus.cpu_get(value,4); bus.check(value==8'h80,"invalid opcode");
        bus.cpu_put(8'h08); bus.cpu_get(value); bus.check(value==8'h80,"SIS without event");
        bus.cpu_put(8'h04); bus.cpu_put(0); bus.cpu_get(value);
        bus.check(value==8'h38,"sense drive status");
        bus.cpu_put(8'h4a); bus.cpu_put(0); bus.tick(4);
        bus.header(7,1,9,2); expect_result(0,0,0,7,1,9,2);
        for (integer nn=0;nn<=6;nn++) read_sector(nn,0);
        read_sector(0,0,0,7); read_sector(0,0,1); read_sector(0,0,0,0,1);
        bus.startup(1); read_sector(0,1); bus.startup();

        // Write/read fixtures use actual content; TC's accepted byte precedes zero fill.
        for (integer deleted=0;deleted<2;deleted++) begin
            bus.command9(deleted!=0 ? 8'h49 : 8'h45); bus.header();
            bus.check(bus.sector_deleted==1'(deleted),"write data mark");
            for (integer k=0;k<128;k++) begin
                if (k<17) bus.data_put(pattern(k),0,k==16);
                bus.disk_write(value);
                bus.check(value==(k<17 ? pattern(k) : 8'd0),"TC write and zero fill"); bytes_checked++;
            end
            expect_result(0,0,0,4,0,1,0);
        end
        scan(8'h51,8'h23,8'h23,8'h08);
        scan(8'h59,8'h23,8'h24,0); scan(8'h5d,8'h24,8'h23,0);
        scan(8'h51,8'hff,8'h12,8'h08); scan(8'h51,8'h23,8'h24,8'h04);

        bus.command9(8'h46); bus.header(8'hff); expect_result(8'h40,4,8'h12,8'hff,0,1,0);
        bus.command9(8'h46); bus.header(3,0,1,0,0,1); expect_result(8'h40,1,1,3,0,1,0);
        bus.command9(8'h46); bus.header(3,0,1,0,0,0,1); expect_result(8'h40,8'h20,0,3,0,1,0);
        bus.command9(8'h46); bus.index_event(); bus.index_event(); expect_result(8'h40,5,0,3,0,1,0);
        bus.write_protect=1; bus.command9(8'h45); expect_result(8'h40,2,0,3,0,1,0); bus.write_protect=0;
        bus.fault=1; bus.command9(8'h46); expect_result(8'h50,0,0,3,0,1,0); bus.fault=0;
        bus.command9(8'h46); bus.header(); bus.disk_byte(8'h55); bus.tick(14);
        expect_result(8'h40,8'h10,0,3,0,1,0);

        // Read Track: wait for index and use nonsequential encountered IDs.
        bus.command9(8'h42,0,0,1,0,2); bus.check(!bus.drq,"read track index gate"); bus.index_event();
        for (integer sec=0;sec<2;sec++) begin
            bus.header(3,0,8'(sec==0 ? 9 : 2),0);
            for (integer k=0;k<128;k++) begin
                bus.disk_byte(pattern(k)); bus.data_get(value,0); bus.check(value==pattern(k),"track data");
            end
            bus.disk_end();
        end
        expect_result(0,0,0,3,0,3,0);

        // Format writes supplied IDs (not loop indices) and filler sector bytes.
        bus.cpu_put(8'h4d); bus.cpu_put(0); bus.cpu_put(0); bus.cpu_put(2);
        bus.cpu_put(8'h1b); bus.cpu_put(8'he5); bus.tick(4); bus.index_event();
        for (integer sec=0;sec<2;sec++) begin
            bus.data_put(7,0); bus.data_put(0,0); bus.data_put(8'(sec==0 ? 9 : 2),0); bus.data_put(0,0);
            bus.check(bus.sector_c==7 && bus.sector_r==8'(sec==0 ? 9 : 2),"format ID metadata");
            for (integer k=0;k<128;k++) begin
                bus.disk_write(value); bus.check(value==8'he5,"format filler");
            end
        end
        bus.check(!bus.irq,"format waits trailing index"); bus.index_event();
        expect_result(0,0,0,7,0,3,0);

        // Four simultaneous seeks, outward recalibration, latched PCN and SIS ordering.
        for (integer drive=0;drive<4;drive++) pulse_before[drive]=pulse_counts[drive];
        for (integer drive=0;drive<4;drive++) begin
            bus.cpu_put(8'h0f); bus.cpu_put(8'(drive)); bus.cpu_put(8'(200+drive));
        end
        bus.tick(500);
        bus.check(bus.direction==15,"seek inward directions");
        for (integer drive=0;drive<4;drive++) begin
            bus.check(pulse_counts[drive]-pulse_before[drive]==200+drive,"seek exact pulse count");
            bus.cpu_put(8'h08); bus.cpu_get(value); bus.check(value==8'h20+8'(drive),"seek completion unit");
            bus.cpu_get(value); bus.check(value==8'(200+drive),"seek PCN");
        end
        pulse_before[0]=pulse_counts[0];
        bus.track0=14; bus.cpu_put(7); bus.cpu_put(0); bus.tick(180);
        bus.check(pulse_counts[0]-pulse_before[0]==77,"recal exact 77 pulses");
        bus.check(!bus.direction[0],"recal outward direction");
        bus.cpu_put(8); bus.cpu_get(value); bus.check(value==8'h70,"77-step recal failure");
        bus.cpu_get(value); bus.check(value==0,"recal PCN zero");
        bus.track0=15; bus.cpu_put(7); bus.cpu_put(0); bus.tick(4);
        bus.cpu_put(8); bus.cpu_get(value); bus.check(value==8'h20,"recal success"); bus.cpu_get(value);

        // Intel Table 8: exact TC result IDs across head/EOT/MT combinations.
        for (integer flags=0;flags<8;flags++) begin
            bit multitrack, side, last;
            multitrack=flags[2]; side=flags[1]; last=flags[0];
            bus.command9(multitrack ? 8'hc6 : 8'h46,3,8'(side),1,0,last ? 1 : 2);
            bus.header(3,8'(side));
            for (integer k=0;k<128;k++) begin
                bus.disk_byte(pattern(k));
                if (k==0) bus.data_get(value,0,1); else bus.tick();
            end
            bus.disk_end();
            expect_result(side ? 4 : 0,0,0,
                last && (!multitrack || side) ? 4 : 3,
                last && multitrack ? 8'(!side) : 8'(side),last ? 1 : 2,0);
        end
        // MT actually switches sides after EOT; ST0 reports the last physical head.
        bus.command9(8'hc6);
        for (integer side=0;side<2;side++) begin
            bus.header(3,8'(side));
            for (integer k=0;k<128;k++) begin
                bus.disk_byte(pattern(k)); bus.data_get(value,0,side==1 && k==127);
            end
            bus.disk_end();
            if (side==0) bus.check(bus.head,"MT side switch");
        end
        expect_result(4,0,0,4,0,1,0);

        // Deleted mark without SK stops after transfer; with SK it searches the next ID.
        bus.command9(8'h46); bus.header(3,0,1,0,1);
        for (integer k=0;k<128;k++) begin bus.disk_byte(pattern(k)); bus.data_get(value,0); end
        bus.disk_end(); expect_result(8'h40,0,8'h40,3,0,1,0);
        bus.command9(8'h66,3,0,1,0,2); bus.header(3,0,1,0,1);
        bus.check(!bus.drq,"SK discards deleted sector"); bus.header(3,0,2);
        for (integer k=0;k<128;k++) begin bus.disk_byte(pattern(k)); bus.data_get(value,0,k==127); end
        bus.disk_end(); expect_result(0,0,0,4,0,1,0);
        bus.command9(8'h46); bus.header();
        for (integer k=0;k<128;k++) begin bus.disk_byte(pattern(k)); bus.data_get(value,0); end
        bus.disk_end(); expect_result(8'h40,8'h80,0,3,0,1,0);

        // DTL limits only the host bytes. Sector CRC is still drained.
        bus.command9(8'h46,3,0,1,0,1,3); bus.header();
        for (integer k=0;k<128;k++) begin
            bus.disk_byte(pattern(k)); if (k<3) bus.data_get(value,0); else bus.tick();
        end
        bus.disk_end(1); expect_result(8'h40,8'h20,8'h20,3,0,1,0);
        bus.command9(8'h45,3,0,1,0,1,3); bus.header();
        for (integer k=0;k<128;k++) begin
            if (k<3) bus.data_put(pattern(k),0); bus.disk_write(value);
            bus.check(value==(k<3 ? pattern(k) : 8'd0),"DTL short write zero fill");
        end
        expect_result(8'h40,8'h80,0,3,0,1,0);

        // A failed scan with STP=2 retries R+2; SH must clear the earlier SN.
        bus.command9(8'h51,3,0,1,0,3,2); bus.header();
        for (integer k=0;k<128;k++) begin bus.disk_byte(1); bus.data_put(2,0); end
        bus.disk_end(); bus.check(bus.sector_r==3,"scan STP two"); bus.header(3,0,3);
        bus.disk_byte(2); bus.data_put(2,0,1); bus.tick(2);
        expect_result(0,0,8'h08,4,0,1,0);
        // A mixed low/equal sector must fail if any disk byte exceeds its host byte.
        bus.command9(8'h59,3,0,1,0,1,1); bus.header();
        bus.disk_byte(2); bus.data_put(3,0); bus.disk_byte(4); bus.data_put(3,0,1); bus.tick(2);
        expect_result(0,0,4,4,0,1,0);
        bus.command9(8'h51,3,0,1,0,1,1); bus.header();
        for (integer k=0;k<128;k++) begin bus.disk_byte(1); bus.data_put(2,0); end
        bus.disk_end(); expect_result(0,0,4,4,0,1,0);
        bus.command9(8'h71,3,0,1,0,3,2); bus.header(3,0,1,0,1);
        bus.header(3,0,3); bus.disk_byte(2); bus.data_put(2,0,1); bus.tick(2);
        expect_result(0,0,8'h48,4,0,1,0);
        bus.command9(8'h46); bus.tc=1; bus.tick(); bus.tc=0;
        expect_result(0,0,0,3,0,1,0);

        // Non-DMA still services a final byte after the backend reports sector end.
        bus.startup(1); bus.command9(8'h46); bus.header(); bus.disk_byte(8'h5a); bus.disk_end();
        bus.data_get(value,1,1); bus.check(value==8'h5a,"ND final byte retained");
        bus.tick(); expect_result(0,0,0,4,0,1,0); bus.startup();

        // Service on the MFM read deadline is legal; DACK alone keeps the byte pending.
        bus.command9(8'h46); bus.header(); bus.disk_byte(8'h35);
        bus.dack_n=0; bus.tick(12); bus.check(dut.service_us==1,"deadline setup");
        bus.rd_n=0; bus.tc=1; bus.tick(); bus.rd_n=1; bus.tc=0; bus.dack_n=1; bus.tick();
        bus.disk_end(); expect_result(0,0,0,4,0,1,0);
        bus.command9(8'h51,3,0,1,0,1,1); bus.header(); bus.disk_byte(2);
        bus.tick(13); expect_result(8'h40,8'h10,0,3,0,1,0);

        // Head load/unload uses Specify timers rather than disk response latency.
        bus.cpu_put(3); bus.cpu_put(8'hf1); bus.cpu_put(8'd40); bus.tick(40);
        bus.cpu_put(8'h4a); bus.cpu_put(0); bus.tick(4);
        bus.check(bus.head_load && !bus.media_active,"HLT settling");
        bus.tick(85); bus.check(bus.media_active,"HLT complete"); bus.header();
        bus.tick(40); bus.check(!bus.head_load,"HUT unload"); expect_result(0,0,0,3,0,1,0);
        bus.startup(); bus.ready[0]=0; bus.command9(8'h46);
        expect_result(8'h48,0,0,3,0,1,0); bus.startup();

        // Seeded content and DMA acknowledge spacing through full sectors.
        for (integer trial=0;trial<8;trial++) begin
            bus.command9(8'h46,3,0,1,0,1); bus.header();
            for (integer k=0;k<128;k++) begin
                value=8'($random(random_state)); bus.disk_byte(value);
                begin logic [7:0] got; bus.data_get(got,0,k==127); bus.check(got==value,"seeded byte"); end
                bus.tick(int'($unsigned($random(random_state))%3));
            end
            bus.disk_end(); expect_result(0,0,0,4,0,1,0);
        end
        $display("8272 SUITE PASSED seed=%0d checks=%0d sector_bytes=%0d",seed,bus.checks,bytes_checked);
        $finish;
    end
endmodule
