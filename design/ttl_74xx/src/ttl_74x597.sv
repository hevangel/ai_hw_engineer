// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x597.md.
// ttl_74x597 - 8-bit shift register, parallel-in / serial-out, with input latches.
module ttl_74x597 (
    input  logic       clk_lat,        // load parallel inputs into latch
    input  logic       clk_shift, srclr_n,
    input  logic       shift_load_n,   // 0 = load latch into shifter, 1 = shift
    input  logic       sin,
    input  logic [7:0] d,
    output logic       qh
);
    logic [7:0] lat, shifter;
    always_ff @(posedge clk_lat) lat <= d;
    always_ff @(posedge clk_shift or negedge srclr_n) begin
        if (!srclr_n)            shifter <= 0;
        else if (!shift_load_n)  shifter <= lat;
        else                     shifter <= {shifter[6:0], sin};
    end
    assign qh = shifter[7];
endmodule
