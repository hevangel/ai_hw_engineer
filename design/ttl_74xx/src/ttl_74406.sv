// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74406.md.
// ttl_74406 - 3-to-8 decoder.
module ttl_74406 (
    input  logic [2:0] a,
    input  logic       en_n,
    output logic [7:0] y_n
);
    always_comb begin
        y_n = 8'hFF;
        if (!en_n) y_n[a] = 1'b0;
    end
endmodule
