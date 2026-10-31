// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x323.md.
// ttl_74x323 - 8-bit bidirectional universal shift register, synchronous clear.
module ttl_74x323 (
    input  logic       clk,
    input  logic       clr_n,
    input  logic       oe_n,
    input  logic       s0, s1,
    input  logic       din_right,
    input  logic       din_left,
    input  logic [7:0] p,
    output logic [7:0] q
);
    logic [7:0] sr;
    always_ff @(posedge clk) begin
        if (!clr_n) sr <= 8'h00;
        else case ({s1, s0})
            2'b00: ;
            2'b01: sr <= {din_right, sr[7:1]};
            2'b10: sr <= {sr[6:0], din_left};
            2'b11: sr <= p;
        endcase
    end
    assign q = oe_n ? 8'h00 : sr;
endmodule
