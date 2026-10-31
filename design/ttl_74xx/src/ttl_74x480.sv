// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x480.md.
// ttl_74x480 - Single burst error recovery circuit.
// Simplified: detects burst errors using a CRC-like polynomial.
module ttl_74x480 (
    input  logic        clk,
    input  logic        clr_n,
    input  logic        din,
    output logic [15:0] reg_state,
    output logic        err
);
    logic feedback;
    assign feedback = reg_state[15] ^ din;
    always_ff @(posedge clk or negedge clr_n) begin
        if (!clr_n) reg_state <= 0;
        else begin
            reg_state <= {reg_state[14:0], 1'b0};
            if (feedback) reg_state <= ({reg_state[14:0], 1'b0}) ^ 16'h8005;
        end
    end
    assign err = (reg_state != 0);
endmodule
