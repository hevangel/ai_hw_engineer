// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x444.md.
// ttl_74x444 - Quad tridirectional bus transceiver, mixed inv/non-inv.
module ttl_74x444 (
    input  logic       oe_n,
    input  logic [1:0] dir,
    input  logic [3:0] a_in, b_in,
    output logic [3:0] a_out, b_out
);
    always_comb begin
        a_out=0; b_out=0;
        if (!oe_n) case (dir)
            2'b00: b_out = a_in;
            2'b01: a_out = ~b_in;
            default: ;
        endcase
    end
endmodule
