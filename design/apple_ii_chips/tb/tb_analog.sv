`timescale 1ns/1ps
module tb_analog;
    real trigger_555=2.5, threshold_555=2.5, reset_555=0.0;
    tri out555, discharge555;
    a2_ne555 flash(0.0,trigger_555,reset_555,-1.0,threshold_555,5.0,out555,discharge555);
    logic trigger=0, reset558=0;
    real timing_voltage=0.0;
    tri [3:0] out558;
    logic [3:0] sink;
    a2_ne558 paddles(.p1(out558[0]),.p2(timing_voltage),.p3(trigger),.p4(-1.0),.p5(5.0),
        .p6(trigger),.p7(timing_voltage),.p8(out558[1]),.p9(out558[2]),.p10(timing_voltage),
        .p11(trigger),.p12(0.0),.p13(reset558),.p14(trigger),.p15(timing_voltage),.p16(out558[3]),.timing_sink(sink));
    real noninvert=0.1;
    wire real amplifier;
    a2_lm741 opamp(0.0,0.0,noninvert,-5.0,0.0,5.0,0.0,amplifier);
    initial begin
        #1;
        if(out555!==0 || discharge555!==0) $fatal(1,"555 reset");
        reset_555=5.0; trigger_555=0.0; #1;
        if(out555!==1 || discharge555!==1'bz) $fatal(1,"555 trigger/discharge release");
        trigger_555=2.5; #1;
        if(out555!==1) $fatal(1,"555 latch hold");
        threshold_555=4.0; #1;
        if(out555!==0 || discharge555!==0) $fatal(1,"555 threshold/discharge");
        trigger_555=0.0; #1;
        if(out555!==1) $fatal(1,"555 trigger wins over threshold");
        if(out558!==4'b0000) $fatal(1,"558 reset");
        reset558=1; #1;
        if(out558!==4'b0000) $fatal(1,"558 must rearm after reset");
        trigger=1; #1; trigger=0; #1;
        if(out558!==4'bzzzz || sink!==0) $fatal(1,"558 edge/polarity");
        timing_voltage=3.2; #1;
        if(out558!==4'b0000 || sink!==4'b1111) $fatal(1,"558 timeout while trigger held low");
        timing_voltage=0.0; #1;
        if(out558!==0) $fatal(1,"558 no level retrigger");
        #2000;
        if(amplifier<0.95 || amplifier>1.1) $fatal(1,"741 slew %f",amplifier);
        #8000;
        if(amplifier<3.99 || amplifier>4.01) $fatal(1,"741 output swing %f",amplifier);
        noninvert=-0.1; #16000;
        if(amplifier< -4.01 || amplifier> -3.95) $fatal(1,"741 negative swing %f",amplifier);
        $display("PASS analog timer thresholds, edge rearming, and amplifier slew/swing"); $finish;
    end
endmodule
