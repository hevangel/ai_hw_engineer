// Iterative unsigned restoring divider for DIV/IDIV/AAM.
//
// One quotient bit per clock: a 2*W-bit dividend by a W-bit divisor takes
// 2*W cycles after start_i. The full 2*W-bit quotient is produced so the
// core can apply the size-specific overflow rule. divisor_i must be
// nonzero; the core raises #DE for a zero divisor before starting.
module intel_80386_divider #(
    parameter int W = 32
) (
    input  logic           clk,
    input  logic           rst_n,
    input  logic           start_i,
    input  logic [2*W-1:0] dividend_i,
    input  logic [W-1:0]   divisor_i,
    output logic           busy_o,
    output logic           done_o,
    output logic [2*W-1:0] quotient_o,
    output logic [W-1:0]   remainder_o
);
  localparam int CW = $clog2(2 * W + 1);
  logic [CW-1:0] count;
  logic [W-1:0] partial;
  logic [W-1:0] divisor;
  logic [W:0] trial;

  // Shift the next dividend bit into the partial remainder and try the
  // subtraction. On a borrow the shifted value is below the divisor, so its
  // top bit (partial[W-1]) is zero and may be dropped.
  always_comb trial = {partial, quotient_o[2*W-1]} - {1'b0, divisor};

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      busy_o <= 1'b0;
      done_o <= 1'b0;
      count <= '0;
      partial <= '0;
      divisor <= '0;
      quotient_o <= '0;
    end else begin
      done_o <= 1'b0;
      if (start_i && !busy_o) begin
        busy_o <= 1'b1;
        count <= CW'(2 * W);
        partial <= '0;
        divisor <= divisor_i;
        quotient_o <= dividend_i;
      end else if (busy_o) begin
        if (!trial[W]) begin
          partial <= trial[W-1:0];
          quotient_o <= {quotient_o[2*W-2:0], 1'b1};
        end else begin
          partial <= {partial[W-2:0], quotient_o[2*W-1]};
          quotient_o <= {quotient_o[2*W-2:0], 1'b0};
        end
        count <= count - CW'(1);
        if (count == CW'(1)) begin
          busy_o <= 1'b0;
          done_o <= 1'b1;
        end
      end
    end
  end

  assign remainder_o = partial;

`ifdef FORMAL
  // The remainder register never reaches the divisor once loaded.
  always_ff @(posedge clk)
    if (rst_n && busy_o && $past(rst_n) && !$past(start_i && !busy_o))
      assert (partial < divisor);
`endif
endmodule
