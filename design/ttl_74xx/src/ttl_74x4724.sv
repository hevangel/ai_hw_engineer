// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x4724.md.
// ttl_74x4724 - 8-bit addressable latch (= 74x259-class).
// When le_n = 0, the addressed bit captures d_in; other bits hold.
// When clr_n = 0, all bits are cleared.
module ttl_74x4724 (
    input  logic       clr_n, le_n,
    input  logic       d_in,
    input  logic [2:0] addr,
    output logic [7:0] q
);
    always_latch begin
        if (!clr_n)     q = 8'b0;
        else if (!le_n) q[addr] = d_in;
    end
endmodule
