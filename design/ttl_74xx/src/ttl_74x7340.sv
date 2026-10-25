// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x7340.md.
// ttl_74x7340 - 8-bit bus driver with bidirectional registers.
// Each direction (A->B and B->A) has its own posedge-clocked register and
// active-low output enable.  Functionally similar to 74x646/652 minus the
// real-time-vs-stored mux: outputs are always the registered value.
module ttl_74x7340 (
    input  logic       cab, oeab_n,
    input  logic       cba, oeba_n,
    input  logic [7:0] a_in, b_in,
    output logic [7:0] a_out, b_out,
    output logic       a_hiz, b_hiz
);
    logic [7:0] ab_q, ba_q;
    always_ff @(posedge cab) ab_q <= a_in;
    always_ff @(posedge cba) ba_q <= b_in;
    assign b_out = oeab_n ? 8'b0 : ab_q;
    assign a_out = oeba_n ? 8'b0 : ba_q;
    assign b_hiz = oeab_n;
    assign a_hiz = oeba_n;
endmodule
