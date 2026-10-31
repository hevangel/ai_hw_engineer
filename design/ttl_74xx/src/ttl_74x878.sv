// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x878.md.
// ttl_74x878 - Dual 4-bit D flip-flop, synchronous clear, non-inverting (3-state).
// Like ttl_74x874 but clear is synchronous (sampled on posedge clk along with D).
module ttl_74x878 (
    input  logic       clk1,
    input  logic       sclr1_n,
    input  logic       oe1_n,
    input  logic [3:0] d1,
    output logic [3:0] q1,
    output logic       q1_oe_n,
    input  logic       clk2,
    input  logic       sclr2_n,
    input  logic       oe2_n,
    input  logic [3:0] d2,
    output logic [3:0] q2,
    output logic       q2_oe_n
);
    logic [3:0] q1_lat, q2_lat;

    always_ff @(posedge clk1) begin
        if (!sclr1_n) q1_lat <= 4'b0;
        else          q1_lat <= d1;
    end

    always_ff @(posedge clk2) begin
        if (!sclr2_n) q2_lat <= 4'b0;
        else          q2_lat <= d2;
    end

    assign q1_oe_n = oe1_n;
    assign q2_oe_n = oe2_n;
    assign q1      = oe1_n ? 4'b0 : q1_lat;
    assign q2      = oe2_n ? 4'b0 : q2_lat;
endmodule
