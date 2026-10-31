`timescale 1ns/1ps
module tb_timer_trace;
    logic clk=0, rst_n=0, phi2_mode_i=0, pulse_i=0;
    logic write_low_i=0, write_high_i=0, write_control_i=0;
    logic [7:0] data_i=0;
    logic [15:0] count_o, latch_o, cycle_count_o;
    logic started_o, underflow_o, cycle_started_o, underflow_event_o;
    string path;
    int handle, fields, command, data, pulse, mode, expected_count, expected_latch, expected_start, expected_underflow;
    int cycles=0;
    mos_6526_timer dut (.*);
    initial begin
        if (!$value$plusargs("vectors=%s",path)) $fatal(1,"Missing independent timer records");
        handle=$fopen(path,"r");
        if (handle==0) $fatal(1,"Cannot open independent timer records");
        while (!$feof(handle)) begin
            fields=$fscanf(handle,"%d %d %d %d %d %d %d %d\n",command,data,pulse,mode,
                           expected_count,expected_latch,expected_start,expected_underflow);
            if(fields!=8) begin
                if(fields!=-1) $fatal(1,"Malformed independent timer record");
                break;
            end
            rst_n=command!=4; phi2_mode_i=1'(mode); pulse_i=1'(pulse);
            write_low_i=command==1; write_high_i=command==2; write_control_i=command==3; data_i=8'(data);
            #1;
            if(cycle_count_o !== 16'(expected_count) || cycle_started_o !== 1'(expected_start) ||
               underflow_event_o !== 1'(expected_underflow))
                $fatal(1,"External current-cycle read mismatch record=%0d count=%04x/%04x start=%b/%b underflow=%b/%b",
                    cycles,cycle_count_o,16'(expected_count),cycle_started_o,1'(expected_start),underflow_event_o,1'(expected_underflow));
            clk=1; #1; clk=0; #1;
            if(count_o !== 16'(expected_count) || latch_o !== 16'(expected_latch) ||
               started_o !== 1'(expected_start) || underflow_o !== 1'(expected_underflow))
                $fatal(1,"External timer replay mismatch record=%0d command=%0d count=%04x/%04x latch=%04x/%04x start=%b/%b underflow=%b/%b",
                    cycles,command,count_o,16'(expected_count),latch_o,16'(expected_latch),started_o,1'(expected_start),underflow_o,1'(expected_underflow));
            cycles++;
        end
        $fclose(handle);
        if(cycles<50000) $fatal(1,"Incomplete external timer replay");
        $display("MOS 6526 FOUR-STATE TIMER PASS: %0d unchanged-oracle records",cycles);
        $finish;
    end
endmodule
