// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x445.md.
// ttl_74x445 - BCD to decimal decoder/driver (same as 74x45).
module ttl_74x445 (
    input  logic [3:0] bcd,
    output logic [9:0] y_n
);
    always_comb begin
        y_n = 10'b1111111111;
        if (bcd < 4'd10) y_n[bcd] = 1'b0;
    end
endmodule
