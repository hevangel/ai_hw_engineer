// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x376.md.
// ttl_74x376 - Quad J-/K FF, shared clock and clear.
module ttl_74x376 (
    input  logic       clk,
    input  logic       clr_n,
    input  logic [3:0] j,
    input  logic [3:0] k_n,
    output logic [3:0] q
);
    always_ff @(posedge clk or negedge clr_n) begin
        if (!clr_n) q <= 4'h0;
        else begin
            for (int i = 0; i < 4; i++) begin
                case ({j[i], ~k_n[i]})
                    2'b01: q[i] <= 1'b0;
                    2'b10: q[i] <= 1'b1;
                    2'b11: q[i] <= ~q[i];
                    default: ;
                endcase
            end
        end
    end
endmodule
