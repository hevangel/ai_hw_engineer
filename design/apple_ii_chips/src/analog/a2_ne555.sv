`timescale 1ns/1ps
module a2_ne555 (
    input real p1, p2, p4, p5, p6, p8,
    output tri p3, p7
);
    logic q;
    real reference_voltage;
    logic powered;
    always_comb begin
        powered=(p8-p1>=4.5 && p8-p1<=16.0);
        // ASSUMPTION: negative sentinel means unconnected control pin.
        reference_voltage=(p5<p1) ? p1+(p8-p1)*2.0/3.0 : p5;
    end
    always_latch begin
        if(!powered || p4-p1<0.7) q=0;
        else if(p2 < p1+(reference_voltage-p1)/2.0) q=1;
        else if(p6 > reference_voltage) q=0;
    end
    assign p3=powered ? q : 1'bx;
    assign p7=powered ? (q ? 1'bz : 1'b0) : 1'bx;
endmodule
