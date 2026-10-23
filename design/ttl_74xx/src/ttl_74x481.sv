// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x481.md.
// ttl_74x481 - 4-bit slice cascadable processor element.
// Simplified ALU slice: 4-bit operands, function select.
module ttl_74x481 (
    input  logic [3:0] a, b,
    input  logic [2:0] f_sel,
    input  logic       cin,
    output logic [3:0] f,
    output logic       cout
);
    logic [4:0] sum;
    always_comb begin
        f    = 0;
        sum  = 0;
        cout = 0;
        case (f_sel)
            3'd0: begin sum = a + b + cin; f = sum[3:0]; cout = sum[4]; end
            3'd1: begin sum = a - b - !cin; f = sum[3:0]; cout = sum[4]; end
            3'd2: f = a & b;
            3'd3: f = a | b;
            3'd4: f = a ^ b;
            3'd5: f = ~a;
            3'd6: f = a;
            3'd7: f = b;
        endcase
    end
endmodule
