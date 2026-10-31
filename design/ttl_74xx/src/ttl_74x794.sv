// ASSUMPTION: noncontentious bus; 793 gate is low during readback.
module ttl_74x794 (
    input logic [7:0] d_in,
    input logic clk,oe_n,
    output logic [7:0] q,d_out,
    output logic d_drive
);
    logic [7:0] state;
    always_ff @(posedge clk)
        if(oe_n) state <= d_in;
    assign q=state;
    assign d_drive=!oe_n;
    assign d_out=d_drive?state:8'd0;
endmodule
