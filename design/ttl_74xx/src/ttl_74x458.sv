// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x458.md.
// ttl_74x458 - Nine's complement / zero element.
// For BCD input a: output is 9-a; if zero_force=1, output is 0.
module ttl_74x458 (
    input  logic [3:0] a,
    input  logic       zero_force,
    output logic [3:0] y
);
    always_comb begin
        if (zero_force) y = 4'd0;
        else            y = (a < 4'd10) ? (4'd9 - a) : 4'd0;
    end
endmodule
