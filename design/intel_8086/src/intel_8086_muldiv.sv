`timescale 1ns / 1ps
// Documented MUL/IMUL/DIV/IDIV results; undefined flags handled by the caller.
module intel_8086_muldiv (
    input logic wide_i,
    input logic [1:0] kind_i,
    input logic [15:0] operand_i,
    ax_i,
    dx_i,
    output logic [15:0] ax_o,
    dx_o,
    output logic carry_o,
    divide_error_o
);
  logic [31:0] product, dividend, divisor, quotient;
  logic [15:0] remainder_value;
  logic signed [32:0] signed_dividend, signed_divisor, signed_quotient;
  logic signed [15:0] signed_remainder;
  logic signed [31:0] signed_product;
  always_comb begin
    product = wide_i ? (32'(ax_i) * 32'(operand_i)) : (32'(ax_i[7:0]) * 32'(operand_i[7:0]));
    signed_product = wide_i ?
        ($signed(ax_i) * $signed(operand_i)) : ($signed(ax_i[7:0]) * $signed(operand_i[7:0]));
    dividend = wide_i ? {dx_i, ax_i} : {16'b0, ax_i};
    divisor = wide_i ? {16'b0, operand_i} : {24'b0, operand_i[7:0]};
    signed_dividend = wide_i ? $signed({dx_i[15], dx_i, ax_i}) : $signed({{17{ax_i[15]}}, ax_i});
    signed_divisor = wide_i ? $signed({{17{operand_i[15]}}, operand_i}) :
        $signed({{25{operand_i[7]}}, operand_i[7:0]});
    quotient = 0;
    remainder_value = 0;
    signed_quotient = 0;
    signed_remainder = 0;
    if (divisor != 0) begin
      quotient = dividend / divisor;
      remainder_value = 16'(dividend % divisor);
    end
    if (signed_divisor != 0) begin
      signed_quotient  = signed_dividend / signed_divisor;
      signed_remainder = 16'(signed_dividend % signed_divisor);
    end
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
        divide_error_o = divisor == 0 || (wide_i ? quotient > 65535 : quotient > 255);
        if (!divide_error_o) begin
          ax_o = wide_i ? quotient[15:0] : {remainder_value[7:0], quotient[7:0]};
          if (wide_i) dx_o = remainder_value[15:0];
        end
      end
      3: begin
        divide_error_o=signed_divisor==0 || (wide_i ?
            (signed_quotient < -33'sd32767 || signed_quotient > 33'sd32767) :
            (signed_quotient < -33'sd127 || signed_quotient > 33'sd127));
        if (!divide_error_o) begin
          ax_o = wide_i ? signed_quotient[15:0] : {signed_remainder[7:0], signed_quotient[7:0]};
          if (wide_i) dx_o = signed_remainder[15:0];
        end
      end
    endcase
  end
endmodule
