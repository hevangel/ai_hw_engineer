// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x2645.md.
// ttl_74x2645 - octal bus transceiver / MOS driver, non-inverting.
// Logically identical to ttl_74x645 (MOS-level drive strength is not modeled).
module ttl_74x2645 (
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
