// IBM System/360 32-bit fixed-point arithmetic and logical unit.
//
// Semantics follow A22-6821-7 (Principles of Operation, eighth edition):
//   Add        pp. 27-28: CC 0 zero, 1 negative, 2 positive, 3 overflow.
//   Subtract   p. 29   : CC 0 zero, 1 negative, 2 positive, 3 overflow.
//   Add Logical pp. 29-30: CC bit 34 = carry out of the sign position,
//                          bit 35 = sum not zero.
//   Compare    p. 30   : algebraic comparison of 32-bit signed integers,
//                        CC 0 equal, 1 first low, 2 first high (3 unused).
//   Compare Logical p. 55: binary comparison, all codes valid.
//   AND/OR/EXCLUSIVE OR p. 55: CC 0 all-zero result, 1 nonzero result.
//   Load and Test p. 27: CC 0 zero, 1 negative, 2 positive.
//
// Comparison deliberately does not reuse the 32-bit subtractor's condition
// code: a signed comparison must remain exact when the difference overflows
// 32 bits (for example 0x8000_0000 compared with 1). Both comparisons are
// computed with a 33-bit reference difference so no overflow is possible.

`timescale 1ns/1ps

`ifndef IBM_S360_ALU_SV
`define IBM_S360_ALU_SV

module ibm_s360_alu (
    input  logic [2:0]  op,
    input  logic [31:0] a,
    input  logic [31:0] b,
    output logic [31:0] y,
    output logic [1:0]  cc,
    output logic        ovf
);

  `include "ibm_s360_defs.svh"

  // Exact 33-bit comparison results: bit 32 is the sign of the difference or
  // the borrow out of the sign position.
  logic [32:0] cmp33;
  logic [32:0] ucmp33;

  assign cmp33  = {a[31], a} - {b[31], b};  // sign-extended signed difference
  assign ucmp33 = {1'b0, a} - {1'b0, b};    // unsigned difference, bit 32 = borrow

  logic [31:0] add_y;
  logic [31:0] sub_y;
  logic        add_ovf;
  logic        sub_ovf;

  assign add_y   = a + b;
  assign sub_y   = a - b;
  // Overflow: the carries out of the sign position and the high-order numeric
  // bit position disagree (A22-6821-7 pp. 27-29).
  assign add_ovf = (a[31] & b[31] & ~add_y[31]) | (~a[31] & ~b[31] & add_y[31]);
  assign sub_ovf = (~a[31] & b[31] & sub_y[31]) | (a[31] & ~b[31] & ~sub_y[31]);

  logic [1:0] add_cc;
  logic [1:0] sub_cc;
  logic [1:0] cmp_cc;
  logic [1:0] ucmp_cc;
  logic [1:0] test_cc;

  // Arithmetic condition codes; overflow dominates a zero result.
  assign add_cc = add_ovf ? 2'd3 : (add_y == 32'd0) ? 2'd0 : (add_y[31] ? 2'd1 : 2'd2);
  assign sub_cc = sub_ovf ? 2'd3 : (sub_y == 32'd0) ? 2'd0 : (sub_y[31] ? 2'd1 : 2'd2);

  // Algebraic comparison of signed integers, computed without 32-bit overflow.
  assign cmp_cc = (cmp33 == 33'd0) ? 2'd0 : (cmp33[32] ? 2'd1 : 2'd2);
  // Binary comparison, all codes valid.
  assign ucmp_cc = (ucmp33 == 33'd0) ? 2'd0 : (ucmp33[32] ? 2'd1 : 2'd2);
  // LOAD AND TEST: zero, negative, positive.
  assign test_cc = (a == 32'd0) ? 2'd0 : (a[31] ? 2'd1 : 2'd2);

  always_comb begin
    y   = 32'd0;
    cc  = 2'd0;
    ovf = 1'b0;
    unique case (op)
      ALU_ADD: begin
        y   = add_y;
        cc  = add_cc;
        ovf = add_ovf;
      end
      ALU_SUB: begin
        y   = sub_y;
        cc  = sub_cc;
        ovf = sub_ovf;
      end
      ALU_CMP: begin
        y  = 32'd0;
        cc = cmp_cc;
      end
      ALU_CLR: begin
        y  = 32'd0;
        cc = ucmp_cc;
      end
      ALU_AND: begin
        y  = a & b;
        cc = (y == 32'd0) ? 2'd0 : 2'd1;
      end
      ALU_OR: begin
        y  = a | b;
        cc = (y == 32'd0) ? 2'd0 : 2'd1;
      end
      ALU_XOR: begin
        y  = a ^ b;
        cc = (y == 32'd0) ? 2'd0 : 2'd1;
      end
      ALU_TEST: begin
        y  = a;
        cc = test_cc;
      end
      default: begin
        y   = 32'd0;
        cc  = 2'd0;
        ovf = 1'b0;
      end
    endcase
  end

`ifdef FORMAL
  // The logical condition code only distinguishes zero from nonzero, and a
  // comparison never reports the "unused" code 3.
  always_comb begin
    if ((op == ALU_AND) || (op == ALU_OR) || (op == ALU_XOR)) begin
      assert ((cc == 2'd0) == (y == 32'd0));
    end
    if ((op == ALU_CMP) || (op == ALU_CLR)) begin
      assert (cc != 2'd3);
      assert (y == 32'd0);
    end
  end
`endif

endmodule

`endif
