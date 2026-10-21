// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x162373.md.
// ttl_74x162373 - 3.3-V ABT 16-bit transparent D-type latch (3-state).
module ttl_74x162373 (
    input  logic        le,
    input  logic        oe_n,
    input  logic [15:0] d,
    output logic [15:0] q
);
    logic [15:0] q_lat;
    always_latch begin
        if (le) q_lat = d;
    end
    assign q = oe_n ? 16'h0000 : q_lat;
endmodule
