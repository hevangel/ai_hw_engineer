`timescale 1ns/1ps
module a2_lm741 #(
    parameter real A0=200000.0,
    parameter real GBW_HZ=1000000.0,
    parameter real SLEW_V_PER_US=0.5,
    parameter real HEADROOM_V=1.0,
    parameter int STEP_NS=100
) (
    input real p1, p2, p3, p4, p5, p7, p8,
    output real p6
);
    real voltage, delta, limit, seconds;
    assign p6=voltage;
    // ASSUMPTION: typical dominant-pole approximation, no input bias/offset.
    // Null pins and NC are electrically unmodeled; see spec/analog.md.
    initial begin
        if(STEP_NS<=0 || A0<=0 || GBW_HZ<=0) $fatal(1,"Invalid amplifier parameters");
        voltage=0.0;
        seconds=real'(STEP_NS)*1.0e-9;
        forever begin
            #(STEP_NS);
            delta=6.283185307179586*GBW_HZ*((p3-p2)-voltage/A0)*seconds;
            limit=SLEW_V_PER_US*seconds*1.0e6;
            if(delta>limit) delta=limit;
            if(delta< -limit) delta= -limit;
            voltage=voltage+delta;
            if(voltage>p7-HEADROOM_V) voltage=p7-HEADROOM_V;
            if(voltage<p4+HEADROOM_V) voltage=p4+HEADROOM_V;
        end
    end
endmodule
