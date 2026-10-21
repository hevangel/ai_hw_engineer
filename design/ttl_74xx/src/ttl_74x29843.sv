// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x29843.md.
// ttl_74x29843 - 9-bit bus interface D-type latches (= 74x2843).
module ttl_74x29843 (
    input  logic        oe_n, le, rst_n,
    input  logic [8:0]  d,
    output logic [8:0]  q,
    output logic        hiz
);
    logic [8:0] r;
    always_latch begin
        if (!rst_n) r = 9'b0;
        else if (le) r = d;
    end
    assign q   = oe_n ? 9'b0 : r;
    assign hiz = oe_n;
endmodule
