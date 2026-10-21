// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74456.md.
// ttl_74456 - 4-bit BCD full adder. {cout, sum} = a + b + cin, valid for BCD operands.
// For valid BCD a,b in 0..9 plus cin, output is BCD with carry to next decade.
module ttl_74456 (
    input  logic [3:0] a, b,
    input  logic       cin,
    output logic [3:0] sum,
    output logic       cout
);
    logic [4:0] r;
    assign r = {1'b0, a} + {1'b0, b} + {4'b0, cin};
    always_comb begin
        if (r > 9) begin
            sum  = r[3:0] + 4'd6;
            cout = 1'b1;
        end else begin
            sum  = r[3:0];
            cout = 1'b0;
        end
    end
endmodule
