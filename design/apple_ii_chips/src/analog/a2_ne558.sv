`timescale 1ns/1ps
module a2_ne558 (
    output tri p1,
    input real p2,
    input logic p3,
    input real p4, p5,
    input logic p6,
    input real p7,
    output tri p8, p9,
    input real p10,
    input logic p11,
    input real p12,
    input logic p13, p14,
    input real p15,
    output tri p16,
    output logic [3:0] timing_sink
);
    logic [3:0] active, trigger, previous_trigger;
    real timing [0:3];
    real reference_voltage;
    logic powered;
    always_comb begin
        powered=(p5-p12>=4.5 && p5-p12<=16.0);
        trigger={p14,p11,p6,p3};
        timing[0]=p2; timing[1]=p7; timing[2]=p10; timing[3]=p15;
        // ASSUMPTION: negative sentinel selects the internal reference.
        reference_voltage=(p4<p12) ? p12+0.63*(p5-p12) : p4;
        timing_sink=~active;
    end
    always_latch begin
        if(!p13 || !powered) begin
            active=0;
            previous_trigger=0;
        end else begin
            for(int i=0;i<4;i++) begin
                if(timing[i]>=reference_voltage) active[i]=0;
                else if(previous_trigger[i]===1'b1 && trigger[i]===1'b0) active[i]=1;
            end
            previous_trigger=trigger;
        end
    end
    assign p1=powered ? (active[0] ? 1'bz : 1'b0) : 1'bx;
    assign p8=powered ? (active[1] ? 1'bz : 1'b0) : 1'bx;
    assign p9=powered ? (active[2] ? 1'bz : 1'b0) : 1'bx;
    assign p16=powered ? (active[3] ? 1'bz : 1'b0) : 1'bx;
endmodule
