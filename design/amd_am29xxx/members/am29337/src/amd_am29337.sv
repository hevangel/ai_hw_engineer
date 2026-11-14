// AMD Am29337 16-bit bounds checker, edge-accurate digital model.
//
// Source: AMD 1988 Am29C300/29300 Data Book, "Am29337 16-Bit Bounds
// Checker" (Issue 08548B, June 1987, PDF 231-241), Tables 1/2 and
// Figure 1 cascading (page images inspected).
//
// Two 16-bit limit registers loaded from the D bus on CP rising edges
// (ENL/ENU active low); two comparators qualify D against the limits
// (signed when SIGNED is high, unsigned otherwise); COL/COU carry
// semantics per Table 1 (the carry upgrades < to <=); OOB per Table 2
// (out of bounds unless both COL and COU are high, i.e. L < D < U with
// the carry qualification). Cascadable per Figure 1: low slices run
// with SIGNED low and feed COL/COU to the next slice's CIL/CIU.
module amd_am29337 (
  input  logic        clk_i,
  input  logic [15:0] d_i,
  input  logic        enl_n_i, enu_n_i,   // limit register load enables
  input  logic        signed_i,           // 1 = two's complement compare
  input  logic        cil_i, ciu_i,       // carry-ins: equal-so-far
  output logic        col_o, cou_o,       // L<D(=) and D<U(=) results
  output logic        oob_o               // out-of-bounds flag
`ifdef FORMAL
  , input logic fml_clk_i                   // formal-only property timebase
`endif
);

  logic [15:0] l_q, u_q;

  always_ff @(posedge clk_i) begin
    if (!enl_n_i) l_q <= d_i;
    if (!enu_n_i) u_q <= d_i;
  end

  // Comparisons: SIGNED selects two's complement (16-bit) vs unsigned.
  wire lt_l = signed_i ? ($signed(d_i) <  $signed(l_q)) : (d_i <  l_q);
  wire le_l = signed_i ? ($signed(d_i) <= $signed(l_q)) : (d_i <= l_q);
  wire lt_u = signed_i ? ($signed(d_i) <  $signed(u_q)) : (d_i <  u_q);
  wire le_u = signed_i ? ($signed(d_i) <= $signed(u_q)) : (d_i <= u_q);

  // Table 1: the carry upgrades the comparison from < to <=.
  assign col_o = cil_i ? le_l : lt_l;
  assign cou_o = ciu_i ? le_u : lt_u;
  // Table 2: out of bounds unless both carries show L < D < U.
  assign oob_o = !(col_o && cou_o);

`ifdef FORMAL
  `include "amd_am29337_props.sv"
`endif
endmodule
