// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x654.md.
// ttl_74x654 - octal bus transceiver / register, non-inverting (3-state A / OC B).
module ttl_74x654 (
    input  logic       gab, gba_n, sab, sba, cab, cba,
    input  logic [7:0] a_in, b_in,
    output logic [7:0] a_out, b_out
);
    logic [7:0] ab_q, ba_q;

    always_ff @(posedge cab) ab_q <= a_in;
    always_ff @(posedge cba) ba_q <= b_in;

    assign b_out =  gab   ? (sab ? ab_q : a_in) : 8'h00;
    assign a_out = !gba_n ? (sba ? ba_q : b_in) : 8'h00;
endmodule
