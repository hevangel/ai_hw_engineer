// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x8153.md.
// ttl_74x8153 - 8-bit serial-to-parallel interface.
// Shifts the serial input into an 8-bit register on each posedge clk; the
// register is presented on `q[7:0]`, with an async clear.
module ttl_74x8153 (
    input  logic       clk, clr_n, ser,
    output logic [7:0] q,
    output logic       ser_out
);
    always_ff @(posedge clk or negedge clr_n) begin
        if (!clr_n) q <= 8'b0;
        else        q <= {q[6:0], ser};
    end
    assign ser_out = q[7];
endmodule
