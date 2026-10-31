// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74ls450.md.
// ttl_74ls450 - 16-to-1 multiplexer, complementary outputs.
module ttl_74ls450 (
    input  logic [3:0]  s,
    input  logic [15:0] d,
    input  logic        g_n,
    output logic        y,
    output logic        y_n
);
    always_comb begin
        if (g_n) begin y = 0; y_n = 1; end
        else begin y = d[s]; y_n = ~d[s]; end
    end
endmodule
