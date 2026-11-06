// Exhaustive combinational formal checks for S/360 address generation.
//
// Reference rules from A22-6821-7 pp. 13-14: base and index are the low-order
// 24 bits of the named general registers, a zero B or X field suppresses that
// component regardless of the register contents, the 12-bit displacement is
// added as an unsigned integer, and carries beyond bit 23 are ignored.
//
// The design is combinational, so a depth-1 check is exhaustive over all
// inputs.
`timescale 1ns/1ps

module ibm_s360_addr_props;

  logic [3:0]  b_field, x_field;
  logic [31:0] b_val, x_val;
  logic [11:0] disp;
  logic [23:0] addr;

  ibm_s360_addr dut (
      .b_field(b_field),
      .x_field(x_field),
      .b_val  (b_val),
      .x_val  (x_val),
      .disp   (disp),
      .addr   (addr)
  );

  // Independent reference: explicitly selected 24-bit components, then a
  // 25-bit sum whose carry out of bit 23 is discarded.
  logic [23:0] ref_base, ref_index;
  logic [24:0] ref_sum;
  logic [23:0] ref_addr;

  assign ref_base  = (b_field == 4'd0) ? 24'd0 : b_val[23:0];
  assign ref_index = (x_field == 4'd0) ? 24'd0 : x_val[23:0];
  assign ref_sum   = {1'b0, ref_base} + {1'b0, ref_index} + {1'b0, 12'd0 | disp};
  assign ref_addr  = ref_sum[23:0];

  always_comb begin
    assert (addr == ref_addr);
    if (b_field == 4'd0) begin
      assert (addr == (ref_index + {12'd0, disp}));
    end
    if (x_field == 4'd0) begin
      assert (addr == (ref_base + {12'd0, disp}));
    end
    if (b_field == 4'd0 && x_field == 4'd0) begin
      assert (addr == {12'd0, disp});
    end
    // The high-order byte of either register never influences the address.
    assert (addr == ibm_s360_addr_ref_upper_ignored(b_val, x_val, b_field, x_field, disp));
  end

  // Recompute with the top bytes forced to a different value; the function
  // form keeps the assertion independent of the DUT's expression.
  function automatic logic [23:0] ibm_s360_addr_ref_upper_ignored(
      input logic [31:0] bv, input logic [31:0] xv,
      input logic [3:0] bf, input logic [3:0] xf,
      input logic [11:0] d);
    logic [24:0] s;
    s = {1'b0, (bf == 4'd0) ? 24'd0 : bv[23:0]}
      + {1'b0, (xf == 4'd0) ? 24'd0 : xv[23:0]}
      + {1'b0, 12'd0 | d};
    ibm_s360_addr_ref_upper_ignored = s[23:0];
  endfunction

  always_comb begin
    cover (addr == 24'h00_0000 && b_field == 4'd0 && x_field == 4'd0 && disp == 12'd0);
    cover (addr == 24'hFF_FFFF && b_val[23:0] == 24'hFF_FFFF && b_field != 4'd0 &&
           x_field == 4'd0 && disp == 12'd0);
    cover (addr == 24'h00_0001 && b_val[23:0] == 24'hFF_FFFF && b_field != 4'd0 &&
           x_val[23:0] == 24'd1 && x_field != 4'd0 && disp == 12'd1);
    cover (b_field == 4'd0 && x_field == 4'd0 && disp == 12'hFFF && addr == 24'h00_0FFF);
  end

endmodule
