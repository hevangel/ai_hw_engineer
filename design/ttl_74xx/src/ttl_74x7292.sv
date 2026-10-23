// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x7292.md.
// ttl_74x7292 - Programmable divider / timer.
// Behavioral model: a 32-bit down-counter preloaded from `n` each time it
// reaches zero; `out` pulses high for one clock cycle on every wrap.
// The 7292's actual programming format (binary divisor select via mode pins)
// is not preserved -- this exposes a single flat binary divisor.
module ttl_74x7292 (
    input  logic        clk,
    input  logic        rst,
    input  logic [31:0] n,
    output logic        out
);
    logic [31:0] cnt;
    always_ff @(posedge clk or posedge rst) begin
        if (rst)               cnt <= 32'd0;
        else if (cnt == 32'd0) cnt <= (n == 32'd0) ? 32'd0 : (n - 32'd1);
        else                   cnt <= cnt - 32'd1;
    end
    assign out = (cnt == 32'd0);
endmodule
