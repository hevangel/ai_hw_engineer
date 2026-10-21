// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x4245.md.
// ttl_74x4245 - 8-bit 3V/5V translating bus transceiver (= 74x245).
// Voltage-level translation is a physical/electrical feature; the logic
// behavior is identical to 74x245.
module ttl_74x4245 (
    input  logic       oe_n, dir,
    input  logic [7:0] a_in, b_in,
    output logic [7:0] a_out, b_out,
    output logic       a_hiz, b_hiz
);
    assign b_out = (!oe_n &&  dir) ? a_in : 8'b0;
    assign a_out = (!oe_n && !dir) ? b_in : 8'b0;
    assign b_hiz = oe_n || !dir;
    assign a_hiz = oe_n ||  dir;
endmodule
