// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x651.md.
// ttl_74x651 - octal bus transceiver / register, inverting (3-state).
//
// Like 74x648 (inverting registered transceiver) but uses the gab + gba_n
// dual-enable control style of 74x638/639 rather than a combined dir+/G.
// Each direction has an independent enable and an SAB/SBA select between
// real-time pass-through and the corresponding posedge-clocked storage register.
module ttl_74x651 (
    input  logic       gab, gba_n, sab, sba, cab, cba,
    input  logic [7:0] a_in, b_in,
    output logic [7:0] a_out, b_out
);
    logic [7:0] ab_q, ba_q;

    always_ff @(posedge cab) ab_q <= a_in;
    always_ff @(posedge cba) ba_q <= b_in;

    assign b_out =  gab   ? (sab ? ~ab_q : ~a_in) : 8'h00;
    assign a_out = !gba_n ? (sba ? ~ba_q : ~b_in) : 8'h00;
endmodule
