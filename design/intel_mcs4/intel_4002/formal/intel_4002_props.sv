// Formal safety properties for the Intel 4002 reconstruction.
//
// The golden model in this module is an independent behavioral model written
// from spec/spec.md: it mirrors the phase sequencer, the M1/M2 command
// latches, the SRC address register, the output port, and the complete main
// and status arrays (as flat vectors) using its own decode expressions.
// Equality with the DUT is asserted on every state element at every clock,
// for arbitrary (completely unconstrained) bus traffic, bank-line activity,
// and P0 strap, which proves the full protocol transition function rather
// than sampled cases.
//
// Environment assumptions are deliberately minimal: reset asserted in the
// initial state, and a well-formed SYNC pulse once every eight clocks after
// reset release (one instruction cycle). data_i, cm_ram_i, po_i, and any
// later reset activity remain free.
//
// ChipMsb is the chip-number MSB this DUT answers to: 0 for a 4002-1,
// 1 for a 4002-2 (the DUT derives it from its Variant1 parameter).
module intel_4002_props #(
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
  // Environment: reset entry, one SYNC pulse every 8 clocks
  // ------------------------------------------------------------------
  logic boot;
  initial boot = 1'b1;          // 1 only in the initial timeframe
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
      a_reset_boot: assume (!rst_n);  // hold reset for the first two edges
    end
    if (rst_n && !$initstate) begin
      a_sync_form: assume (sync == (cyc == 3'd7));
    end
  end

  // ------------------------------------------------------------------
  // Independent golden model per spec sections 4-7
  // ------------------------------------------------------------------
  logic [2:0]   g_phase;
  logic [3:0]   g_cmd_opr;
  logic [3:0]   g_cmd_opa;
  logic [7:0]   g_addr;
  logic [3:0]   g_out_port;
  logic [255:0] g_main;
  logic [63:0]  g_stat;

  // Formal init: known base state instead of free constants (see the DUT's
  // FORMAL initial block).
  initial begin
    g_phase    = 3'd0;
    g_cmd_opr  = 4'h0;
    g_cmd_opa  = 4'h0;
    g_addr     = 8'h0;
    g_out_port = 4'h0;
    g_main     = 256'h0;
    g_stat     = 64'h0;
  end

  // Decode, re-derived from the spec tables
  logic m_is_src;
  logic m_is_io;
  logic m_romside;   // WRR / WPM / RDR: not 4002 operations
  logic m_is_wrm;
  logic m_is_wmp;
  logic m_is_wrsc;   // WR0-WR3
  logic m_is_read;   // SBM, RDM, ADM, RD0-RD3
  logic m_sel;
  logic [5:0] m_main_ix;
  logic [3:0] m_stat_ix;
  assign m_is_src   = (g_cmd_opr == 4'h2) && g_cmd_opa[0];
  assign m_is_io    = (g_cmd_opr == 4'he);
  assign m_romside  = (g_cmd_opa == 4'h2) || (g_cmd_opa == 4'h3) ||
                      (g_cmd_opa == 4'ha);
  assign m_is_wrm   = m_is_io && (g_cmd_opa == 4'h0);
  assign m_is_wmp   = m_is_io && (g_cmd_opa == 4'h1);
  assign m_is_wrsc  = m_is_io && (g_cmd_opa >= 4'h4) && (g_cmd_opa <= 4'h7);
  assign m_is_read  = m_is_io && !m_romside && g_cmd_opa[3];
  assign m_sel      = cm_ram_i &&
                      (g_addr[7:6] == {ChipMsb, po_i});
  assign m_main_ix  = {g_addr[5:4], g_addr[3:0]};
  assign m_stat_ix  = {g_addr[5:4], g_cmd_opa[1:0]};

  logic [3:0] m_rd_val;
  always_comb begin
    m_rd_val = 4'h0;
    if (m_is_read) begin
      if (g_cmd_opa == 4'h8 || g_cmd_opa == 4'h9 || g_cmd_opa == 4'hb) begin
        m_rd_val = g_main[m_main_ix*4 +: 4];
      end else begin
        m_rd_val = g_stat[m_stat_ix*4 +: 4];
      end
    end
  end

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      g_phase    <= 3'd0;
      g_cmd_opr  <= 4'h0;
      g_cmd_opa  <= 4'h0;
      g_addr     <= 8'h0;
      g_out_port <= 4'h0;
      g_main     <= 256'h0;
      g_stat     <= 64'h0;
    end else begin
      if (sync) begin
        g_phase <= 3'd1;
      end else begin
        g_phase <= g_phase + 3'd1;
      end
      if (g_phase == PhM1) begin
        g_cmd_opr <= data_i;
      end
      if (g_phase == PhM2) begin
        g_cmd_opa <= data_i;
      end
      if (m_is_src && cm_ram_i && g_phase == PhX2) begin
        g_addr[7:4] <= data_i;
      end
      if (m_is_src && cm_ram_i && g_phase == PhX3) begin
        g_addr[3:0] <= data_i;
      end
      if (g_phase == PhX3 && m_sel) begin
        if (m_is_wrm) begin
          g_main[m_main_ix*4 +: 4] <= data_i;
        end
        if (m_is_wmp) begin
          g_out_port <= data_i;
        end
        if (m_is_wrsc) begin
          g_stat[m_stat_ix*4 +: 4] <= data_i;
        end
      end
    end
  end

  // ------------------------------------------------------------------
  // S1: full-state equality (covers storage integrity for all addresses)
  // ------------------------------------------------------------------
  always @(posedge clk) begin
    if (rst_n && !$initstate && $past(rst_n)) begin
      a_phase_eq: assert (phase == g_phase);
      a_opr_eq:   assert (cmd_opr == g_cmd_opr);
      a_opa_eq:   assert (cmd_opa == g_cmd_opa);
      a_addr_eq:  assert (addr == g_addr);
      a_port_eq:  assert (out_port == g_out_port);
      a_main_eq:  assert (main_flat == g_main);
      a_stat_eq:  assert (stat_flat == g_stat);
      a_sel_eq:   assert (selected == m_sel);
      a_io_o_eq:  assert (io_o == g_out_port);
    end
  end

  // ------------------------------------------------------------------
  // S2: write-read consistency at an anyconst main-memory cell (written
  // value persists until the next write to that same cell) and at an
  // anyconst status cell
  // ------------------------------------------------------------------
  (* anyconst *) logic [5:0] mc;
  (* anyconst *) logic [3:0] sc;

  logic [3:0] exp_mc;
  logic [3:0] exp_sc;
  initial begin
    exp_mc = 4'h0;
    exp_sc = 4'h0;
  end
  always_ff @(posedge clk) begin
    if (!rst_n) begin
      exp_mc <= 4'h0;
      exp_sc <= 4'h0;
    end else begin
      if (g_phase == PhX3 && m_sel && m_is_wrm && m_main_ix == mc) begin
        exp_mc <= data_i;
      end
      if (g_phase == PhX3 && m_sel && m_is_wrsc && m_stat_ix == sc) begin
        exp_sc <= data_i;
      end
    end
  end

  always @(posedge clk) begin
    if (rst_n && !$initstate && $past(rst_n)) begin
      a_s2_main: assert (main_flat[mc*4 +: 4] == exp_mc);
      a_s2_stat: assert (stat_flat[sc*4 +: 4] == exp_sc);
    end
  end

  // ------------------------------------------------------------------
  // S3: no cross-address corruption — a write to one anyconst main cell
  // leaves a different anyconst main cell unchanged; same for status
  // ------------------------------------------------------------------
  (* anyconst *) logic [5:0] ma;
  (* anyconst *) logic [5:0] mb;
  (* anyconst *) logic [3:0] sa;
  (* anyconst *) logic [3:0] sb;

  always @(posedge clk) begin
    if (rst_n && !$initstate && $past(rst_n)) begin
      if ($past(g_phase == PhX3 && m_sel && m_is_wrm) &&
          $past(m_main_ix) == mb && ma != mb) begin
        a_s3_main: assert (main_flat[ma*4 +: 4] ==
                           $past(main_flat[ma*4 +: 4]));
      end
      if ($past(g_phase == PhX3 && m_sel && m_is_wrsc) &&
          $past(m_stat_ix) == sb && sa != sb) begin
        a_s3_stat: assert (stat_flat[sa*4 +: 4] ==
                           $past(stat_flat[sa*4 +: 4]));
      end
    end
  end

  // ------------------------------------------------------------------
  // S4: drive-enable gating — the chip drives only in X2/X3, only under a
  // 4002 read command, only while its bank line is active and its chip
  // number matches; and then exactly the selected storage nibble
  // ------------------------------------------------------------------
  always @(posedge clk) begin
    if (rst_n && !$initstate && $past(rst_n)) begin
      if (data_oe) begin
        a_s4_phase: assert (phase == PhX2 || phase == PhX3);
        a_s4_cmd:   assert (m_is_read);
        a_s4_bank:  assert (cm_ram_i);
        a_s4_chip:  assert (addr[7:6] == {ChipMsb, po_i});
        a_s4_data:  assert (data_o == m_rd_val);
      end
      // Complement: no drive while the bank line is inactive
      if (!cm_ram_i) begin
        a_s4_no_bank: assert (!data_oe);
      end
    end
  end

  // ------------------------------------------------------------------
  // S5: output-port semantics — changes only at a selected WMP commit,
  // holds otherwise (exp tracking); golden equality (a_port_eq) covers
  // the same contract from the model side
  // ------------------------------------------------------------------
  logic [3:0] exp_port;
  initial exp_port = 4'h0;
  always_ff @(posedge clk) begin
    if (!rst_n) begin
      exp_port <= 4'h0;
    end else if (g_phase == PhX3 && m_sel && m_is_wmp) begin
      exp_port <= data_i;
    end
  end

  always @(posedge clk) begin
    if (rst_n && !$initstate && $past(rst_n)) begin
      a_s5_port: assert (io_o == exp_port);
    end
  end

  // ------------------------------------------------------------------
  // S6: reset behavior — one cycle after a reset edge everything is
  // cleared and the bus buffer is off
  // ------------------------------------------------------------------
  always @(posedge clk) begin
    if (!$initstate && rst_n && $past(!rst_n)) begin
      a_s6_phase: assert (phase == 3'd0);
      a_s6_oe:    assert (!data_oe);
      a_s6_addr:  assert (addr == 8'h0);
      a_s6_port:  assert (io_o == 4'h0);
      a_s6_main:  assert (main_flat == 256'h0);
      a_s6_stat:  assert (stat_flat == 64'h0);
    end
  end

  // ------------------------------------------------------------------
  // S7: address decode — the X2/X3 nibble placement of the SRC select
  // code, visible one cycle after each load edge
  // ------------------------------------------------------------------
  logic dut_is_src;
  assign dut_is_src = (cmd_opr == 4'h2) && cmd_opa[0];

  always @(posedge clk) begin
    if (rst_n && !$initstate && $past(rst_n)) begin
      if ($past(phase == PhX2) && $past(dut_is_src && cm_ram_i)) begin
        a_s7_hi: assert (addr[7:4] == $past(data_i));
      end
      if ($past(phase == PhX3) && $past(dut_is_src && cm_ram_i)) begin
        a_s7_lo: assert (addr[3:0] == $past(data_i));
      end
    end
  end

endmodule
