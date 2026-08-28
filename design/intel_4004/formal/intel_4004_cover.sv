// Reachability (non-vacuity) covers for the Intel 4004 reconstruction.
//
// All bus inputs are left free in this build, so the solver may deliver any
// instruction stream; each cover then demonstrates that the corresponding
// instruction class, sequencer state, or bus condition is reachable within a
// short horizon. This checks the safety properties (including the inline
// structural assertions) against vacuity. Broad equivalence to the spec is
// covered by the props task and the simulation regression.
module intel_4004_cover (
    input logic       clk,
    input logic       rst_n,
    input logic       test_i,
    input logic [3:0] data_i,
    input logic [3:0] data_o,
    input logic       data_oe,
    input logic       sync,
    input logic       cm_rom,
    input logic [3:0] cm_ram,

    // DUT internals
    input logic [2:0] phase,
    input logic       cycle2,
    input logic [3:0] opr,
    input logic [3:0] opa,
    input logic [1:0] sp,
    input logic [3:0] acc,
    input logic       cy,
    input logic [7:0] src_ptr,
    input logic [2:0] cmd,
    input logic [11:0] pc,
    input logic        two_cycle,
    input logic        jcn_taken,
    input logic        isz_taken
);

  localparam logic [2:0] PhX2 = 3'd6;
  localparam logic [2:0] PhX3 = 3'd7;

  logic commit;
  assign commit = (phase == PhX3) && rst_n;

  always @(posedge clk) begin
    if (!$initstate && rst_n) begin
      // One per OPR group (committed instruction of that group)
      c_opr_0_nop:  cover (commit && opr == 4'h0);
      c_opr_1_jcn:  cover (commit && opr == 4'h1);
      c_opr_2_fimsrc: cover (commit && opr == 4'h2);
      c_opr_3_finjin: cover (commit && opr == 4'h3);
      c_opr_4_jun:  cover (commit && opr == 4'h4);
      c_opr_5_jms:  cover (commit && opr == 4'h5);
      c_opr_6_inc:  cover (commit && opr == 4'h6);
      c_opr_7_isz:  cover (commit && opr == 4'h7);
      c_opr_8_add:  cover (commit && opr == 4'h8);
      c_opr_9_sub:  cover (commit && opr == 4'h9);
      c_opr_a_ld:   cover (commit && opr == 4'ha);
      c_opr_b_xch:  cover (commit && opr == 4'hb);
      c_opr_c_bbl:  cover (commit && opr == 4'hc);
      c_opr_d_ldm:  cover (commit && opr == 4'hd);
      c_opr_e_io:   cover (commit && opr == 4'he);
      c_opr_f_acc:  cover (commit && opr == 4'hf);

      // Word-level variants: FIM/SRC, FIN/JIN
      c_fim: cover (commit && opr == 4'h2 && !opa[0]);
      c_src: cover (commit && opr == 4'h2 && opa[0]);
      c_fin: cover (commit && opr == 4'h3 && !opa[0]);
      c_jin: cover (commit && opr == 4'h3 && opa[0]);

      // RAM/ROM port representatives
      c_wrm: cover (commit && opr == 4'he && opa == 4'h0);
      c_wmp: cover (commit && opr == 4'he && opa == 4'h1);
      c_wrr: cover (commit && opr == 4'he && opa == 4'h2);
      c_wpm: cover (commit && opr == 4'he && opa == 4'h3);
      c_wr0: cover (commit && opr == 4'he && opa == 4'h4);
      c_sbm: cover (commit && opr == 4'he && opa == 4'h8);
      c_rdm: cover (commit && opr == 4'he && opa == 4'h9);
      c_rdr: cover (commit && opr == 4'he && opa == 4'ha);
      c_adm: cover (commit && opr == 4'he && opa == 4'hb);
      c_rd0: cover (commit && opr == 4'he && opa == 4'hc);

      // Accumulator group, all defined encodings
      c_clb: cover (commit && opr == 4'hf && opa == 4'h0);
      c_clc: cover (commit && opr == 4'hf && opa == 4'h1);
      c_iac: cover (commit && opr == 4'hf && opa == 4'h2);
      c_cmc: cover (commit && opr == 4'hf && opa == 4'h3);
      c_cma: cover (commit && opr == 4'hf && opa == 4'h4);
      c_ral: cover (commit && opr == 4'hf && opa == 4'h5);
      c_rar: cover (commit && opr == 4'hf && opa == 4'h6);
      c_tcc: cover (commit && opr == 4'hf && opa == 4'h7);
      c_dac: cover (commit && opr == 4'hf && opa == 4'h8);
      c_tcs: cover (commit && opr == 4'hf && opa == 4'h9);
      c_stc: cover (commit && opr == 4'hf && opa == 4'ha);
      c_daa: cover (commit && opr == 4'hf && opa == 4'hb);
      c_kbp: cover (commit && opr == 4'hf && opa == 4'hc);
      c_dcl: cover (commit && opr == 4'hf && opa == 4'hd);
      c_acc_undefined_nop: cover (commit && opr == 4'hf && opa == 4'he);

      // Branch outcomes
      c_jcn_taken:   cover (commit && opr == 4'h1 && jcn_taken);
      c_jcn_not:     cover (commit && opr == 4'h1 && !jcn_taken);
      c_isz_taken:   cover (commit && opr == 4'h7 && isz_taken);
      c_isz_skip:    cover (commit && opr == 4'h7 && !isz_taken);
      c_two_cycle:   cover (cycle2 && two_cycle);

      // Stack and state conditions
      c_sp_full:     cover (sp == 2'd3);
      c_src_set:     cover (src_ptr == 8'ha5);
      c_cmd_bank7:   cover (cmd == 3'b111);
      c_cmd_bank5:   cover (cmd == 3'b101);
      c_acc_zero_cy: cover (acc == 4'h0 && cy);

      // Bus conditions
      c_src_drive_x3: cover ((phase == PhX3) && data_oe && cm_ram != 4'b0000);
      c_romport_drive: cover ((phase == PhX2) && data_oe && cm_rom);
      c_page_edge_fetch: cover (cycle2 && two_cycle && pc[7:0] == 8'hff);
      c_test_cond: cover (commit && opr == 4'h1 && opa[0] && !test_i);
    end
  end

  logic _unused_cover;
  assign _unused_cover = &{1'b0, data_i, data_o, sync, PhX2, PhX3};

endmodule
