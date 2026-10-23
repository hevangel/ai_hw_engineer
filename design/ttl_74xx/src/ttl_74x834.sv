// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x834.md.
// ttl_74x834 - 8-bit to 9-bit parity bus transceiver, inverting (3-state +OC).
//
// Inverting twin of ttl_74x833: bus outputs deliver the bitwise complement
// of their inputs in both directions. The parity-bit generation/check follows
// the bus values (note: for an 8-bit word, ^(~x) == ^x, so generated parity
// is the same value as the non-inverting 833 would produce when fed the
// original a_in — the parity bit just accompanies inverted data).
module ttl_74x834 (
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
    assign point_p  = ^{b_in, parity_in};

    always_comb begin
        a_out = 8'h00; b_out = 8'h00; parity_out = 1'b0;
        a_oe_n = 1'b1; b_oe_n = 1'b1; parity_oe_n = 1'b1;
        case ({oea_n, oeb_n})
            2'b10: begin
                b_out       = ~a_in;
                parity_out  = ~parity_a;
                b_oe_n      = 1'b0;
                parity_oe_n = 1'b0;
            end
            2'b01: begin
                a_out  = ~b_in;
                a_oe_n = 1'b0;
            end
            2'b00: begin
                b_out       = ~a_in;
                parity_out  = parity_a;
                b_oe_n      = 1'b0;
                parity_oe_n = 1'b0;
            end
            default: ;
        endcase
    end

    always_ff @(posedge clk or negedge clr_n) begin
        if (!clr_n) err_reg <= 1'b1;
        else        err_reg <= err_reg & point_p;
    end

    assign err_n = err_reg;
endmodule
