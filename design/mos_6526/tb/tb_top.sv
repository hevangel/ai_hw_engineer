`timescale 1ns/1ps
module tb_top;
    logic clk=0, rst_n=0, cs_n=1, rw=1;
    logic [3:0] addr=0;
    logic [7:0] data_i=0, data_o, pa_i=0, pb_i=0;
    logic data_oe;
    logic [7:0] pa_o,pb_o,pa_oe,pb_oe;
    logic cnt_i=0,sp_i=0,flag_n_i=1,tod_i=0;
    logic cnt_o,cnt_oe,sp_o,sp_oe,pc_n,irq_n;
    int checks=0, cycles=0, events=0;
    logic last_cnt;
    logic [7:0] value;
    mos_6526 dut (.*);
    task automatic require_check(input logic condition,input string message);
        if(condition !== 1) $fatal(1,"cycle=%0d %s addr=%x data=%02x",cycles,message,addr,data_o);
        checks++;
    endtask
    task automatic tick;
        #1; clk=1; #1;
        require_check(data_oe == (rst_n && !cs_n && rw),"Read driver during PHI2 high");
        clk=0; #1; cycles++;
        require_check(!data_oe,"Read driver releases during PHI2 low");
    endtask
    task automatic idle;
        cs_n=1; rw=1; tick();
    endtask
    task automatic put(input logic [3:0] regno,input logic [7:0] data);
        cs_n=0; rw=0; addr=regno; data_i=data; tick(); cs_n=1; rw=1;
    endtask
    task automatic get(input logic [3:0] regno,output logic [7:0] data);
        cs_n=0; rw=1; addr=regno;
        #1; clk=1; #1; data=data_o;
        require_check(data_oe,"Selected read driver");
        clk=0; #1; cycles++; cs_n=1;
        require_check(!data_oe,"Read completion releases driver");
    endtask
    task automatic expect_reg(input logic [3:0] regno,input logic [7:0] expected);
        logic [7:0] observed;
        get(regno,observed);
        require_check(observed==expected,$sformatf("register %x expected %02x observed %02x",regno,expected,observed));
    endtask
    task automatic reset_chip;
        rst_n=0; cs_n=1; rw=1; cnt_i=0; flag_n_i=1; tod_i=0;
        tick(); tick(); rst_n=1;
        require_check(pa_oe==0 && pb_oe==0 && pc_n && irq_n && !cnt_oe && !sp_oe,"Reset pin intents");
    endtask
    task automatic cnt_pulse;
        cnt_i=0; idle(); cnt_i=1; idle(); cnt_i=0; idle();
    endtask
    task automatic tod_pulse;
        tod_i=0; idle(); tod_i=1; idle(); tod_i=0; idle();
    endtask
    initial begin
        reset_chip();
        expect_reg(2,0); expect_reg(3,0);
        for(int r=4;r<8;r++) expect_reg(4'(r),8'hff);
        expect_reg(8,0); expect_reg(9,0); expect_reg(10,0); expect_reg(11,1);
        expect_reg(12,0); expect_reg(13,0); expect_reg(14,0); expect_reg(15,0);
        // All DDR/latch combinations, with resolved pins deliberately different
        // from output intent. Reads must sample pins, even when DDR is all ones.
        for(int d=0;d<256;d++) begin
            put(2,8'(d)); put(3,8'(255-d));
            for(int l=0;l<256;l++) begin
                put(0,8'(l)); put(1,8'(255-l));
                pa_i=8'(l)^8'ha5; pb_i=8'(l)^8'h5a;
                expect_reg(0,pa_i); expect_reg(1,pb_i);
                require_check(pa_oe==8'(d) && pb_oe==8'(255-d),"DDR drives output enables");
                require_check(pa_o==8'(l) && pb_o==8'(255-l),"Output latch intents");
                require_check(!pc_n,"PRB read pulses PC low");
                idle(); require_check(pc_n,"PC releases next cycle");
            end
        end
        reset_chip(); put(4,8'h34); put(5,8'h12);
        expect_reg(4,8'h34); expect_reg(5,8'h12);
        put(4,8'h78); expect_reg(4,8'h34);
        put(14,8'h10); expect_reg(14,0); idle(); idle();
        expect_reg(4,8'h78); expect_reg(5,8'h12);
        // Count exactly twelve qualified external edges in Timer B CNT mode.
        reset_chip(); put(6,40); put(7,0); put(15,8'h21);
        for(int p=0;p<12;p++) cnt_pulse();
        idle(); expect_reg(6,28); expect_reg(7,0);
        // Cascade counts Timer A events, with and without CNT gating.
        for(int gated=0;gated<3;gated++) begin
            reset_chip(); put(6,100); put(7,0); put(15,gated==0 ? 8'h41 : 8'h61);
            put(4,2); put(5,0); put(14,8'h23); // A counts CNT, PB6 exposes underflow pulse.
            require_check(pb_oe[6],"Timer output overrides input DDR");
            events=0;
            for(int p=0;p<60;p++) begin
                cnt_i=gated==1 ? (p%3)==1 : (p%6)!=0;
                if(pb_o[6] && (gated==0 || cnt_i)) events++;
                idle();
            end
            // Stop A, then drain the delayed B pulse and decrement pipeline.
            if(pb_o[6] && (gated==0 || cnt_i)) events++;
            put(14,8'h22);
            for(int p=0;p<4;p++) begin
                if(pb_o[6] && (gated==0 || cnt_i)) events++;
                idle();
            end
            require_check(gated==1 ? events==0 : events>0,"Cascade enabled/inhibited events exercised");
            expect_reg(6,8'(100-events)); expect_reg(7,0);
        end
        // Serial input reaches SDR and source bit 3 through the full pin path.
        for(int byte_value=0;byte_value<256;byte_value++) begin
            reset_chip(); put(13,8'h88);
            for(int bit_index=0;bit_index<8;bit_index++) begin
                sp_i=1'((byte_value>>(7-bit_index))&1); cnt_pulse();
            end
            expect_reg(12,8'(byte_value));
            require_check(!irq_n,"Serial completion reaches IRQ pin");
            expect_reg(13,8'h88); idle(); expect_reg(13,0);
        end
        reset_chip(); put(13,8'h90); flag_n_i=0; idle(); idle();
        require_check(!irq_n,"FLAG falling edge interrupt");
        expect_reg(13,8'h90); idle(); expect_reg(13,0);
        flag_n_i=1; idle(); idle(); expect_reg(13,0);
        // Serial output is driven by Timer A; inspect actual CNT/SP pins.
        for(int byte_value=0;byte_value<256;byte_value++) begin
            reset_chip(); put(14,8'h40); put(4,0); put(5,0);
            put(13,8'h88); put(12,8'(byte_value)); put(14,8'h41);
            events=0; last_cnt=cnt_o; value=0;
            for(int p=0;p<48;p++) begin
                idle();
                require_check(cnt_oe==!cnt_o && sp_oe==!sp_o,"Serial open-drain drive/release intents");
                if(cnt_o && !last_cnt) begin value={value[6:0],sp_o}; events++; end
                last_cnt=cnt_o;
            end
            require_check(events==8 && value==8'(byte_value) && cnt_o,"Eight output bits in MSB order");
            get(13,value); require_check(value[3] && value[7],"TX completion interrupt routes to ICR");
        end
        // Five/six qualified TOD edges per tenth, coherent snapshot and alarm.
        for(int mode=0;mode<2;mode++) begin
            reset_chip(); put(14,mode==0 ? 0 : 8'h80);
            put(11,1); put(10,0); put(9,0); put(8,0);
            put(15,8'h80); put(11,1); put(10,0); put(9,0); put(8,1);
            put(15,0); put(13,8'h84);
            for(int p=0;p<(mode==0 ? 5 : 4);p++) tod_pulse();
            expect_reg(8,0); tod_pulse(); idle();
            expect_reg(8,1); require_check(!irq_n,"TOD alarm IRQ"); expect_reg(13,8'h84);
            expect_reg(11,1); // Freeze snapshot at tenth 1.
            for(int p=0;p<(mode==0 ? 6 : 5);p++) tod_pulse();
            expect_reg(8,1); expect_reg(8,2);
        end
        // PHI2 timer produces source bit zero and PB6 pulse with DDR zero.
        reset_chip(); put(4,2); put(5,0); put(13,8'h81); put(14,3);
        events=0;
        for(int p=0;p<20;p++) begin idle(); if(pb_o[6]) events++; end
        require_check(events>0 && events<20 && pb_oe==8'h40 && !irq_n,"PHI2 timer pulse and IRQ");
        get(13,value); require_check(value==8'h81,"Timer A source routes to ICR bit zero");
        $display("MOS 6526 INTEGRATION PASS: %0d checks, %0d PHI2 cycles; 65536 port cases, 256 RX bytes",checks,cycles);
        $finish;
    end
endmodule
