// Reachability (non-vacuity) covers for the Intel 4001 reconstruction.
//
// Each labeled cover demonstrates that a distinct behavior of the chip is
// reachable within the cover depth: every instruction-cycle period, ROM
// fetch across corner addresses and both nibbles, selected and unselected
// chip behavior for fetch and port operations, SRC select switching and
// its X3-ignored rule, WRR latch/overwrite/clear, RDR read of both data
// sources and both drive periods, WPM non-participation, reset mid-cycle,
// sync re-lock, and CM-ROM/absent qualification. Goals are sticky: once
// an event has been seen the corresponding goal stays set, so each cover
// assertion is discharged by any trace that exhibits the event. Only the
// initial-reset assumption is imposed; all bus inputs stay free, which
// also exercises the chip against arbitrary (not just well-formed) buses
// for the events covered here.
module intel_4001_cover (
    input logic        clk,
    input logic        rst_n,
    input logic        clr_n,
    input logic [3:0]  data_i,
    input logic [3:0]  data_o,
    input logic        data_oe,
    input logic        sync,
    input logic        cm_rom,
    input logic [3:0]  port_i,
    input logic [2:0]  phase,
    input logic [7:0]  addr_q,
    input logic        cm_rom_seen,
    input logic        fetch_sel_q,
    input logic [3:0]  opr_q,
    input logic [3:0]  opa_q,
    input logic [3:0]  io_sel_q,
    input logic [3:0]  port_q,
    input logic [7:0]  rom_word,
    input logic        fetch_selected,
    input logic        io_selected,
    input logic        s_src,
    input logic        s_wrr,
    input logic        s_rdr,
    input logic        s_wpm,
    input logic [3:0]  CHIP_NO,
    input logic [3:0]  IO_DIR
  );

  localparam logic [2:0] PhA1 = 3'd0;
  localparam logic [2:0] PhA2 = 3'd1;
  localparam logic [2:0] PhA3 = 3'd2;
  localparam logic [2:0] PhM1 = 3'd3;
  localparam logic [2:0] PhM2 = 3'd4;
  localparam logic [2:0] PhX1 = 3'd5;
  localparam logic [2:0] PhX2 = 3'd6;
  localparam logic [2:0] PhX3 = 3'd7;

  localparam integer NG = 38;
  logic [NG-1:0] goal;

  logic        m1_drive;
  logic        rdr_drive;
  logic        rdr_drive_x2;
  logic        rdr_drive_x3;
  logic [3:0]  rdr_val;
  logic        seen_src;
  logic        seen_wrr;
  logic [3:0]  wrr_val;
  logic        saw_sel_other;
  logic        saw_sel_match;
  logic        seen_m1;
  logic [7:0]  last_addr;
  logic        seen_m1_cycle;

  assign m1_drive    = data_oe && (phase == PhM1) && fetch_selected;
  assign rdr_val     = (IO_DIR & port_q) | (~IO_DIR & port_i);
  assign rdr_drive   = data_oe && s_rdr && io_selected &&
                       ((phase == PhX2) || (phase == PhX3));
  assign rdr_drive_x2 = rdr_drive && (phase == PhX2);
  assign rdr_drive_x3 = rdr_drive && (phase == PhX3);

  always_ff @(posedge clk) begin
    if ($initstate) begin
      a_reset0: assume (!rst_n);
    end
    if (!rst_n) begin
      goal          <= {NG{1'b0}};
      seen_src      <= 1'b0;
      seen_wrr      <= 1'b0;
      wrr_val       <= 4'h0;
      saw_sel_other <= 1'b0;
      saw_sel_match <= 1'b0;
      seen_m1       <= 1'b0;
      last_addr     <= 8'h0;
      seen_m1_cycle <= 1'b0;
    end else begin
      // Goal updates (sticky OR of each event)
      goal[0]  <= goal[0]  || (phase == PhA1);
      goal[1]  <= goal[1]  || (phase == PhA2);
      goal[2]  <= goal[2]  || (phase == PhA3);
      goal[3]  <= goal[3]  || (phase == PhM1);
      goal[4]  <= goal[4]  || (phase == PhM2);
      goal[5]  <= goal[5]  || (phase == PhX1);
      goal[6]  <= goal[6]  || (phase == PhX2);
      goal[7]  <= goal[7]  || (phase == PhX3);
      goal[8]  <= goal[8]  || (m1_drive && (addr_q == 8'h00));
      goal[9]  <= goal[9]  || (m1_drive && (addr_q == 8'hff));
      goal[10] <= goal[10] || (m1_drive && (addr_q == 8'h01));
      goal[11] <= goal[11] || (m1_drive && (addr_q == 8'hfe));
      goal[12] <= goal[12] || (m1_drive && (addr_q == 8'h80));
      goal[13] <= goal[13] || (m1_drive && (rom_word[7:4] == 4'hf));
      goal[14] <= goal[14] || ((phase == PhM2) && data_oe &&
                               fetch_selected && (rom_word[3:0] == 4'h0));
      goal[15] <= goal[15] || ($past((phase == PhA3) && !fetch_sel_q) &&
                               (phase == PhM1) && !data_oe);
      goal[16] <= goal[16] || (saw_sel_other &&
                               (io_sel_q == CHIP_NO) &&
                               $past(io_sel_q != CHIP_NO));
      goal[17] <= goal[17] || (saw_sel_match &&
                               (io_sel_q != CHIP_NO) &&
                               $past(io_sel_q == CHIP_NO));
      goal[18] <= goal[18] || ($past((phase == PhX3) && s_wrr &&
                                     io_selected) && (port_q == 4'h0));
      goal[19] <= goal[19] || ($past((phase == PhX3) && s_wrr &&
                                     io_selected) && (port_q != 4'h0));
      goal[20] <= goal[20] || ($past((phase == PhX3) && s_wrr &&
                                     io_selected) &&
                               (port_q != $past(port_q)));
      goal[21] <= goal[21] || (rdr_drive && (rdr_val == 4'h0));
      goal[22] <= goal[22] || (rdr_drive && (rdr_val != 4'h0));
      goal[23] <= goal[23] || (rdr_drive && !seen_src);
      goal[24] <= goal[24] || (rdr_drive && seen_wrr &&
                               (data_o == wrr_val));
      goal[25] <= goal[25] || (saw_sel_match &&
                               $past((phase == PhX3) && s_wrr &&
                                     !io_selected) &&
                               (port_q == $past(port_q)) &&
                               (port_q != 4'h0));
      goal[26] <= goal[26] || ((phase == PhX3) && s_rdr && !io_selected &&
                               !data_oe);
      goal[27] <= goal[27] || ($past((phase == PhX3) && s_wpm) &&
                               !data_oe && (port_q == $past(port_q)));
      goal[28] <= goal[28] || ($past((port_q != 4'h0) && !clr_n) &&
                               (port_q == 4'h0));
      // Synchronous reset takes effect one edge after rst_n drops: the
      // chip first finishes the period in progress, then lands on A1 with
      // the static flip-flops cleared and the bus released.
      goal[29] <= goal[29] || ($past(!rst_n && (phase != PhA1)) &&
                               (phase == PhA1) && !data_oe);
      goal[30] <= goal[30] || (sync && (phase == PhX3));
      goal[31] <= goal[31] || (seen_m1 && m1_drive &&
                               (addr_q != last_addr));
      goal[32] <= goal[32] || ((phase == PhX3) && s_src &&
                               (io_sel_q == $past(io_sel_q)) &&
                               (data_i != io_sel_q));
      goal[33] <= goal[33] || rdr_drive_x2;
      goal[34] <= goal[34] || rdr_drive_x3;
      goal[35] <= goal[35] || ($past((phase == PhA1) && !cm_rom) &&
                               (addr_q[3:0] == $past(addr_q[3:0])));
      goal[36] <= goal[36] || ((phase == PhX2) && s_src &&
                               (data_i != CHIP_NO));
      goal[37] <= goal[37] || seen_m1_cycle && (phase == PhM2) && data_oe &&
                               fetch_selected;

      // Tracking flags
      if ((phase == PhX2) && s_src) begin
        seen_src <= 1'b1;
        if (data_i != CHIP_NO) begin
          saw_sel_other <= 1'b1;
        end else begin
          saw_sel_match <= 1'b1;
        end
      end
      if ((phase == PhX3) && s_wrr && io_selected) begin
        seen_wrr <= 1'b1;
        wrr_val  <= data_i;
      end
      if (m1_drive) begin
        seen_m1       <= 1'b1;
        last_addr     <= addr_q;
        seen_m1_cycle <= 1'b1;
      end
      if (phase == PhX3) begin
        seen_m1_cycle <= 1'b0;
      end
    end
  end

  always @(posedge clk) begin
    if (!$initstate) begin
      c00_phase_a1:        cover (goal[0]);
      c01_phase_a2:        cover (goal[1]);
      c02_phase_a3:        cover (goal[2]);
      c03_phase_m1:        cover (goal[3]);
      c04_phase_m2:        cover (goal[4]);
      c05_phase_x1:        cover (goal[5]);
      c06_phase_x2:        cover (goal[6]);
      c07_phase_x3:        cover (goal[7]);
      c08_addr_00:         cover (goal[8]);
      c09_addr_ff:         cover (goal[9]);
      c10_addr_01:         cover (goal[10]);
      c11_addr_fe:         cover (goal[11]);
      c12_addr_80:         cover (goal[12]);
      c13_word_hi_f:       cover (goal[13]);
      c14_word_lo_0:       cover (goal[14]);
      c15_unsel_a3_quiet:  cover (goal[15]);
      c16_select_match:    cover (goal[16]);
      c17_select_switch:   cover (goal[17]);
      c18_wrr_latch_0:     cover (goal[18]);
      c19_wrr_latch_nz:    cover (goal[19]);
      c20_wrr_overwrite:   cover (goal[20]);
      c21_rdr_value_0:     cover (goal[21]);
      c22_rdr_value_nz:    cover (goal[22]);
      c23_rdr_before_src:  cover (goal[23]);
      c24_rdr_after_wrr:   cover (goal[24]);
      c25_wrr_unsel_hold:  cover (goal[25]);
      c26_rdr_unsel_quiet: cover (goal[26]);
      c27_wpm_ignored:     cover (goal[27]);
      c28_clr_clears:      cover (goal[28]);
      c29_reset_midcycle:  cover (goal[29]);
      c30_sync_relock:     cover (goal[30]);
      c31_addr_change:     cover (goal[31]);
      c32_src_x3_ignored:  cover (goal[32]);
      c33_rdr_drive_x2:    cover (goal[33]);
      c34_rdr_drive_x3:    cover (goal[34]);
      c35_a1_no_cmrom:     cover (goal[35]);
      c36_src_other_chip:  cover (goal[36]);
      c37_a3_sel_latched:  cover (goal[37]);
    end
  end

  // Ports not needed by any goal are referenced so the port list stays
  // fully used.
  logic _unused;
  assign _unused = &{1'b0, port_i, cm_rom_seen, fetch_sel_q, opr_q, opa_q};

endmodule
