// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x4560.md.
// ttl_74x4560 - 4-bit BCD adder (NBCD addition).
// Produces the BCD sum of a + b + cin (each in 0..9) along with a carry-out
// (asserted when the sum >= 10).  Inputs outside the BCD range are not
// guaranteed by the original chip.
module ttl_74x4560 (
    input  logic [3:0] a, b,
    input  logic       cin,
    output logic [3:0] s,
    output logic       cout
);
    logic [4:0] raw;
    always_comb begin
        raw  = {1'b0, a} + {1'b0, b} + 5'(cin);
        if (raw >= 5'd10) begin
            s    = raw[3:0] + 4'd6;
            cout = 1'b1;
        end else begin
            s    = raw[3:0];
            cout = 1'b0;
        end
    end
endmodule
