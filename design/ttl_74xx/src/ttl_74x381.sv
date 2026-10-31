// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x381.md.
// ttl_74x381 - 4-bit ALU with generate/propagate outputs.
module ttl_74x381 (
    input  logic [3:0] a, b,
    input  logic [2:0] s,
    input  logic       cn,
    output logic [3:0] f,
    output logic       p,
    output logic       g
);
    logic [4:0] arith;
    always_comb begin
        f     = 4'h0;
        p     = 1'b0;
        g     = 1'b0;
        arith = 5'h0;
        case (s)
            3'b000: ;
            3'b001: begin arith = {1'b0, b} - {1'b0, a} - {4'h0, ~cn}; f = arith[3:0]; g = arith[4]; end
            3'b010: begin arith = {1'b0, a} - {1'b0, b} - {4'h0, ~cn}; f = arith[3:0]; g = arith[4]; end
            3'b011: begin arith = {1'b0, a} + {1'b0, b} + {4'h0, cn}; f = arith[3:0]; p = &(a|b); g = arith[4]; end
            3'b100: f = a ^ b;
            3'b101: f = a | b;
            3'b110: f = a & b;
            3'b111: f = 4'hF;
        endcase
    end
endmodule
