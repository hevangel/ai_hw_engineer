`timescale 1ns / 1ps
// Documented MUL/IMUL/DIV/IDIV results and the AAM divide; undefined flags
// are handled by the caller. Multiplication is combinational. Division is
// an iterative restoring divider: start_i latches the operands and the
// magnitude quotient/remainder settle after 32 clocks, so no wide
// combinational divider sits on the core's critical path (review #286
// finding 6). Signed results are formed from magnitudes with the same
// truncation and 8086 IDIV range rules as before.
module intel_8086_muldiv (
    input logic clk,
    rst_n,
    input logic start_i,
    aam_i,
    input logic wide_i,
    input logic [1:0] kind_i,
    input logic [15:0] operand_i,
    ax_i,
    dx_i,
    input logic [7:0] aam_divisor_i,
    output logic [15:0] ax_o,
    dx_o,
    output logic carry_o,
    divide_error_o,
    divide_done_o,
    output logic [7:0] aam_quotient_o,
    aam_remainder_o
);
  logic [31:0] product;
  logic signed [31:0] signed_product;
  // Divider state, latched at start_i.
  logic [31:0] quotient, start_magnitude;
  logic [16:0] remainder, start_divisor;
  logic [15:0] divisor;
  logic [5:0] steps;
  logic busy, valid, div_wide, div_signed, negate_quotient, negate_remainder;
  logic [16:0] shifted;
  logic signed [32:0] signed_quotient;
  logic signed [16:0] signed_remainder;
  logic signed [32:0] start_dividend;
  logic signed [16:0] start_signed_divisor;
  logic start_signed;

  always_comb begin
    start_signed = !aam_i && kind_i == 3;
    start_dividend = aam_i ? 33'(ax_i[7:0]) :
        start_signed ? (wide_i ? $signed({dx_i[15], dx_i, ax_i}) : $signed({{17{ax_i[15]}}, ax_i})) :
        (wide_i ? $signed({1'b0, dx_i, ax_i}) : $signed({17'b0, ax_i}));
    start_signed_divisor = aam_i ? 17'(aam_divisor_i) :
        start_signed ? (wide_i ? $signed({operand_i[15], operand_i}) : $signed({{9{operand_i[7]}}, operand_i[7:0]})) :
        (wide_i ? $signed({1'b0, operand_i}) : $signed({9'b0, operand_i[7:0]}));
    start_magnitude = start_dividend < 0 ? 32'(-start_dividend) : 32'(start_dividend);
    start_divisor = start_signed_divisor < 0 ? 17'(-start_signed_divisor) : 17'(start_signed_divisor);
  end

  assign shifted = {remainder[15:0], quotient[31]};
  always_ff @(posedge clk) begin
    if (!rst_n) begin
      quotient <= 0;
      remainder <= 0;
      divisor <= 0;
      steps <= 0;
      busy <= 0;
      valid <= 0;
      div_wide <= 0;
      div_signed <= 0;
      negate_quotient <= 0;
      negate_remainder <= 0;
    end else if (start_i) begin
      quotient <= start_magnitude;
      remainder <= 0;
      divisor <= start_divisor[15:0];
      steps <= 32;
      busy <= 1;
      valid <= 0;
      div_wide <= wide_i && !aam_i;
      div_signed <= start_signed;
      negate_quotient <= (start_dividend < 0) != (start_signed_divisor < 0);
      negate_remainder <= start_dividend < 0;
    end else if (busy) begin
      // Restoring step: shift one dividend bit into the partial remainder.
      if (shifted >= {1'b0, divisor}) begin
        remainder <= shifted - {1'b0, divisor};
        quotient <= {quotient[30:0], 1'b1};
      end else begin
        remainder <= shifted;
        quotient <= {quotient[30:0], 1'b0};
      end
      steps <= steps - 6'd1;
      if (steps == 1) begin
        busy <= 0;
        valid <= 1;
      end
    end
  end
  assign divide_done_o = valid && !busy && !start_i;
  assign aam_quotient_o = quotient[7:0];
  assign aam_remainder_o = remainder[7:0];

  always_comb begin
    product = wide_i ? (32'(ax_i) * 32'(operand_i)) : (32'(ax_i[7:0]) * 32'(operand_i[7:0]));
    signed_product = wide_i ?
        ($signed(ax_i) * $signed(operand_i)) : ($signed(ax_i[7:0]) * $signed(operand_i[7:0]));
    signed_quotient = negate_quotient ? -$signed({1'b0, quotient}) : $signed({1'b0, quotient});
    signed_remainder = negate_remainder ? -$signed(remainder) : $signed(remainder);
    ax_o = ax_i;
    dx_o = dx_i;
    carry_o = 0;
    divide_error_o = 0;
    case (kind_i)
      0: begin
        ax_o = product[15:0];
        if (wide_i) dx_o = product[31:16];
        carry_o = wide_i ? product[31:16] != 0 : product[15:8] != 0;
      end
      1: begin
        ax_o = signed_product[15:0];
        if (wide_i) dx_o = signed_product[31:16];
        carry_o = wide_i ?
            signed_product != $signed({{16{signed_product[15]}}, signed_product[15:0]}) :
            signed_product != $signed({{24{signed_product[7]}}, signed_product[7:0]});
      end
      2: begin
        divide_error_o = divisor == 0 || (div_wide ? quotient > 65535 : quotient > 255);
        if (!divide_error_o) begin
          ax_o = div_wide ? quotient[15:0] : {remainder[7:0], quotient[7:0]};
          if (div_wide) dx_o = remainder[15:0];
        end
      end
      3: begin
        divide_error_o = divisor == 0 || (div_wide ?
            (signed_quotient < -33'sd32767 || signed_quotient > 33'sd32767) :
            (signed_quotient < -33'sd127 || signed_quotient > 33'sd127));
        if (!divide_error_o) begin
          ax_o = div_wide ? signed_quotient[15:0] : {signed_remainder[7:0], signed_quotient[7:0]};
          if (div_wide) dx_o = signed_remainder[15:0];
        end
      end
    endcase
  end
  logic unused_divider;
  assign unused_divider = ^{div_signed, start_divisor[16], signed_remainder[16]};
endmodule
