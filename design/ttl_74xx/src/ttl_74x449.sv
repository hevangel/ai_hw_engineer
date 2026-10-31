// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x449.md.
// ttl_74x449 - Quad bus transceiver, non-inverting.
module ttl_74x449 (
    input  logic       oe_n,
    input  logic       dir,
    input  logic [3:0] a_in, b_in,
    output logic [3:0] a_out, b_out
);
    always_comb begin
        a_out=0; b_out=0;
        if (!oe_n) begin
            if (dir) b_out = a_in;
            else     a_out = b_in;
        end
    end
endmodule
