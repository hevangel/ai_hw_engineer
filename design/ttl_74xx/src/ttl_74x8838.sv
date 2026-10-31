// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x8838.md.
// ttl_74x8838 - 64-bit barrel shifter.
// Combinational barrel shifter: rotates the 64-bit input `a` left by `shft`
// positions when `dir=0` (left) or right when `dir=1`.
module ttl_74x8838 (
    input  logic        dir,
    input  logic [5:0]  shft,
    input  logic [63:0] a,
    output logic [63:0] y
);
    logic [5:0] inv_shft;
    assign inv_shft = 6'((7'd64 - {1'b0, shft}) & 7'h3F);
    always_comb begin
        if (dir) y = (a >> shft) | (a << inv_shft);
        else     y = (a << shft) | (a >> inv_shft);
    end
endmodule
