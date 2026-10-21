// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x380.md.
// ttl_74x380 - 8-bit multifunction register.
// Combines features of 74x374, 74x377, 74x273, 74x534. Operating modes:
//   s = 00: hold
//   s = 01: clear (q <= 0)
//   s = 10: load (q <= d)
//   s = 11: invert (q <= ~q)
module ttl_74x380 (
    input  logic       clk,
    input  logic [1:0] s,
    input  logic [7:0] d,
    output logic [7:0] q
);
    always_ff @(posedge clk) begin
        case (s)
            2'b00: ;
            2'b01: q <= 8'h00;
            2'b10: q <= d;
            2'b11: q <= ~q;
        endcase
    end
endmodule
