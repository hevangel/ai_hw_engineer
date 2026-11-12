// Transport-only abstraction of the Am9512 FPU used by the formal proof.
// The numerical result and status are unconstrained; the model only supplies
// the start/done handshake so the stack, status and bus transport can be
// proved independently of the arithmetic datapath.
module amd_am9512_fpu #(
    parameter int MANT_W = 24,
    parameter int EXP_W = 8,
    parameter int BIAS = 127
) (
    input  logic clk_i,
    input  logic reset_i,
    input  logic start_i,
    input  logic [1:0] op_i,
    input  logic [MANT_W+EXP_W-1:0] a_i,
    input  logic [MANT_W+EXP_W-1:0] b_i,
    output logic done_o,
    output logic busy_o,
    output logic [MANT_W+EXP_W-1:0] result_o,
    output logic [4:0] status_o
);
    localparam int WORD_W = MANT_W + EXP_W;
    (* anyseq *) logic [WORD_W-1:0] value;
    (* anyseq *) logic [4:0] flags;
    logic [1:0] phase;

    assign result_o = value;
    assign status_o = flags;
    assign busy_o = (phase != 2'd0);
    assign done_o = (phase == 2'd2);

    always_ff @(posedge clk_i) begin
        if (reset_i)
            phase <= 2'd0;
        else if (phase == 2'd0) begin
            if (start_i)
                phase <= 2'd1;
        end else if (phase == 2'd1)
            phase <= 2'd2;
        else
            phase <= 2'd0;
    end
endmodule