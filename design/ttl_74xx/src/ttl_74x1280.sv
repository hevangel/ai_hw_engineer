// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x1280.md.
// =============================================================================
// ttl_74x1280 - 9-bit parity generator/checker with registered outputs
//
// Original part number : 74x1280 (QS74FCT1280)
// Datasheet reference  : Quality Semiconductor QSFCT280T/1280T (MDSL-00014-01)
//
// Function
// --------
// A 9-bit parity generator/checker (relative of the '280) with an I8 enable and
// a clocked register on the parity result.
//
//   Combinational parity over I0..I7, plus I8 when en8 is high:
//     sum_o (odd)  = ^i[7:0] ^ (en8 & i8)
//     sum_e (even) = ~sum_o
//   (en8 low excludes I8 from the parity, per the Function Table.)
//
//   Registered outputs q_sum_e / q_sum_o (parity check on the next cycle):
//     - clr_n low  : asynchronous clear -> 0
//     - clk rising, cen_n low : load (q_sum_e <= sum_e, q_sum_o <= sum_o)
//     - clk rising, cen_n high: hold (clock disabled)
//     - oer_n high : registered outputs are three-stated (modeled as 0)
//   The combinational sum_e / sum_o are always driven.
//
// FPGA notes
// ----------
// Async-clear register; 3-state on registered outputs modeled as muxed 0.
//
// Pin mapping (FCT1280, 20-pin): I5=1,I6=2,I7=3, EN8=4, I8=5, Se=6, So=7,
// QSe=8, QSo=9, GND=10, /CLR=11, /OER=12, /CEN=13, CLK=14, I0=15,I1=16,I2=17,
// I3=18,I4=19, Vcc=20.
//
// Unsupported physical behavior
// -----------------------------
// True three-state high-Z on the registered outputs (modeled as driven 0).
// =============================================================================

module ttl_74x1280 (
    input  logic [7:0] i,        // data inputs I0..I7
    input  logic       i8,       // 9th data input
    input  logic       en8,      // enable I8 (high = include in parity)
    input  logic       clk,      // register clock (posedge)
    input  logic       cen_n,    // clock enable, active low
    input  logic       clr_n,    // register clear, active low (async)
    input  logic       oer_n,    // registered-output enable, active low (3-state)
    output logic       sum_e,    // combinational even parity
    output logic       sum_o,    // combinational odd parity
    output logic       q_sum_e,  // registered even parity
    output logic       q_sum_o   // registered odd parity
);
    logic par_odd, qe, qo;

    assign par_odd = ^i ^ (en8 & i8);
    assign sum_o = par_odd;
    assign sum_e = ~par_odd;

    always_ff @(posedge clk or negedge clr_n) begin
        if (!clr_n) begin
            qe <= 1'b0;
            qo <= 1'b0;
        end else if (!cen_n) begin
            qe <= sum_e;
            qo <= sum_o;
        end
    end

    assign q_sum_e = oer_n ? 1'b0 : qe;
    assign q_sum_o = oer_n ? 1'b0 : qo;
endmodule
