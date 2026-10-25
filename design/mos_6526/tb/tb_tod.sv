`timescale 1ns/1ps
module tb_tod;
    logic clk=0, rst_n=0, edge_i=0, mode_50hz_i=1;
    logic write_i=0, read_i=0, alarm_select_i=0;
    logic [1:0] addr=0;
    logic [7:0] data_i=0, data_o;
    logic alarm_event_o, stopped_o, latched_o;
    logic [31:0] time_o, alarm_o;
    int alarm_events=0, checks=0, previous_events;
    logic [7:0] value;
    mos_6526_tod dut (.*);
    task automatic require_check(input logic condition,input string message);
        if(condition !== 1) $fatal(1,"%s time=%08x alarm=%08x stop=%b latched=%b",message,time_o,alarm_o,stopped_o,latched_o);
        checks++;
    endtask
    task automatic tick(input logic event_edge=0);
        edge_i=event_edge; #1;
        if(alarm_event_o) alarm_events++;
        clk=1; #1; clk=0; #1; edge_i=0; #1;
    endtask
    task automatic put(input logic [1:0] address,input logic [7:0] data,input logic alarm_write=0);
        addr=address; data_i=data; alarm_select_i=alarm_write; write_i=1;
        tick(); write_i=0; #1;
    endtask
    task automatic get(input logic [1:0] address,output logic [7:0] result);
        addr=address; read_i=1; #1; result=data_o;
        tick(); read_i=0; #1;
    endtask
    initial begin
        tick(); rst_n=1;
        require_check(time_o==32'h01000000 && stopped_o && !latched_o,"Explicit TOD reset profile");
        put(3,8'h11); put(2,8'h59); put(1,8'h59); put(0,9);
        get(3,value); require_check(value==8'h11 && latched_o,"Hour read snapshots all fields");
        repeat(4) tick(1);
        require_check(time_o==32'h11595909,"50 Hz divider does not advance early");
        tick(1); require_check(time_o==32'h92000000,"11:59:59.9 AM to 12 PM");
        get(1,value); require_check(value==8'h59,"Live clock cannot tear latched seconds");
        get(3,value); require_check(value==8'h11,"Repeated hour read retains snapshot");
        get(0,value); require_check(value==9 && !latched_o,"Tenths read returns snapshot then releases");
        get(3,value); require_check(value==8'h92,"New snapshot observes current clock");
        get(0,value); require_check(value==0,"New snapshot tenths");
        put(3,7); repeat(20) tick(1);
        require_check(time_o==32'h07000000 && stopped_o,"Hour write stops clock");
        put(0,9); repeat(4) tick(1);
        require_check(time_o==32'h07000009 && !stopped_o,"Restart resets divider and honors full period");
        tick(1); require_check(time_o==32'h07000100,"Restarted divider exact endpoint");
        mode_50hz_i=0; repeat(5) tick(1);
        require_check(time_o==32'h07000100,"60 Hz divider requires sixth pulse");
        tick(1); require_check(time_o==32'h07000101,"60 Hz divider endpoint");
        put(3,8'h12); require_check(time_o[31:24]==8'h92,"Time-hour-12 write flips PM");
        put(3,8'h12,1); require_check(alarm_o[31:24]==8'h12,"Alarm-hour-12 write preserves PM");
        put(3,1); put(2,0); put(1,0); put(0,4);
        put(3,1,1); put(2,0,1); put(1,0,1); put(0,5,1);
        previous_events=alarm_events;
        repeat(6) tick(1);
        require_check(time_o==32'h01000005 && alarm_events==previous_events+1,"Clock advance generates alarm match");
        repeat(10) tick(); require_check(alarm_events==previous_events+1,"Static equal state does not retrigger");
        put(0,6,1); previous_events=alarm_events; put(0,5,1);
        require_check(alarm_events==previous_events+1,"Writing matching alarm generates event");
        put(3,8'hff); put(2,8'hff); put(1,8'hff); put(0,8'hff);
        require_check(time_o==32'h9f7f7f0f,"All unused register bits masked");
        repeat(6) tick(1);
        require_check(time_o==32'h9f7f7f00,"Invalid tenths wrap without normal decimal carry");
        $display("MOS 6526 TOD FOUR-STATE PASS: %0d checks; divider/latch/alarm/BCD/write-12",checks);
        $finish;
    end
endmodule
