// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x646.md.
// ttl_74x646 - octal bus transceiver / register / multiplexer, non-inverting (3-state).
//
// Each direction has a posedge-clocked storage register and a 2:1 mux selecting
// between real-time pass-through and the stored value:
//
//   B-side output = sab ? ab_q : a_in     (when enabled in A->B direction)
//   A-side output = sba ? ba_q : b_in     (when enabled in B->A direction)
//
// Storage registers capture on the rising edge of cab/cba regardless of g_n/dir.
module ttl_74x646 (
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
            b_out  = sab ? ab_q : a_in;
            a_oe_n = 1'b1;  b_oe_n = 1'b0;
        end else begin
            a_out  = sba ? ba_q : b_in;
            b_out  = 8'h00;
            a_oe_n = 1'b0;  b_oe_n = 1'b1;
        end
    end
endmodule
