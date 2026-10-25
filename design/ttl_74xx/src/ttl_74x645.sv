// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x645.md.
// ttl_74x645 - Octal bus transceiver, non-inverting, 3-state (functionally equivalent to 74x245).
module ttl_74x645 (
    input  logic       oe_n,
    input  logic       dir,
    input  logic [7:0] a_in,
    input  logic [7:0] b_in,
    output logic [7:0] a_out,
    output logic [7:0] b_out,
    output logic       a_oe_n,
    output logic       b_oe_n
);
    always_comb begin
        if (oe_n) begin
            a_out  = 8'h00; b_out  = 8'h00;
            a_oe_n = 1'b1;  b_oe_n = 1'b1;
        end else if (dir) begin
            a_out  = 8'h00; b_out  = a_in;
            a_oe_n = 1'b1;  b_oe_n = 1'b0;
        end else begin
            a_out  = b_in;  b_out  = 8'h00;
            a_oe_n = 1'b0;  b_oe_n = 1'b1;
        end
    end
endmodule
