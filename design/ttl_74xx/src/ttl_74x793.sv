// ASSUMPTION: noncontentious bus; 793 gate is low during readback.
module ttl_74x793 (
    input logic [7:0] d_in,
    input logic g,oe_n,
    output logic [7:0] q,d_out,
    output logic d_drive
);
    logic [7:0] state;
    always_latch begin
        if(g && oe_n) state = d_in;
    end
    assign q=state;
    assign d_drive=!oe_n;
    assign d_out=d_drive?state:8'd0;
endmodule
