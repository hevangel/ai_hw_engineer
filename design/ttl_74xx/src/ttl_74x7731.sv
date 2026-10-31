// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x7731.md.
// ttl_74x7731 - Quad 64-bit static shift register.
// Four independent serial-in / serial-out 64-bit shift registers sharing a
// clock pin.  Each rank shifts its `ser_in` into bit 0 of its register and
// emits the previous bit-63 on its `ser_out`.
module ttl_74x7731 (
    input  logic       clk,
    input  logic [3:0] ser_in,
    output logic [3:0] ser_out
);
    logic [63:0] sr [0:3];
    always_ff @(posedge clk) begin
        for (int i = 0; i < 4; i++)
            sr[i] <= {sr[i][62:0], ser_in[i]};
    end
    always_comb begin
        ser_out[0] = sr[0][63];
        ser_out[1] = sr[1][63];
        ser_out[2] = sr[2][63];
        ser_out[3] = sr[3][63];
    end
endmodule
