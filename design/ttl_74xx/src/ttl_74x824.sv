// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x824.md.
// ttl_74x824 - 9-bit bus interface flip-flop, inverting inputs (3-state).
// Inverting-D twin of ttl_74x823.
module ttl_74x824 (
    input  logic       clk,
    input  logic       clr_n,
    input  logic       clken_n,
    input  logic       oe_n,
    input  logic [8:0] d,
    output logic [8:0] q,
    output logic       q_oe_n
);
    logic [8:0] q_lat;

    always_ff @(posedge clk or negedge clr_n) begin
        if (!clr_n)         q_lat <= 9'b0;
        else if (!clken_n)  q_lat <= ~d;
    end

    assign q_oe_n = oe_n;
    assign q      = oe_n ? 9'b0 : q_lat;
endmodule
