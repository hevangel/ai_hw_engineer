// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x396.md.
// ttl_74x396 - Octal storage registers, parallel access.
module ttl_74x396 (
    input  logic       clk,
    input  logic       ce_n,
    input  logic [7:0] d,
    output logic [7:0] q
);
    always_ff @(posedge clk) if (!ce_n) q <= d;
endmodule
