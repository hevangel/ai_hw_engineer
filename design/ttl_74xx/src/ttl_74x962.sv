// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x962.md.
// ttl_74x962 - dual rank 8-bit shift register with register exchange mode.
// Two 8-bit ranks (A = shift, B = hold). The mode field selects the operation
// performed on each posedge clk:
//   00: hold       (both ranks unchanged)
//   01: shift A    (serial_in -> A[0]; A shifts toward A[7]; B unchanged)
//   10: A -> B     (rank A copied into rank B)
//   11: exchange   (A <-> B swap)
module ttl_74x962 (
    input  logic       clk,
    input  logic [1:0] mode,
    input  logic       serial_in,
    output logic [7:0] q_a,
    output logic [7:0] q_b,
    output logic       serial_out
);
    always_ff @(posedge clk) begin
        unique case (mode)
            2'b00: ;                              // hold
            2'b01: q_a <= {q_a[6:0], serial_in};  // shift A
            2'b10: q_b <= q_a;                    // A -> B
            2'b11: begin                          // exchange
                q_a <= q_b;
                q_b <= q_a;
            end
        endcase
    end

    assign serial_out = q_a[7];
endmodule
