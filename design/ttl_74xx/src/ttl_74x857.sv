// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x857.md.
// ttl_74x857 - hex 2-to-1 universal multiplexer with AND-mask, force-low, and
// inversion modes (3-state outputs). Per SN74ALS857 datasheet (SDAS170A).
//
// Six channels; each Y_i is a function of A_i and B_i selected by {S1, S0},
// optionally inverted by COMP. The 6 Y outputs plus an OPER=0 detector all
// share 3-state output buffers.
//
// Function table (per channel; the OPER detector spans all six channels):
//   COMP S1 S0  Y         OPER=0                       Y_oe  OPER_oe
//   L    L  L   A         H when all A inputs are L    en    en
//   L    L  H   B         H when all B inputs are L    en    en
//   L    H  L   A & B     Z                            en    Z
//   L    H  H   L         L                            en    en
//   H    L  L   ~A        H when all A inputs are L    en    en
//   H    L  H   ~B        H when all B inputs are L    en    en
//   H    H  L   ~(A & B)  Z                            en    Z
//   H    H  H   Z         Z                            Z     Z
module ttl_74x857 (
    input  logic       s0,
    input  logic       s1,
    input  logic       comp,
    input  logic [5:0] a,
    input  logic [5:0] b,
    output logic [5:0] y,
    output logic       oper_zero,
    output logic       y_oe_n,
    output logic       oper_oe_n
);
    logic [5:0] y_int;
    logic       oper_int;

    always_comb begin
        unique case ({s1, s0})
            2'b00: y_int = a;
            2'b01: y_int = b;
            2'b10: y_int = a & b;
            2'b11: y_int = 6'h00;
        endcase
        if (comp) y_int = ~y_int;
    end

    always_comb begin
        unique case ({s1, s0})
            2'b00:   oper_int = ~|a;
            2'b01:   oper_int = ~|b;
            2'b11:   oper_int = 1'b0;      // forced L (only when comp=0; high-Z handled by oper_oe_n)
            default: oper_int = 1'b0;       // unused — Y_oe_n covers the Hi-Z case
        endcase
    end

    assign y_oe_n    = comp & s1 & s0;
    assign oper_oe_n = (s1 & ~s0) | (s1 & s0 & comp);

    assign y         = y_oe_n    ? 6'h00 : y_int;
    assign oper_zero = oper_oe_n ? 1'b0  : oper_int;
endmodule
