// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x2648.md.
// ttl_74x2648 - octal registered transceiver, inverting (= 74x648).
module ttl_74x2648 (
    input  logic       g_n,
    input  logic       dir,
    input  logic       sab,
    input  logic       sba,
    input  logic       cab,
    input  logic       cba,
    input  logic [7:0] a_in,
    input  logic [7:0] b_in,
    output logic [7:0] a_out,
    output logic [7:0] b_out,
    output logic       a_oe_n,
    output logic       b_oe_n
);
    logic [7:0] ab_q, ba_q;

    always_ff @(posedge cab) ab_q <= a_in;
    always_ff @(posedge cba) ba_q <= b_in;

    always_comb begin
        if (g_n) begin
            a_out  = 8'h00; b_out  = 8'h00;
            a_oe_n = 1'b1;  b_oe_n = 1'b1;
        end else if (dir) begin
            a_out  = 8'h00;
            b_out  = sab ? ~ab_q : ~a_in;
            a_oe_n = 1'b1;  b_oe_n = 1'b0;
        end else begin
            a_out  = sba ? ~ba_q : ~b_in;
            b_out  = 8'h00;
            a_oe_n = 1'b0;  b_oe_n = 1'b1;
        end
    end
endmodule
