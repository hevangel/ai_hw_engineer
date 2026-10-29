// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x306.md.
// ttl_74x306 - 8-bit LV-TTL to GTL+ bus transceiver (digital pass-through).
// Voltage translation is not modeled. dir selects direction.
module ttl_74x306 (
    input  logic       oe_n,
    input  logic       dir,
    input  logic [7:0] a_in, b_in,
    output logic [7:0] a_out, b_out,
    output logic       a_oe_n, b_oe_n
);
    always_comb begin
        if (oe_n) begin
            a_out = 0; b_out = 0; a_oe_n = 1; b_oe_n = 1;
        end else if (dir) begin
            b_out = a_in; a_out = 0; b_oe_n = 0; a_oe_n = 1;
        end else begin
            a_out = b_in; b_out = 0; a_oe_n = 0; b_oe_n = 1;
        end
    end
endmodule
