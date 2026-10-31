// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x964.md.
// ttl_74x964 - dual rank 8-bit shift register with sync + async clear.
// Like ttl_74x963 plus an active-low asynchronous clear (clr_n).
module ttl_74x964 (
    input  logic       clk,
    input  logic       clr_n,        // async clear, active low
    input  logic [1:0] mode,
    input  logic       serial_in,
    output logic [7:0] q_a,
    output logic [7:0] q_b,
    output logic       serial_out
);
    always_ff @(posedge clk or negedge clr_n) begin
        if (!clr_n) begin
            q_a <= 8'b0;
            q_b <= 8'b0;
        end else begin
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
    end

    assign serial_out = q_a[7];
endmodule
