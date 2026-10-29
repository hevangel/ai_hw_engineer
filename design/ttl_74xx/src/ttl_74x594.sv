// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x594.md.
// ttl_74x594 - 8-bit shift register, serial-in, parallel-out, with output latch.
module ttl_74x594 (
    input  logic       clk_shift, srclr_n,
    input  logic       clk_lat,   rclr_n,
    input  logic       sin,
    output logic [7:0] q
);
    logic [7:0] shifter;
    always_ff @(posedge clk_shift or negedge srclr_n) begin
        if (!srclr_n) shifter <= 0;
        else          shifter <= {shifter[6:0], sin};
    end
    always_ff @(posedge clk_lat or negedge rclr_n) begin
        if (!rclr_n) q <= 0;
        else         q <= shifter;
    end
endmodule
