// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x579.md.
// ttl_74x579 - 8-bit bidirectional binary counter with 3-state outputs.
module ttl_74x579 (
    input  logic       clk, ce_n, u_d_n, oe_n,
    input  logic       load_n,
    input  logic [7:0] d_in,
    output logic [7:0] q,
    output logic       hiz
);
    logic [7:0] r;
    always_ff @(posedge clk) begin
        if (!load_n)    r <= d_in;
        else if (!ce_n) r <= u_d_n ? r - 1 : r + 1;
    end
    assign q   = oe_n ? 8'b0 : r;
    assign hiz = oe_n;
endmodule
