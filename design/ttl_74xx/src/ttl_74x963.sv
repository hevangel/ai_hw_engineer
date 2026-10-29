// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x963.md.
// ttl_74x963 - dual rank 8-bit shift register with synchronous clear.
// Same dual-rank structure as ttl_74x962 but the "exchange" mode is replaced
// with a synchronous clear that zeroes both ranks on the next clock edge.
//   00: hold
//   01: shift A
//   10: A -> B
//   11: synchronous clear (both ranks)
module ttl_74x963 (
    input  logic       clk,
    input  logic [1:0] mode,
    input  logic       serial_in,
    output logic [7:0] q_a,
    output logic [7:0] q_b,
    output logic       serial_out
);
    always_ff @(posedge clk) begin
        unique case (mode)
            2'b00: ;
            2'b01: q_a <= {q_a[6:0], serial_in};
            2'b10: q_b <= q_a;
            2'b11: begin
                q_a <= 8'b0;
                q_b <= 8'b0;
            end
        endcase
    end

    assign serial_out = q_a[7];
endmodule
