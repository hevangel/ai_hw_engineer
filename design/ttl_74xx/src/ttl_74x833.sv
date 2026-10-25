// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x833.md.
// ttl_74x833 - 8-bit to 9-bit parity bus transceiver, non-inverting (3-state +OC).
//
// Per SN74ABT833 datasheet (SCBS195C). The chip combines an octal transceiver
// with a 9th parity I/O bit and a sticky error-flag register:
//
//   - {oea_n, oeb_n} = 11  -> Isolation: both A and B Hi-Z, PARITY Hi-Z.
//   - {oea_n, oeb_n} = 10  -> A->B transmit: B drives a_in, PARITY drives
//                             ~^a_in so that popcount(a_in) + PARITY is odd
//                             (odd-parity generation).
//   - {oea_n, oeb_n} = 01  -> B->A receive: A drives b_in, PARITY is input.
//                             Parity check = ^{b_in, parity_in}; sampled into
//                             the error register on each posedge of clk.
//   - {oea_n, oeb_n} = 00  -> A->B inverted-parity transmit: B drives a_in,
//                             PARITY drives ^a_in (forces a parity error in
//                             an odd-parity receiver). Used for diagnostics.
//
// The error register is async-cleared by clr_n low (sets err_n high = no error)
// and on each posedge clk holds err_n = err_n & point_p, i.e., it latches low
// once a parity error is sampled and stays low until cleared (sticky-low).
// /ERR is open-collector on the real chip; physical wired-AND is not modeled.
module ttl_74x833 (
    input  logic       clk,
    input  logic       clr_n,
    input  logic       oea_n,
    input  logic       oeb_n,
    input  logic [7:0] a_in,
    input  logic [7:0] b_in,
    input  logic       parity_in,
    output logic [7:0] a_out,
    output logic [7:0] b_out,
    output logic       parity_out,
    output logic       err_n,
    output logic       a_oe_n,
    output logic       b_oe_n,
    output logic       parity_oe_n
);
    logic parity_a, point_p;
    logic err_reg;

    assign parity_a = ^a_in;
    assign point_p  = ^{b_in, parity_in};   // 1 = no error under odd-parity

    always_comb begin
        a_out = 8'h00; b_out = 8'h00; parity_out = 1'b0;
        a_oe_n = 1'b1; b_oe_n = 1'b1; parity_oe_n = 1'b1;
        case ({oea_n, oeb_n})
            2'b10: begin
                b_out       = a_in;
                parity_out  = ~parity_a;
                b_oe_n      = 1'b0;
                parity_oe_n = 1'b0;
            end
            2'b01: begin
                a_out  = b_in;
                a_oe_n = 1'b0;
            end
            2'b00: begin
                b_out       = a_in;
                parity_out  = parity_a;
                b_oe_n      = 1'b0;
                parity_oe_n = 1'b0;
            end
            default: ;  // 2'b11 isolation
        endcase
    end

    always_ff @(posedge clk or negedge clr_n) begin
        if (!clr_n) err_reg <= 1'b1;
        else        err_reg <= err_reg & point_p;
    end

    assign err_n = err_reg;
endmodule
