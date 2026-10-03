module amd_am2903 (
  input logic cp_i,
  input logic [8:0] instruction_i,
  input logic [3:0] a_i, b_i, da_i, db_i, y_i,
  input logic ea_i, oe_b_n_i, oe_y_n_i, we_n_i, ien_n_i, cn_i,
  input logic lss_n_i, mss_n_i, z_i,
  input logic sio0_i, sio3_i, qio0_i, qio3_i,
  // These pins cross phase-separated latch and bidirectional cascade paths.
  /* verilator lint_off UNOPTFLAT */
  output logic [3:0] y_o,
  output logic [3:0] shift_o,
  /* verilator lint_on UNOPTFLAT */
  output logic [3:0] db_o,
  output logic y_oe_o, db_oe_o, write_n_o, write_oe_o,
  output logic cn4_o, gn_o, povr_o, z_pull_low_o,
  output logic [3:0] shift_oe_o
);
  logic [3:0] memory [0:15];
  logic [3:0] a_latch,b_latch,q,r,s,q_next;
  logic sc,q_enable,sc_enable,sc_next;
  logic [3:0] q_edge_data;
  logic sc_edge_data;
  // Native complementary read/write latches form a phase-separated path.
  /* verilator lint_off UNOPTFLAT */
  logic [3:0] ram_input;
  /* verilator lint_on UNOPTFLAT */
`ifdef FORMAL
  (* anyseq *) logic [3:0] storage_write_data;
`else
  logic [3:0] storage_write_data;
  assign storage_write_data=ram_input;
`endif
  assign ram_input=oe_y_n_i ? y_i:y_o;
  assign r=ea_i ? da_i:a_latch;
  assign s=instruction_i[0] ? q:(oe_b_n_i ? db_i:b_latch);
  assign db_o=b_latch;
  assign db_oe_o=!oe_b_n_i;
  assign y_oe_o=!oe_y_n_i;
  assign write_oe_o=!lss_n_i;
  // ASSUMPTION: setup/hold honored by callers; no power-up values specified.
  always_latch begin
    if(cp_i) begin a_latch=memory[a_i];b_latch=memory[b_i];end
  end
  for(genvar word_index=0;word_index<16;word_index++) begin: ram_words
    always_latch begin
      if(!cp_i && !we_n_i && b_i==4'(word_index)) memory[word_index]=storage_write_data;
    end
  end
  // Preserve pre-edge data when HIGH-transparent read latches reopen.
  // A real edge-triggered FF samples before read-latch propagation. The
  // explicit LOW input capture makes that timing order synthesizable and
  // deterministic in zero-delay tools; it adds five model capture bits.
  always_latch begin
    if(!cp_i) begin q_edge_data=q_next;sc_edge_data=sc_next;end
  end
  always_ff @(posedge cp_i) begin
    if(q_enable) q<=q_edge_data;
    if(sc_enable) sc<=sc_edge_data;
  end
  amd_am2903_datapath datapath (
    .instruction_i(instruction_i),.r_i(r),.s_i(s),.q_i(q),.y_i(y_i),
    .sc_i(sc),.cn_i(cn_i),.z_i(z_i),.ien_n_i(ien_n_i),.oe_y_n_i(oe_y_n_i),
    .lss_n_i(lss_n_i),.mss_n_i(mss_n_i),
    .sio0_i(sio0_i),.sio3_i(sio3_i),.qio0_i(qio0_i),.qio3_i(qio3_i),
    .y_o(y_o),.q_next_o(q_next),.q_enable_o(q_enable),.sc_enable_o(sc_enable),.sc_next_o(sc_next),
    .cn4_o(cn4_o),.gn_o(gn_o),.povr_o(povr_o),.z_pull_low_o(z_pull_low_o),
    .write_n_o(write_n_o),.shift_o(shift_o),.shift_oe_o(shift_oe_o)
  );
`ifdef FORMAL
  `include "amd_am2903_props.sv"
`endif
endmodule
