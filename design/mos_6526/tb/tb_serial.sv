`timescale 1ns/1ps
module tb_serial;
    logic clk=0, rst_n=0, output_mode_i=0, write_i=0;
    logic [7:0] data_i=0, data_o;
    logic cnt_rise_i=0, sp_i=1, baud_pulse_i=0;
    logic cnt_o, cnt_oe, sp_o, sp_oe, irq_event_o, active_o, pending_o;
    int interrupts=0, previous_interrupts, checks=0;
    logic previous_clock;
    logic [15:0] decoded;
    logic [7:0] first_byte, second_byte;
    mos_6526_serial dut (.*);
    task automatic require_check(input logic condition,input string message);
        if(condition !== 1) $fatal(1,"%s SDR=%02x CNT=%b SP=%b active=%b pending=%b irq=%0d previous=%0d bits=%0d",message,data_o,cnt_o,sp_o,active_o,pending_o,interrupts,previous_interrupts,dut.bits_q);
        checks++;
    endtask
    task automatic tick(input logic baud=0,input logic receive=0,input logic bit_value=1);
        baud_pulse_i=baud; cnt_rise_i=receive; sp_i=bit_value; #1;
        if(irq_event_o) interrupts++;
        clk=1; #1; clk=0; #1;
        require_check(cnt_oe== (output_mode_i && !cnt_o) && sp_oe==(output_mode_i && !sp_o),"Open-drain output intent");
    endtask
    task automatic reset_chip(input logic transmit);
        rst_n=0; output_mode_i=0; write_i=0; tick(); rst_n=1; output_mode_i=transmit; tick();
    endtask
    task automatic put(input logic [7:0] value,input logic baud=0);
        write_i=1; data_i=value; tick(baud); write_i=0;
        require_check(data_o==value,"SDR CPU write readback");
    endtask
    initial begin
        reset_chip(0);
        for(int value=0;value<256;value++) begin
            previous_interrupts=interrupts;
            // Ascending index avoids xezim 0.11.0 treating a descending int
            // loop's -1 as unsigned; the stimulus still sends exactly 8 bits.
            for(int index=0;index<8;index++) begin
                tick(0,0,!1'(value>>(7-index))); tick(0,1,1'(value>>(7-index)));
                if(index<7) require_check(interrupts==previous_interrupts,"Receive cannot complete early");
            end
            require_check(data_o==8'(value) && interrupts==previous_interrupts+1,"All received bytes MSB first");
        end
        for(int value=0;value<256;value++) begin
            first_byte=8'(value); second_byte=8'(value)^8'ha5; decoded=0;
            reset_chip(1); put(first_byte); previous_interrupts=interrupts;
            for(int half=0;half<32;half++) begin
                previous_clock=cnt_o;
                if(half==3) put(second_byte,1); else tick(1);
                if(!previous_clock && cnt_o) decoded={decoded[14:0],sp_o};
            end
            repeat(4) tick();
            require_check(decoded=={first_byte,second_byte} && interrupts==previous_interrupts+2,"Buffered byte stream and completion events");
            require_check(cnt_o && sp_o==second_byte[0] && !active_o && !pending_o,"Final SP retained, clock idle high");
        end
        reset_chip(1); put(8'h55); previous_interrupts=interrupts;
        for(int value=0;value<256;value++) begin
            first_byte=8'(value); second_byte=8'(value)^8'ha5; decoded=0;
            reset_chip(1); put(first_byte); repeat(5) tick(); put(second_byte);
            previous_interrupts=interrupts;
            for(int half=0;half<32;half++) begin
                previous_clock=cnt_o; tick(1);
                if(!previous_clock && cnt_o) decoded={decoded[14:0],sp_o};
            end
            repeat(4) tick();
            require_check(decoded=={first_byte,second_byte} && interrupts==previous_interrupts+2,
                          "Both bytes before first underflow survive");
            reset_chip(1); put(first_byte); decoded=0;
            repeat(15) begin
                previous_clock=cnt_o; tick(1);
                if(!previous_clock && cnt_o) decoded={decoded[14:0],sp_o};
            end
            require_check(!cnt_o,"Previous byte still owes final edge");
            put(second_byte); require_check(cnt_o,"Late write releases CNT");
            decoded={decoded[14:0],sp_o};
            repeat(16) begin
                previous_clock=cnt_o; tick(1);
                if(!previous_clock && cnt_o) decoded={decoded[14:0],sp_o};
            end
            require_check(decoded=={first_byte,second_byte},"Late write preserves complete bit stream");
        end
        reset_chip(1); put(8'h55); previous_interrupts=interrupts;
        for(int half=0;half<15;half++) begin
            tick(1);
            if(half!=14) repeat(8) tick();
        end
        require_check(!cnt_o && interrupts==previous_interrupts,"Bit eight precedes request");
        repeat(3) begin
            tick(); require_check(interrupts==previous_interrupts,"No early transmit request");
        end
        tick(); require_check(interrupts==previous_interrupts+1 && !cnt_o,"Four-clock transmit request latency");
        tick(1); require_check(cnt_o && !active_o,"Final rising CNT completes wire transfer");
        reset_chip(1); put(8'h55); previous_interrupts=interrupts;
        repeat(15) tick(1);
        output_mode_i=0; tick(); repeat(4) tick();
        require_check(interrupts==previous_interrupts,"Direction change cancels in-flight transmit request");
        reset_chip(0); repeat(7) tick(0,1,1);
        reset_chip(1); put(8'h01); decoded=0;
        for(int half=0;half<32;half++) begin
            previous_clock=cnt_o;
            if(half==14) put(8'h80,1); else tick(1);
            if(!previous_clock && cnt_o) decoded={decoded[14:0],sp_o};
        end
        require_check(decoded==16'h0180,"Coincident final-bit write preserves outgoing and queued bytes");
        reset_chip(0); repeat(7) tick(0,1,1);
        previous_interrupts=interrupts; write_i=1; data_i=8'h5a; tick(0,1,1); write_i=0;
        require_check(data_o==8'h5a && interrupts==previous_interrupts+1,"CPU write and receive completion precedence");
        reset_chip(1); put(0); tick(1); output_mode_i=0; tick();
        require_check(cnt_o && sp_o && !cnt_oe && !sp_oe && !active_o && !pending_o,"Direction switch releases pins and clears shift state");
        $display("MOS 6526 SERIAL FOUR-STATE PASS: 256 RX bytes, 256 buffered pairs, %0d checks",checks);
        $finish;
    end
endmodule
