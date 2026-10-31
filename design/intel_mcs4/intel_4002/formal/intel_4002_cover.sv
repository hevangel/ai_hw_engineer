// Formal cover enumeration for the Intel 4002 reconstruction.
//
// Non-vacuity witness for the property set: every command, storage corner,
// selection corner, and reset path is shown reachable within the cover
// depth, under the same minimal environment as intel_4002_props (reset
// entry, one SYNC pulse per 8 clocks, otherwise free bus/bank/strap
// inputs). ChipMsb is this DUT's chip-number MSB (0 for a 4002-1,
// 1 for a 4002-2).
module intel_4002_cover #(
    parameter ChipMsb = 1'b0
) (
    input logic        clk,
    input logic        rst_n,
    input logic [3:0]  data_i,
    input logic [3:0]  data_o,
    input logic        data_oe,
    input logic        sync,
    input logic        cm_ram_i,
    input logic        po_i,
    input logic [3:0]  io_o,
    // DUT internals
    input logic [2:0]  phase,
    input logic [3:0]  cmd_opr,
    input logic [3:0]  cmd_opa,
    input logic [7:0]  addr,
    input logic [3:0]  out_port,
    input logic        selected,
    input logic [255:0] main_flat,
    input logic [63:0]  stat_flat
);

  localparam logic [2:0] PhM1 = 3'd3;
  localparam logic [2:0] PhM2 = 3'd4;
  localparam logic [2:0] PhX2 = 3'd6;
  localparam logic [2:0] PhX3 = 3'd7;

  // ------------------------------------------------------------------
  // Environment (mirrors intel_4002_props)
  // ------------------------------------------------------------------
  logic boot;
  initial boot = 1'b1;
  always_ff @(posedge clk) begin
    boot <= 1'b0;
  end

  logic [2:0] cyc;
  initial cyc = 3'd6;
  always_ff @(posedge clk) begin
    if (!rst_n) begin
      cyc <= 3'd6;  // first post-release cycle has cyc==7: the SYNC (A1) cycle
    end else begin
      cyc <= cyc + 3'd1;
    end
  end

  always @(posedge clk) begin
    if (boot || $past(boot)) begin
      assume (!rst_n);
    end
    if (rst_n && !$initstate) begin
      assume (sync == (cyc == 3'd7));
    end
  end

  // ------------------------------------------------------------------
  // Local decode of DUT state
  // ------------------------------------------------------------------
  logic is_src, is_io, is_read, is_write;
  logic romside;
  assign is_src   = (cmd_opr == 4'h2) && cmd_opa[0];
  assign is_io    = (cmd_opr == 4'he);
  assign romside  = (cmd_opa == 4'h2) || (cmd_opa == 4'h3) ||
                    (cmd_opa == 4'ha);
  assign is_write = is_io && !romside && !cmd_opa[3];
  assign is_read  = is_io && !romside && cmd_opa[3];

  logic [5:0] main_ix;
  logic [3:0] stat_ix;
  assign main_ix = {addr[5:4], addr[3:0]};
  assign stat_ix = {addr[5:4], cmd_opa[1:0]};

  // ------------------------------------------------------------------
  // History flags (set once, never cleared except by init)
  // ------------------------------------------------------------------
  logic f_wrm_nonzero, f_wmp_seen, f_src_done, f_wrs_seen;
  logic f_wmp_nonzero;
  logic [3:0] f_last_wmp;
  logic [3:0] f_last_wrm_val;
  logic [5:0] f_last_wrm_ix;
  logic [3:0] f_last_wrs_val;
  logic [3:0] f_last_wrs_ix;
  initial begin
    f_wrm_nonzero   = 1'b0;
    f_wmp_seen      = 1'b0;
    f_wmp_nonzero   = 1'b0;
    f_src_done      = 1'b0;
    f_wrs_seen      = 1'b0;
    f_last_wmp      = 4'h0;
    f_last_wrm_val  = 4'h0;
    f_last_wrm_ix   = 6'd0;
    f_last_wrs_val  = 4'h0;
    f_last_wrs_ix   = 4'h0;
  end

  always_ff @(posedge clk) begin
    if (rst_n) begin
      if (phase == PhX3 && selected && is_write && cmd_opa == 4'h0) begin
        f_last_wrm_val <= data_i;
        f_last_wrm_ix  <= main_ix;
        if (data_i != 4'h0) begin
          f_wrm_nonzero <= 1'b1;
        end
      end
      if (phase == PhX3 && selected && is_write && cmd_opa == 4'h1) begin
        f_last_wmp <= data_i;
        f_wmp_seen <= 1'b1;
        if (data_i != 4'h0) begin
          f_wmp_nonzero <= 1'b1;
        end
      end
      if (phase == PhX3 && selected && is_write && cmd_opa >= 4'h4 &&
          cmd_opa <= 4'h7) begin
        f_last_wrs_val <= data_i;
        f_last_wrs_ix  <= stat_ix;
        f_wrs_seen     <= 1'b1;
      end
      if (is_src && cm_ram_i && phase == PhX3) begin
        f_src_done <= 1'b1;
      end
    end
  end

  // ------------------------------------------------------------------
  // Covers
  // ------------------------------------------------------------------
  always @(posedge clk) begin
    if (rst_n && !$initstate) begin
      // -- each command executing with this chip selected (13)
      c_wrm: cover (phase == PhX3 && selected && is_write &&
                    cmd_opa == 4'h0);
      c_wmp: cover (phase == PhX3 && selected && is_write &&
                    cmd_opa == 4'h1);
      c_wr0: cover (phase == PhX3 && selected && is_write &&
                    cmd_opa == 4'h4);
      c_wr1: cover (phase == PhX3 && selected && is_write &&
                    cmd_opa == 4'h5);
      c_wr2: cover (phase == PhX3 && selected && is_write &&
                    cmd_opa == 4'h6);
      c_wr3: cover (phase == PhX3 && selected && is_write &&
                    cmd_opa == 4'h7);
      c_sbm: cover (phase == PhX3 && selected && cmd_opa == 4'h8 &&
                    data_oe);
      c_rdm: cover (phase == PhX3 && selected && cmd_opa == 4'h9 &&
                    data_oe);
      c_adm: cover (phase == PhX3 && selected && cmd_opa == 4'hb &&
                    data_oe);
      c_rd0: cover (phase == PhX3 && selected && cmd_opa == 4'hc &&
                    data_oe);
      c_rd1: cover (phase == PhX3 && selected && cmd_opa == 4'hd &&
                    data_oe);
      c_rd2: cover (phase == PhX3 && selected && cmd_opa == 4'he &&
                    data_oe);
      c_rd3: cover (phase == PhX3 && selected && cmd_opa == 4'hf &&
                    data_oe);

      // -- read data quality (3)
      c_rdm_nonzero: cover (phase == PhX3 && selected &&
                            cmd_opa == 4'h9 && data_oe && data_o != 4'h0);
      c_adm_nonzero: cover (phase == PhX3 && selected &&
                            cmd_opa == 4'hb && data_oe && data_o != 4'h0);
      c_sbm_nonzero: cover (phase == PhX3 && selected &&
                            cmd_opa == 4'h8 && data_oe && data_o != 4'h0);

      // -- write/read roundtrips matching the tracked cell (2)
      c_wrm_rdm_match: cover (f_wrm_nonzero && phase == PhX3 && selected &&
                              cmd_opa == 4'h9 && data_oe &&
                              main_ix == f_last_wrm_ix &&
                              data_o == f_last_wrm_val);
      c_wrs_rds_match: cover (f_wrs_seen && phase == PhX3 && selected &&
                              cmd_opa[3] && cmd_opa[2] && data_oe &&
                              stat_ix == f_last_wrs_ix &&
                              data_o == f_last_wrs_val);

      // -- output port overwrite with a different value (1)
      c_wmp_overwrite: cover (f_wmp_seen && phase == PhX3 && selected &&
                              is_write && cmd_opa == 4'h1 &&
                              data_i != f_last_wmp);

      // -- SRC field extremes (4)
      c_src_reg0:  cover (is_src && cm_ram_i && phase == PhX2 &&
                          data_i[1:0] == 2'd0);
      c_src_reg3:  cover (is_src && cm_ram_i && phase == PhX2 &&
                          data_i[1:0] == 2'd3);
      c_src_char0: cover (is_src && cm_ram_i && phase == PhX3 &&
                          data_i == 4'h0);
      c_src_char15: cover (is_src && cm_ram_i && phase == PhX3 &&
                           data_i == 4'hf);

      // -- selection corners (3)
      c_chip_match: cover (is_src && cm_ram_i && phase == PhX3 &&
                           data_i[3:2] == {ChipMsb, po_i});
      c_chip_miss:  cover (is_src && cm_ram_i && phase == PhX2 &&
                           data_i[3:2] != {ChipMsb, po_i});
      c_bank_low:   cover (is_src && !cm_ram_i && phase == PhX2);

      // -- drive-enable placement (3)
      c_oe_x2: cover (phase == PhX2 && data_oe);
      c_oe_x3: cover (phase == PhX3 && data_oe);
      c_no_drive_m1: cover (phase == PhM1 && data_i == 4'he && !data_oe);

      // -- unselected command never drives (1)
      c_unselected_read: cover (phase == PhX3 && is_read && !selected &&
                                !data_oe);

      // -- ROM-side encodings ignored (1)
      c_romside_idle: cover (phase == PhX3 && is_io && romside &&
                             !data_oe);

      // -- reset clears live state (2). Note: that a written main-memory
      // cell actually reads 0 after the reset edge is ASSERTED in
      // intel_4002_props (a_s6_main, full-vector compare); here the cover
      // only witnesses that a write -> reset sequence is reachable, so the
      // assertion cannot be vacuous. The cleared cell is deliberately NOT
      // re-observed through the 64-way main_flat mux, which would drag the
      // whole array into every cover query (prohibitively slow for the z3
      // cover engine; see plans/formal_plan.md).
      c_reset_port_clear: cover (f_wmp_nonzero && rst_n && !$initstate &&
                                 $past(!rst_n) && io_o == 4'h0);
      c_reset_mem_clear:  cover (f_wrm_nonzero && rst_n && !$initstate &&
                                 $past(!rst_n) && !data_oe);

      // -- sequencer (2)
      c_cycle_wrap: cover (phase == PhX3);
      c_src_then_cmd: cover (f_src_done && phase == PhX3 && selected &&
                             is_read && data_oe);

      // -- status write into register 2 and main write to character 15 (2)
      c_stat_reg2: cover (phase == PhX3 && selected && is_write &&
                          cmd_opa >= 4'h4 && cmd_opa <= 4'h7 &&
                          addr[5:4] == 2'd2);
      c_wrm_char15: cover (phase == PhX3 && selected && is_write &&
                           cmd_opa == 4'h0 && addr[3:0] == 4'hf);
    end
  end

  // main_flat/stat_flat are passed for interface parity with
  // intel_4002_props but intentionally not observed here (see the reset
  // cover note above); fold them away so the array-view muxes are pruned
  // from the cover build.
  logic _unused_cover;
  assign _unused_cover = &{1'b0, main_flat, stat_flat};

endmodule
