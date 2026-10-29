// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x598.md.
// ttl_74x598 - 8-bit shift register with selectable parallel-in/out and input latches.
module ttl_74x598 (
    input  logic       clk_lat,            // latch parallel input
    input  logic       clk_shift, srclr_n,
    input  logic       shift_load_n,       // 0 = load latch into shifter
    input  logic       sin,
    input  logic [7:0] d,
    output logic [7:0] q,                  // parallel out = shifter
    output logic       qh                  // serial MSB
);
    logic [7:0] lat;
    always_ff @(posedge clk_lat) lat <= d;
    always_ff @(posedge clk_shift or negedge srclr_n) begin
        if (!srclr_n)           q <= 0;
        else if (!shift_load_n) q <= lat;
        else                    q <= {q[6:0], sin};
    end
    assign qh = q[7];
endmodule
