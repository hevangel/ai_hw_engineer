// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x322.md.
// ttl_74x322 - 8-bit shift register with sign extend.
// On posedge clk: shift right with new MSB = sign bit (q[7]) if sign_extend=1, else din.
module ttl_74x322 (
    input  logic       clk,
    input  logic       clr_n,
    input  logic       s_e_n,     // sign-extend enable (active low)
    input  logic       s_l_n,     // parallel load (active low)
    input  logic       din,
    input  logic [7:0] p,
    output logic [7:0] q,
    output logic       q_h
);
    logic msb_in;
    assign msb_in = !s_e_n ? q[7] : din;

    always_ff @(posedge clk or negedge clr_n) begin
        if (!clr_n)       q <= 8'h00;
        else if (!s_l_n)  q <= p;
        else              q <= {msb_in, q[7:1]};
    end
    assign q_h = q[0];
endmodule
