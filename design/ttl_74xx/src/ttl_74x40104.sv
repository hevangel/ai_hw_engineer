// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x40104.md.
// ttl_74x40104 - 4-bit bidirectional universal shift register.
// Same mode encoding as ttl_74x9164 but 4-bit wide.
module ttl_74x40104 (
    input  logic       clk, clr_n,
    input  logic [1:0] mode,
    input  logic       sin,
    input  logic [3:0] d,
    output logic [3:0] q
);
    always_ff @(posedge clk or negedge clr_n) begin
        if (!clr_n) q <= 4'b0;
        else unique case (mode)
            2'b00: ;
            2'b01: q <= {sin, q[3:1]};
            2'b10: q <= {q[2:0], sin};
            2'b11: q <= d;
        endcase
    end
endmodule
