// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x979.md.
// ttl_74x979 - 9-bit registered transceiver with parity gen/check (FutureBus).
//
// Two registers (A->B and B->A) clocked by clk. The 9-bit data section is
// accompanied by a parity I/O that is generated on transmit and checked on
// receive. Odd parity (matching SN74BCT833/979 convention): the parity bit
// is the complement of the XOR of the data so that popcount(data) + parity
// is odd. Error flag is sticky-low until cleared by clr_n.
module ttl_74x979 (
    input  logic       clk,
    input  logic       clr_n,
    input  logic       dir,            // 1 = A->B (register A_in, drive B/parity_out)
                                        // 0 = B->A (register B_in, drive A/parity_out)
    input  logic       oe_n,           // global 3-state enable
    input  logic [8:0] a_in,
    input  logic [8:0] b_in,
    input  logic       parity_in,      // checked on receive side
    output logic [8:0] a_out,
    output logic [8:0] b_out,
    output logic       parity_out,
    output logic       err_n,
    output logic       hiz
);
    logic [8:0] ab_reg, ba_reg;
    logic err_reg;

    always_ff @(posedge clk or negedge clr_n) begin
        if (!clr_n) begin
            ab_reg <= 9'b0;
            ba_reg <= 9'b0;
            err_reg <= 1'b1;
        end else begin
            if ( dir) ab_reg <= a_in;
            else      ba_reg <= b_in;
            // Parity is checked only on the receive direction (B->A) and
            // only when outputs are enabled.  Odd parity convention: the
            // XOR of data and parity must be 1.  Mismatch latches err_reg
            // low (sticky until clr_n).
            if (!dir && !oe_n)
                err_reg <= err_reg & (^{b_in, parity_in});
        end
    end

    logic [8:0] tx_data;
    assign tx_data = dir ? ab_reg : ba_reg;

    assign b_out      = (!oe_n &&  dir) ? tx_data : 9'b0;
    assign a_out      = (!oe_n && !dir) ? tx_data : 9'b0;
    assign parity_out = (!oe_n)         ? ~(^tx_data) : 1'b0;
    assign err_n      = err_reg;
    assign hiz        = oe_n;
endmodule
