// Formal harness for intel_80386_divider (reduced width W=4).
// Checks the division identity quotient*divisor + remainder == dividend and
// remainder < divisor at completion, for every start with a nonzero divisor.
module intel_80386_divider_props (
    input logic clk,
    input logic rst_n,
    input logic start_i,
    input logic [7:0] dividend_i,
    input logic [3:0] divisor_i
);
  logic busy, done;
  logic [7:0] quotient;
  logic [3:0] remainder;
  logic [7:0] dividend_q;
  logic [3:0] divisor_q;
  logic past_valid = 1'b0;

  intel_80386_divider #(.W(4)) dut (
      .clk(clk), .rst_n(rst_n), .start_i(start_i), .dividend_i(dividend_i),
      .divisor_i(divisor_i), .busy_o(busy), .done_o(done),
      .quotient_o(quotient), .remainder_o(remainder));

  always_ff @(posedge clk) begin
    past_valid <= 1'b1;
    if (start_i && !busy) begin
      dividend_q <= dividend_i;
      divisor_q <= divisor_i;
    end
  end

  always_comb begin
    if (!past_valid) assume (!rst_n);
    if (start_i) assume (divisor_i != 4'd0);
  end

  always_ff @(posedge clk) begin
    if (past_valid && rst_n && done) begin
      assert ({4'b0, quotient} * {8'b0, divisor_q} + {8'b0, remainder} == {4'b0, dividend_q});
      assert (remainder < divisor_q);
    end
    if (past_valid && rst_n && $past(rst_n) && !$past(busy) && !$past(start_i))
      assert (!busy);
    cover (past_valid && rst_n && done && quotient > 8'd15);
    cover (past_valid && rst_n && done && remainder == divisor_q - 4'd1);
  end
endmodule
