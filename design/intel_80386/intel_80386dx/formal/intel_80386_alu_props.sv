// Formal check of intel_80386_pkg::alu flag generation against signed and
// unsigned integer definitions of carry/borrow and overflow (Intel
// 230985-001, appendix C flag definitions): CF is the carry out of (or
// borrow into) the operand's top bit, OF is set when the signed result is
// out of range, ZF/SF/PF describe the truncated result.
module intel_80386_alu_props (
    input logic [3:0] op,
    input logic [1:0] size,
    input logic [31:0] a,
    input logic [31:0] b,
    input logic cin
);
  logic [63:0] out;
  logic [31:0] r, f, mask;
  logic [33:0] ua, ub, usum;
  logic signed [33:0] sa, sb, ssum, smax, smin;

  always_comb begin
    out = intel_80386_pkg::alu(op, size, a, b, cin);
    r = out[31:0];
    f = out[63:32];
    mask = intel_80386_pkg::size_mask(size);
    ua = {2'b0, a & mask};
    ub = {2'b0, b & mask};
    sa = $signed({2'b0, intel_80386_pkg::sign_extend(a & mask, size)});
    sb = $signed({2'b0, intel_80386_pkg::sign_extend(b & mask, size)});
    if (intel_80386_pkg::sign_extend(a & mask, size) >> 31) sa = sa - 34'sh1_0000_0000;
    if (intel_80386_pkg::sign_extend(b & mask, size) >> 31) sb = sb - 34'sh1_0000_0000;
    case (size)
      2'd0: begin smax = 34'sd127; smin = -34'sd128; end
      2'd1: begin smax = 34'sd32767; smin = -34'sd32768; end
      default: begin smax = 34'sd2147483647; smin = -34'sd2147483648; end
    endcase
    usum = 34'b0;
    ssum = 34'sd0;
    assume (op <= 4'd10);
    assume (size != 2'd3);
    if (op == 4'd0 || op == 4'd2) begin
      usum = ua + ub + ((op == 4'd2) ? {33'b0, cin} : 34'b0);
      ssum = sa + sb + ((op == 4'd2) ? $signed({33'b0, cin}) : 34'sd0);
      assert (f[0] == (usum > {2'b0, mask}));
      assert (f[11] == (ssum > smax || ssum < smin));
      assert (r == (usum[31:0] & mask));
    end
    if (op == 4'd5 || op == 4'd7 || op == 4'd3) begin
      usum = ua - ub - ((op == 4'd3) ? {33'b0, cin} : 34'b0);
      ssum = sa - sb - ((op == 4'd3) ? $signed({33'b0, cin}) : 34'sd0);
      assert (f[0] == (ua < ub + ((op == 4'd3) ? {33'b0, cin} : 34'b0)));
      assert (f[11] == (ssum > smax || ssum < smin));
      assert (r == (usum[31:0] & mask));
    end
    if (op == 4'd1 || op == 4'd4 || op == 4'd6) assert (f[0] == 1'b0 && f[11] == 1'b0);
    if (op == 4'd8 || op == 4'd9) assert (f[0] == cin);
    if (op == 4'd10) assert (f[0] == ((a & mask) != 32'b0));
    assert (f[6] == (r == 32'b0));
    assert (f[7] == intel_80386_pkg::sign_bit(r, size));
    assert (f[2] == ~^r[7:0]);
    assert ((r & ~mask) == 32'b0);
    cover (op == 4'd0 && size == 2'd2 && f[0] && f[11]);
    cover (op == 4'd3 && size == 2'd0 && f[0] && !f[11]);
  end
endmodule
