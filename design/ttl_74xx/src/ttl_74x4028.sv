// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x4028.md.
// ttl_74x4028 - BCD to decimal decoder (1-of-10).
// Asserts q[d] high when d in 0..9; all outputs low otherwise.
module ttl_74x4028 (
    input  logic [3:0] d,
    output logic [9:0] q
);
    always_comb begin
        q = 10'b0;
        if (d <= 4'd9) q[d] = 1'b1;
    end
endmodule
