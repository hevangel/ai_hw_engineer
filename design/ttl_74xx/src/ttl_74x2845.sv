// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x2845.md.
// ttl_74x2845 - 8-bit transparent latch with async reset and multiple output enable.
module ttl_74x2845 (
    input  logic        oe1_n, oe2_n, le, rst_n,
    input  logic [7:0]  d,
    output logic [7:0]  q,
    output logic        hiz
);
    logic [7:0] r;
    wire oe_n = oe1_n | oe2_n;     // both must be low for outputs to be enabled
    always_latch begin
        if (!rst_n) r = 8'b0;
        else if (le) r = d;
    end
    assign q   = oe_n ? 8'b0 : r;
    assign hiz = oe_n;
endmodule
