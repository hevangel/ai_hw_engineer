// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x9164.md.
// ttl_74x9164 - 8-bit shift register (serial in/out, parallel in/out).
// Mode-controlled bidirectional shift register:
//   mode = 00: hold
//   mode = 01: shift right (sin -> q[0] -> q[7] -> sout_r)
//   mode = 10: shift left  (sin -> q[7] -> q[0] -> sout_l)
//   mode = 11: parallel load from d
module ttl_74x9164 (
    input  logic       clk, clr_n,
    input  logic [1:0] mode,
    input  logic       sin,
    input  logic [7:0] d,
    output logic [7:0] q,
    output logic       sout_r,   // serial out, right shift
    output logic       sout_l    // serial out, left shift
);
    always_ff @(posedge clk or negedge clr_n) begin
        if (!clr_n) q <= 8'b0;
        else unique case (mode)
            2'b00: ;
            2'b01: q <= {sin, q[7:1]};      // shift right
            2'b10: q <= {q[6:0], sin};      // shift left
            2'b11: q <= d;
        endcase
    end
    assign sout_r = q[0];
    assign sout_l = q[7];
endmodule
