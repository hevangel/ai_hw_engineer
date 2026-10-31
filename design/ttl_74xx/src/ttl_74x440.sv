// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x440.md.
// ttl_74x440 - Quad tridirectional bus transceiver, non-inverting.
// 3 directions: A->B, B->A, A->B (storage), B->A (storage). Simplified.
module ttl_74x440 (
    input  logic       oe_n,
    input  logic [1:0] dir,        // 00=A->B, 01=B->A, 10=hold, 11=tri
    input  logic [3:0] a_in, b_in,
    output logic [3:0] a_out, b_out
);
    always_comb begin
        a_out=0; b_out=0;
        if (!oe_n) case (dir)
            2'b00: b_out = a_in;
            2'b01: a_out = b_in;
            default: ;
        endcase
    end
endmodule
