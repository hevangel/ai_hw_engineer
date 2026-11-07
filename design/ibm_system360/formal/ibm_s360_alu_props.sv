// Exhaustive combinational formal checks for the S/360 arithmetic unit.
//
// The reference expressions below are written from A22-6821-7 (pp. 27-30,
// 53-55) in a different form from the RTL: condition codes are derived from
// the manual's prose (zero/negative/positive/overflow, carry-out semantics,
// algebraic versus binary comparison) rather than from the RTL's internal
// structure. With no state in the design, a depth-1 BMC check covers every
// possible operand pair and operation selector, so these are complete proofs
// for the combinational function, not samples.
//
// Limitation: the reference expressions are a second reading of the same
// primary source by the same author. They catch implementation mistakes, not
// a shared misreading of the manual; instruction-level agreement against an
// independent emulator is tracked by issue #383.
`timescale 1ns/1ps

module ibm_s360_alu_props;

  `include "ibm_s360_defs.svh"

  logic [2:0]  op;
  logic [31:0] a, b;
  logic [31:0] y;
  logic [1:0]  cc;
  logic        ovf;

  ibm_s360_alu dut (
      .op (op),
      .a  (a),
      .b  (b),
      .y  (y),
      .cc (cc),
      .ovf(ovf)
  );

  // Reference model of the manual's rules.
  logic [31:0] ref_add, ref_sub, ref_and, ref_or, ref_xor;
  logic        ref_add_ovf, ref_sub_ovf;
  logic [1:0]  ref_add_cc, ref_sub_cc, ref_cmp_cc, ref_clr_cc, ref_logic_cc, ref_test_cc;

  assign ref_add = a + b;
  assign ref_sub = a - b;
  assign ref_and = a & b;
  assign ref_or  = a | b;
  assign ref_xor = a ^ b;

  // "The carries out of the sign-bit position and the high-order numeric bit
  // position disagree" (p. 27), expressed as a sign rule.
  assign ref_add_ovf = (a[31] == b[31]) && (ref_add[31] != a[31]);
  assign ref_sub_ovf = (a[31] != b[31]) && (ref_sub[31] != a[31]);

  assign ref_add_cc = ref_add_ovf ? 2'd3
                    : (ref_add == 32'd0) ? 2'd0
                    : ref_add[31] ? 2'd1 : 2'd2;
  assign ref_sub_cc = ref_sub_ovf ? 2'd3
                    : (ref_sub == 32'd0) ? 2'd0
                    : ref_sub[31] ? 2'd1 : 2'd2;
  assign ref_cmp_cc = (a == b) ? 2'd0 : ($signed(a) < $signed(b)) ? 2'd1 : 2'd2;
  assign ref_clr_cc = (a == b) ? 2'd0 : (a < b) ? 2'd1 : 2'd2;
  assign ref_logic_cc = ({32'd0, ref_and} == 32'd0) ? 2'd0 : 2'd1;
  assign ref_test_cc = (a == 32'd0) ? 2'd0 : a[31] ? 2'd1 : 2'd2;

  always_comb begin
    unique case (op)
      ALU_ADD: begin
        assert (y == ref_add);
        assert (ovf == ref_add_ovf);
        assert (cc == ref_add_cc);
        assert ((cc == 2'd3) == ref_add_ovf);
      end
      ALU_SUB: begin
        assert (y == ref_sub);
        assert (ovf == ref_sub_ovf);
        assert (cc == ref_sub_cc);
        assert ((cc == 2'd3) == ref_sub_ovf);
      end
      ALU_CMP: begin
        assert (cc == ref_cmp_cc);
        assert (cc != 2'd3);
        assert (ovf == 1'b0);
      end
      ALU_CLR: begin
        assert (cc == ref_clr_cc);
        assert (cc != 2'd3);
      end
      ALU_AND: begin
        assert (y == ref_and);
        assert (cc == ((y == 32'd0) ? 2'd0 : 2'd1));
        assert (ovf == 1'b0);
      end
      ALU_OR: begin
        assert (y == ref_or);
        assert (cc == ((y == 32'd0) ? 2'd0 : 2'd1));
        assert (ovf == 1'b0);
      end
      ALU_XOR: begin
        assert (y == ref_xor);
        assert (cc == ((y == 32'd0) ? 2'd0 : 2'd1));
        assert (ovf == 1'b0);
      end
      ALU_TEST: begin
        assert (y == a);
        assert (cc == ref_test_cc);
        assert (ovf == 1'b0);
      end
      default: begin
        assert (y == 32'd0);
        assert (cc == 2'd0);
        assert (ovf == 1'b0);
      end
    endcase
  end

  // Non-vacuity: every selector produces at least one reachable result.
  always_comb begin
    cover (op == 3'd0 && a == 32'h7FFF_FFFF && b == 32'd1 && y == 32'h8000_0000);
    cover (op == 3'd1 && a == 32'h8000_0000 && b == 32'd1 && y == 32'h7FFF_FFFF);
    cover (op == 3'd2 && a == 32'h8000_0000 && b == 32'd1 && cc == 2'd1);
    cover (op == 3'd3 && a == 32'hFFFF_FFFF && b == 32'd1 && cc == 2'd2);
    cover (op == 3'd4 && y == 32'd0);
    cover (op == 3'd5 && y == 32'hFFFF_FFFF);
    cover (op == 3'd6 && y == 32'd0);
    cover (op == 3'd7 && a == 32'h8000_0000 && cc == 2'd1);
  end

endmodule
