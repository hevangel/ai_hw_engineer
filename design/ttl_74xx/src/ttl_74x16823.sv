// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x16823.md.
// ttl_74x16823 - 18-bit bus interface flip-flop with /CLR, /CLKEN, /OE (3-state).
// Widebus extension of 74x823 from 9-bit to 18-bit.
module ttl_74x16823 (
    input  logic        clk,
    input  logic        clr_n,
    input  logic        clken_n,
    input  logic        oe_n,
    input  logic [17:0] d,
    output logic [17:0] q,
    output logic        q_oe_n
);
    logic [17:0] q_lat;
    always_ff @(posedge clk or negedge clr_n) begin
        if (!clr_n)        q_lat <= 18'b0;
        else if (!clken_n) q_lat <= d;
    end
    assign q_oe_n = oe_n;
    assign q      = oe_n ? 18'b0 : q_lat;
endmodule
