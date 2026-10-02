`timescale 1ns/1ps
module tb_rev0_peripherals;
    logic trigger=1;
    tri flash;
    logic [3:0] timers;
    logic cassette;
    wire real amplifier;
    apple_ii_rev0_peripherals dut(trigger,0.0,50000.0,100000.0,150000.0,
        0.0,flash,timers,cassette,amplifier);
    realtime began, finish_time [0:3];
    logic [3:0] completed=0;
    logic output_level=1'bx;
    real output_load=0.0;
    wire real output_voltage;
    logic output_valid, output_checked=0;
    apple_ii_cassette_output cassette_jack(.drive_level(output_level),
        .load_ohms(output_load),.jack_voltage(output_voltage),.voltage_valid(output_valid));
    initial begin
        #100;
        if(output_valid) $fatal(1,"Unknown cassette output cannot be valid");
        output_level=0; #1;
        if(!output_valid || output_voltage<0.001652891 || output_voltage>0.001652893)
            $fatal(1,"Open cassette jack low voltage %f",output_voltage);
        output_level=1; #1;
        if(!output_valid || output_voltage<0.033057850 || output_voltage>0.033057852)
            $fatal(1,"Open cassette jack high voltage %f",output_voltage);
        output_load=1000.0; #1;
        if(!output_valid || output_voltage<0.030075187 || output_voltage>0.030075189)
            $fatal(1,"Loaded cassette jack voltage %f",output_voltage);
        output_level=1'bz; #1;
        if(output_valid) $fatal(1,"Floating cassette output cannot be valid");
        output_level=1; output_load=-1.0; #1;
        if(output_valid) $fatal(1,"Negative cassette load cannot be valid");
        output_checked=1;
    end
    initial begin
        #1000;
        if(timers!==0) $fatal(1,"paddles before trigger");
        began=$realtime; trigger=0;
        #1;
        if(timers!==4'b1111) $fatal(1,"all four timers must start");
        #4000000;
        if(completed!==4'b1111) $fatal(1,"paddle timeout missing");
        for(int i=0;i<4;i++) begin
            if(finish_time[i]-began<0.99*(100.0+50000.0*i)*22.0 ||
               finish_time[i]-began>1.01*(100.0+50000.0*i)*22.0+100.0)
                $fatal(1,"paddle channel %0d duration %f",i,finish_time[i]-began);
        end
        if(timers!==0) $fatal(1,"trigger low cannot retrigger");
        if(!output_checked) $fatal(1,"Cassette jack checks did not complete");
        $display("PASS revision-0 four paddle RC channels and routing");
        $display("PASS cassette jack open/load divider voltages and invalid-level rejection"); $finish;
    end
    initial begin
        wait(timers[0]===1'b1); @(negedge timers[0]); finish_time[0]=$realtime; completed[0]=1;
    end
    initial begin
        wait(timers[1]===1'b1); @(negedge timers[1]); finish_time[1]=$realtime; completed[1]=1;
    end
    initial begin
        wait(timers[2]===1'b1); @(negedge timers[2]); finish_time[2]=$realtime; completed[2]=1;
    end
    initial begin
        wait(timers[3]===1'b1); @(negedge timers[3]); finish_time[3]=$realtime; completed[3]=1;
    end
    initial begin #5000000; $fatal(1,"analog board timeout"); end
endmodule
