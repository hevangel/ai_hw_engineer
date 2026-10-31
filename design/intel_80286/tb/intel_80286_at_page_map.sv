// IBM 5170 type 1 sheets 13 and 15: U110/U120 address selection, U81
// map enable, and U79's separate XA16 buffer. map_data_i is the existing
// fixture's CPU-visible low eight mapper bits; it is not a complete LS612.
module intel_80286_at_page_map (
    input logic refresh_n_i, dack0_n_i, dack2_n_i, dack3_n_i,
    input logic dack4_n_i, dack6_n_i, dack7_n_i,
    input logic hlda_i, master_n_i, aen1_n_i,
    input logic [7:0] map_data_i,
    output logic [3:0] map_index_o,
    output logic [6:0] a23_a17_o,
    output logic a23_a17_oe_o, xa16_o, xa16_valid_o
);
    assign map_index_o = {dack4_n_i, !(refresh_n_i && dack0_n_i),
                          dack2_n_i && dack6_n_i, dack3_n_i && dack7_n_i};
    // Sheet 13: -ACK is the inversion of HLDA AND -MASTER. Sheet 15
    // connects -ACK to LS612 ME#, with its MM input grounded.
    assign a23_a17_oe_o = hlda_i && master_n_i;
    assign a23_a17_o = map_data_i[7:1];
    assign xa16_o = map_data_i[0];
    // U79 G# is -AEN1. Valid requires both an enabled mapper and buffer.
    assign xa16_valid_o = a23_a17_oe_o && !aen1_n_i;
endmodule
