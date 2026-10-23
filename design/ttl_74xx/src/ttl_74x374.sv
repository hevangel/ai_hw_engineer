// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x374.md.
// =============================================================================
// ttl_74x374 - Octal D-type flip-flop, posedge clk, 3-state outputs
//
// On posedge clk, q <- d. When oe_n=0, q drives; when oe_n=1, q is 0
// (project convention for FPGA-internal high-Z representation).
// =============================================================================

module ttl_74x374 (
    input  logic       clk,
    input  logic       oe_n,
    input  logic [7:0] d,
    output logic [7:0] q
);
    logic [7:0] q_reg;

    always_ff @(posedge clk) begin
        q_reg <= d;
    end

    assign q = oe_n ? 8'h00 : q_reg;
endmodule
