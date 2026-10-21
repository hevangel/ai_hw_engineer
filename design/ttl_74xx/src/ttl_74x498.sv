// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x498.md.
// ttl_74x498 - 8-bit bidirectional shift register with parallel inputs.
module ttl_74x498 (
    input  logic       clk, clr_n,
    input  logic       s0, s1,
    input  logic       din_right, din_left,
    input  logic [7:0] p,
    output logic [7:0] q
);
    always_ff @(posedge clk or negedge clr_n) begin
        if (!clr_n) q <= 0;
        else case ({s1, s0})
            2'b00: ;
            2'b01: q <= {din_right, q[7:1]};
            2'b10: q <= {q[6:0], din_left};
            2'b11: q <= p;
        endcase
    end
endmodule
