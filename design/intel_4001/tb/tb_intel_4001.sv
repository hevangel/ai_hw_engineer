`timescale 1ns/1ps

// Self-checking testbench for the Intel 4001 reconstruction (direct, no
// UVM). The bench plays the 4004 CPU side of an MCS-4 bus: a bus master
// issues genuine eight-period instruction cycles (SYNC-punctuated,
// CM-ROM during A1-A3 and during the X2/X3 ROM-port periods of
// WRR/WPM/RDR) using the exact timing of the verified intel_4004
// reconstruction, while two intel_4001 instances respond on the shared
// bus:
//   dut0: chip number 0, default mask (word(a) = (37a+61) mod 256),
//         all-output I/O port;
//   dut1: chip number 1, second mask (word(a) = (13a+137) mod 256),
//         pins 0-1 outputs / pins 2-3 inputs.
// An independently written golden model tracks what each chip should
// have latched and should be driving, decoding instructions from the
// OBSERVED bus (not from test intent); the scoreboard compares both
// chips' pins and their internal state (hierarchical references) at
// every clock period.
//
// Timing methodology: the master changes its outputs at negedges; a
// value driven at a negedge is sampled by the chips at the next posedge.
// Chip outputs (registered at posedges, stable within the period) are
// compared at negedges, and the bus value the chips will sample at the
// next posedge is computed from the drive enables directly. Only one
// driver is enabled per period; collisions are flagged at sample points.
// Reset and CL overrides ride on ordinary clocked periods (the tick task
// forces idle drives while rst_cnt/clr_cnt are set), so the master's
// period counter and the chips' phase counters never drift: reset ticks
// pin the master period to A1, and the first post-reset tick is a real
// A1 with SYNC, which the chips' sync re-lock accepts from any state.
//
// Port-op cycles (SRC/WRR/RDR fetches) address absent chip number 2 so
// no instantiated ROM drives M1/M2; the master then injects the fetched
// word, standing in for program memory whose fixed mask cannot contain
// arbitrary opcodes. Ordinary fetch cycles address a real chip and the
// master releases the bus at M1/M2 for that chip to drive the word.
module tb_intel_4001;

  // ------------------------------------------------------------------
  // Clock, reset/clear, command lines, CPU-side bus drive
  // ------------------------------------------------------------------
  logic clk;
  logic       rst_n  = 1'b0;
  logic       clr_n  = 1'b1;
  logic       sync   = 1'b0;
  logic       cm_rom = 1'b0;
  logic [3:0] cpu_do = 4'h0;
  logic       cpu_oe = 1'b0;

  initial begin
    clk = 1'b0;
  end
  always #5 clk = ~clk;

  // ------------------------------------------------------------------
  // DUTs and bus resolution
  // ------------------------------------------------------------------
  logic [3:0] d0_data_o, d1_data_o;
  logic       d0_oe, d1_oe;
  logic [3:0] bus_data;
  logic [3:0] port1_in = 4'h0;
  logic [3:0] dut0_port_o, dut1_port_o;
  logic [3:0] dut0_port_oe, dut1_port_oe;

  // Bus value seen by every chip: the single enabled driver wins.
  always_comb begin
    if (cpu_oe) begin
      bus_data = cpu_do;
    end else if (d0_oe) begin
      bus_data = d0_data_o;
    end else if (d1_oe) begin
      bus_data = d1_data_o;
    end else begin
      bus_data = 4'h0;
    end
  end

  intel_4001 dut0 (
      .clk     (clk),
      .rst_n   (rst_n),
      .clr_n   (clr_n),
      .data_i  (bus_data),
      .data_o  (d0_data_o),
      .data_oe (d0_oe),
      .sync    (sync),
      .cm_rom  (cm_rom),
      .port_i  (4'h0),
      .port_o  (dut0_port_o),
      .port_oe (dut0_port_oe)
  );

  localparam logic [2047:0] MASK_B = 2048'h7c6f6255483b2e211407faede0d3c6b9ac9f9285786b5e5144372a1d1003f6e9dccfc2b5a89b8e8174675a4d403326190cfff2e5d8cbbeb1a4978a7d706356493c2f221508fbeee1d4c7baada09386796c5f5245382b1e1104f7eaddd0c3b6a99c8f8275685b4e4134271a0d00f3e6d9ccbfb2a5988b7e7164574a3d30231609fcefe2d5c8bbaea194877a6d605346392c1f1205f8ebded1c4b7aa9d908376695c4f4235281b0e01f4e7dacdc0b3a6998c7f7265584b3e3124170afdf0e3d6c9bcafa295887b6e6154473a2d201306f9ecdfd2c5b8ab9e9184776a5d504336291c0f02f5e8dbcec1b4a79a8d807366594c3f3225180bfef1e4d7cabdb0a39689;

  intel_4001 #(
      .CHIP_NO (4'h1),
      .IO_DIR  (4'b0011),
      .ROM_INIT(MASK_B)
  ) dut1 (
      .clk     (clk),
      .rst_n   (rst_n),
      .clr_n   (clr_n),
      .data_i  (bus_data),
      .data_o  (d1_data_o),
      .data_oe (d1_oe),
      .sync    (sync),
      .cm_rom  (cm_rom),
      .port_i  (port1_in),
      .port_o  (dut1_port_o),
      .port_oe (dut1_port_oe)
  );

  // ------------------------------------------------------------------
  // Scoreboard bookkeeping and golden-model state
  // ------------------------------------------------------------------
  integer checks;
  integer failures;
  integer cycle_count;

  logic [7:0] g_addr;
  logic       g_cmrom_seen;
  logic       g_fetch_sel0;
  logic       g_fetch_sel1;
  logic [3:0] g_opr;
  logic [3:0] g_opa;
  logic [3:0] g_io_sel;
  logic [3:0] g_port0;
  logic [3:0] g_port1;

  logic s_src_g, s_wrr_g, s_rdr_g;
  assign s_src_g = (g_opr == 4'h2) && g_opa[0];
  assign s_wrr_g = (g_opr == 4'he) && (g_opa == 4'h2);
  assign s_rdr_g = (g_opr == 4'he) && (g_opa == 4'ha);

  // Golden port read values (independent of DUT logic)
  logic [3:0] g_rdr0, g_rdr1;
  assign g_rdr0 = g_port0;
  assign g_rdr1 = (4'b0011 & g_port1) | (4'b1100 & port1_in);

  function automatic logic [7:0] mask_a(input logic [7:0] a);
    logic [7:0] s;
    begin
      s      = a * 8'd37 + 8'd61;  // mod-256 arithmetic matches the mask
      mask_a = s;
    end
  endfunction

  function automatic logic [7:0] mask_b(input logic [7:0] a);
    logic [7:0] s;
    begin
      s      = a * 8'd13 + 8'd137;
      mask_b = s;
    end
  endfunction

  // Master period counter (0 = A1 .. 7 = X3) and per-edge bookkeeping
  logic [2:0] mp;
  logic       ge_rst;   // rst_n sampled at the last posedge
  logic       ge_clr;   // clr_n sampled at the last posedge
  logic       cur_rom;  // cm_rom driven during the last completed period
  logic [3:0] cap_bus;  // bus value sampled at the last posedge
  logic       checks_on;
  integer     rst_cnt;  // remaining forced-reset periods
  integer     clr_cnt;  // remaining forced-clear periods

  task automatic inc_fail;
    begin
      failures = failures + 1;
    end
  endtask

  // ------------------------------------------------------------------
  // Golden-model update for the posedge that just completed
  // ------------------------------------------------------------------
  task automatic golden_update(input logic [2:0] ended_phase);
    begin
      if (ge_rst) begin
        if (ended_phase == 3'd0) begin
          if (cur_rom) begin
            g_addr[3:0] = cap_bus[3:0];
          end
        end else if (ended_phase == 3'd1) begin
          if (cur_rom) begin
            g_addr[7:4] = cap_bus[3:0];
          end
        end else if (ended_phase == 3'd2) begin
          if (cur_rom) begin
            g_fetch_sel0 = (cap_bus[3:0] == 4'h0);
            g_fetch_sel1 = (cap_bus[3:0] == 4'h1);
            g_cmrom_seen = 1'b1;
          end else begin
            g_fetch_sel0 = 1'b0;
            g_fetch_sel1 = 1'b0;
            g_cmrom_seen = 1'b0;
          end
        end else if (ended_phase == 3'd3) begin
          g_opr = cap_bus[3:0];  // every chip snoops every fetched word
        end else if (ended_phase == 3'd4) begin
          g_opa = cap_bus[3:0];
        end else if ((ended_phase == 3'd6) && s_src_g) begin
          g_io_sel = cap_bus[3:0];  // X2 nibble; the X3 nibble is ignored
        end else if ((ended_phase == 3'd7) && s_wrr_g) begin
          if (g_io_sel == 4'h0) begin
            g_port0 = cap_bus[3:0];
          end
          if (g_io_sel == 4'h1) begin
            g_port1 = cap_bus[3:0];
          end
        end
        if (!ge_clr) begin
          g_port0 = 4'h0;  // CL clears the I/O latches only
          g_port1 = 4'h0;
        end
      end else begin
        // RESET was sampled at that posedge: static flip-flops clear and
        // outputs are inhibited; the I/O latch is CL's job, not RESET's.
        g_addr       = 8'h0;
        g_cmrom_seen = 1'b0;
        g_fetch_sel0 = 1'b0;
        g_fetch_sel1 = 1'b0;
        g_opr        = 4'h0;
        g_opa        = 4'h0;
        g_io_sel     = 4'h0;
      end
    end
  endtask

  // ------------------------------------------------------------------
  // Compare both chips' outputs and internal state for the period now
  // in progress (index ph). Call only when out of reset on both edges.
  // ------------------------------------------------------------------
  task automatic compare_period(input logic [2:0] ph);
    logic       e0_oe, e1_oe;
    logic [3:0] e0_d, e1_d;
    logic       sel0, sel1;
    begin
      sel0 = g_fetch_sel0 && g_cmrom_seen;
      sel1 = g_fetch_sel1 && g_cmrom_seen;
      e0_oe = 1'b0;
      e1_oe = 1'b0;
      e0_d  = 4'h0;
      e1_d  = 4'h0;
      if (sel0 && (ph == 3'd3)) begin
        e0_oe = 1'b1;
        e0_d  = mask_a(g_addr)[7:4];
      end else if (sel0 && (ph == 3'd4)) begin
        e0_oe = 1'b1;
        e0_d  = mask_a(g_addr)[3:0];
      end else if ((g_io_sel == 4'h0) && s_rdr_g &&
                   ((ph == 3'd6) || (ph == 3'd7))) begin
        e0_oe = 1'b1;
        e0_d  = g_rdr0;
      end
      if (sel1 && (ph == 3'd3)) begin
        e1_oe = 1'b1;
        e1_d  = mask_b(g_addr)[7:4];
      end else if (sel1 && (ph == 3'd4)) begin
        e1_oe = 1'b1;
        e1_d  = mask_b(g_addr)[3:0];
      end else if ((g_io_sel == 4'h1) && s_rdr_g &&
                   ((ph == 3'd6) || (ph == 3'd7))) begin
        e1_oe = 1'b1;
        e1_d  = g_rdr1;
      end

      checks = checks + 1;
      if (d0_oe !== e0_oe) begin
        inc_fail();
        $display("FAIL d0_oe ph=%0d got=%b exp=%b (addr=%h sel0=%b)",
                 ph, d0_oe, e0_oe, g_addr, sel0);
      end
      checks = checks + 1;
      if (d0_data_o !== e0_d) begin
        inc_fail();
        $display("FAIL d0_data ph=%0d got=%h exp=%h", ph, d0_data_o, e0_d);
      end
      checks = checks + 1;
      if (d1_oe !== e1_oe) begin
        inc_fail();
        $display("FAIL d1_oe ph=%0d got=%b exp=%b (addr=%h sel1=%b)",
                 ph, d1_oe, e1_oe, g_addr, sel1);
      end
      checks = checks + 1;
      if (d1_data_o !== e1_d) begin
        inc_fail();
        $display("FAIL d1_data ph=%0d got=%h exp=%h", ph, d1_data_o, e1_d);
      end

      checks = checks + 6;
      if (dut0_port_o !== g_port0) begin
        inc_fail();
        $display("FAIL port0_o got=%h exp=%h", dut0_port_o, g_port0);
      end
      if (dut0_port_oe !== 4'b1111) begin
        inc_fail();
        $display("FAIL port0_oe got=%b", dut0_port_oe);
      end
      if (dut1_port_o !== g_port1) begin
        inc_fail();
        $display("FAIL port1_o got=%h exp=%h", dut1_port_o, g_port1);
      end
      if (dut1_port_oe !== 4'b0011) begin
        inc_fail();
        $display("FAIL port1_oe got=%b", dut1_port_oe);
      end
      if (dut0.phase !== ph) begin
        inc_fail();
        $display("FAIL dut0.phase got=%0d exp=%0d", dut0.phase, ph);
      end
      if (dut1.phase !== ph) begin
        inc_fail();
        $display("FAIL dut1.phase got=%0d exp=%0d", dut1.phase, ph);
      end

      checks = checks + 10;
      if (dut0.addr_q !== g_addr) begin
        inc_fail();
        $display("FAIL dut0.addr_q got=%h exp=%h", dut0.addr_q, g_addr);
      end
      if (dut1.addr_q !== g_addr) begin
        inc_fail();
        $display("FAIL dut1.addr_q got=%h exp=%h", dut1.addr_q, g_addr);
      end
      if (dut0.opr_q !== g_opr) begin
        inc_fail();
        $display("FAIL dut0.opr_q got=%h exp=%h", dut0.opr_q, g_opr);
      end
      if (dut1.opr_q !== g_opr) begin
        inc_fail();
        $display("FAIL dut1.opr_q got=%h exp=%h", dut1.opr_q, g_opr);
      end
      if (dut0.opa_q !== g_opa) begin
        inc_fail();
        $display("FAIL dut0.opa_q got=%h exp=%h", dut0.opa_q, g_opa);
      end
      if (dut1.opa_q !== g_opa) begin
        inc_fail();
        $display("FAIL dut1.opa_q got=%h exp=%h", dut1.opa_q, g_opa);
      end
      if (dut0.io_sel_q !== g_io_sel) begin
        inc_fail();
        $display("FAIL dut0.io_sel got=%h exp=%h", dut0.io_sel_q, g_io_sel);
      end
      if (dut1.io_sel_q !== g_io_sel) begin
        inc_fail();
        $display("FAIL dut1.io_sel got=%h exp=%h", dut1.io_sel_q, g_io_sel);
      end
      if (dut0.port_q !== g_port0) begin
        inc_fail();
        $display("FAIL dut0.port_q got=%h exp=%h", dut0.port_q, g_port0);
      end
      if (dut1.port_q !== g_port1) begin
        inc_fail();
        $display("FAIL dut1.port_q got=%h exp=%h", dut1.port_q, g_port1);
      end

      if (ph == 3'd0) begin
        cycle_count = cycle_count + 1;
        checks      = checks + 2;
        if (dut0.fetch_sel_q !== g_fetch_sel0) begin
          inc_fail();
          $display("FAIL dut0.fetch_sel got=%b exp=%b", dut0.fetch_sel_q,
                   g_fetch_sel0);
        end
        if (dut1.fetch_sel_q !== g_fetch_sel1) begin
          inc_fail();
          $display("FAIL dut1.fetch_sel got=%b exp=%b", dut1.fetch_sel_q,
                   g_fetch_sel1);
        end
      end
    end
  endtask

  // ------------------------------------------------------------------
  // One clock period: apply the golden update for the posedge that just
  // completed, compare the period now in progress, then set the CPU
  // drive the chips sample at the next posedge. While rst_cnt/clr_cnt
  // are positive the override forces RESET/CL with idle bus drives; the
  // period counter is pinned to A1 across reset ticks so the first
  // normal tick after a reset is a genuine SYNC'd A1.
  // ------------------------------------------------------------------
  task automatic tick(
      input logic       p_sync,
      input logic       p_cm_rom,
      input logic       p_drive,
      input logic [3:0] p_data);
    logic       in_rst;
    logic [2:0] ended;
    logic       eff_drive;
    logic [3:0] eff_data;
    begin
      // Phase of the period that just ended at the previous posedge,
      // computed before any reset pinning of the counter
      ended = mp - 3'd1;
      // One-shot mid-cycle reset request: this period plus two holds
      if (rst_cnt == 0) begin
        in_rst = 1'b0;
      end else begin
        in_rst = 1'b1;
        rst_cnt = rst_cnt - 1;
        mp      = 3'd0;
      end

      rst_n = !in_rst;
      if (clr_cnt > 0) begin
        clr_n   = 1'b0;
        clr_cnt = clr_cnt - 1;
      end else begin
        clr_n = 1'b1;
      end

      golden_update(ended);
      if (checks_on && !in_rst && ge_rst) begin
        compare_period(mp);
      end

      // Effective CPU drive for this period (idle during reset)
      eff_drive = in_rst ? 1'b0 : p_drive;
      eff_data  = in_rst ? 4'h0 : p_data;
      sync   = in_rst ? 1'b0 : p_sync;
      cm_rom = in_rst ? 1'b0 : p_cm_rom;
      cpu_oe = eff_drive;
      cpu_do = eff_data;
      cur_rom = cm_rom;
      if (eff_drive) begin
        cap_bus = eff_data;
      end else if (d0_oe) begin
        cap_bus = d0_data_o;
      end else if (d1_oe) begin
        cap_bus = d1_data_o;
      end else begin
        cap_bus = 4'h0;
      end
      // Drive-collision check at the sample point
      if ((eff_drive && (d0_oe || d1_oe)) || (d0_oe && d1_oe)) begin
        inc_fail();
        $display("FAIL bus collision at mp=%0d cpu=%b d0=%b d1=%b",
                 mp, eff_drive, d0_oe, d1_oe);
      end
      checks = checks + 1;
      if (!in_rst) begin
        mp = mp + 3'd1;
      end
      ge_rst = rst_n;
      ge_clr = clr_n;
      @(negedge clk);
    end
  endtask

  task automatic idle_ticks(input integer n);
    integer i;
    begin
      for (i = 0; i < n; i = i + 1) begin
        tick(1'b0, 1'b0, 1'b0, 4'h0);
      end
    end
  endtask

  // A full NOP cycle with CL asserted throughout: clears both port
  // latches while the rest of the chip keeps running.
  task automatic op_clr;
    begin
      clr_cnt = 8;
      op_idle(8'h00);
    end
  endtask

  // One full instruction cycle. inject=1: master drives M1/M2 with the
  // fetched word (port-op cycles aimed at the absent chip 2). inject=0:
  // master releases M1/M2 and a real chip is expected to drive.
  // x2_cm/x3_cm: CM-ROM during the X2/X3 port periods (the 4004 asserts
  // it for WRR/WPM/RDR).
  task automatic do_cycle(
      input logic       inject,
      input logic [3:0] w_hi,
      input logic [3:0] w_lo,
      input logic [3:0] a3,
      input logic       x2_cm,
      input logic       x2_en,
      input logic [3:0] x2_val,
      input logic       x3_cm,
      input logic       x3_en,
      input logic [3:0] x3_val);
    begin
      tick(1'b1, 1'b1, 1'b1, w_lo);   // A1: word address low nibble
      tick(1'b0, 1'b1, 1'b1, w_hi);   // A2: word address high nibble
      tick(1'b0, 1'b1, 1'b1, a3);     // A3: chip number
      tick(1'b0, 1'b0, inject, w_hi); // M1: OPR (driven by ROM or bench)
      tick(1'b0, 1'b0, inject, w_lo); // M2: OPA
      tick(1'b0, 1'b0, 1'b0, 4'h0);   // X1
      tick(1'b0, x2_cm, x2_en, x2_val); // X2
      tick(1'b0, x3_cm, x3_en, x3_val); // X3
    end
  endtask

  // Fetch from a real chip's ROM page: address nibbles at A1/A2, chip
  // number at A3, bus released at M1/M2 for the chip to drive the word.
  task automatic op_fetch(input logic [3:0] chip, input logic [7:0] a);
    begin
      do_cycle(1'b0, a[7:4], a[3:0], chip, 1'b0, 1'b0, 4'h0, 1'b0, 1'b0,
               4'h0);
    end
  endtask

  // Cycle whose fetched word is injected (absent-chip fetch address 2)
  task automatic op_idle(input logic [7:0] word);
    begin
      do_cycle(1'b1, word[7:4], word[3:0], 4'h2, 1'b0, 1'b0, 4'h0, 1'b0,
               1'b0, 4'h0);
    end
  endtask

  // WPM with active X2/X3 drive and CM-ROM, as the 4004 drives it
  task automatic op_wpm_active(input logic [3:0] data);
    begin
      do_cycle(1'b1, 4'he, 4'h3, 4'h2, 1'b1, 1'b1, data, 1'b1, 1'b1, data);
    end
  endtask

  // SRC: X2 carries the select high nibble, X3 the low nibble (ignored
  // by the 4001). No CM-ROM at X2/X3 for SRC.
  task automatic op_src(input logic [3:0] sel_hi, input logic [3:0] sel_lo);
    begin
      do_cycle(1'b1, 4'h2, 4'h1, 4'h2, 1'b0, 1'b1, sel_hi, 1'b0, 1'b1,
               sel_lo);
    end
  endtask

  // WRR to ROM-port chip sel_hi
  task automatic op_wrr(input logic [3:0] sel_hi, input logic [3:0] data);
    begin
      op_src(sel_hi, 4'h0);
      do_cycle(1'b1, 4'he, 4'h2, 4'h2, 1'b1, 1'b1, data, 1'b1, 1'b1, data);
    end
  endtask

  // RDR from ROM-port chip sel_hi
  task automatic op_rdr(input logic [3:0] sel_hi);
    begin
      op_src(sel_hi, 4'h0);
      do_cycle(1'b1, 4'he, 4'ha, 4'h2, 1'b1, 1'b0, 4'h0, 1'b1, 1'b0, 4'h0);
    end
  endtask

  // Reset asserted at period at_p of an injected cycle + two hold
  // periods, then realigned; the port latch must survive.
  task automatic reset_mid_cycle(input integer at_p);
    integer p;
    begin
      for (p = 0; p < at_p; p = p + 1) begin
        if (p == 0) begin
          tick(1'b1, 1'b1, 1'b1, 4'h0);
        end else if (p <= 2) begin
          tick(1'b0, 1'b1, 1'b1, 4'h0);
        end else begin
          tick(1'b0, 1'b0, 1'b0, 4'h0);
        end
      end
      rst_cnt = 3;
      idle_ticks(3);
    end
  endtask

  // ------------------------------------------------------------------
  // Main sequence
  // ------------------------------------------------------------------
  integer      i;
  integer      a;
  logic [15:0] lfsr;
  logic [3:0]  rchip;
  logic [7:0]  raddr;
  logic [3:0]  rdata;
  logic [3:0]  rsel;

  function automatic logic [15:0] lfsr_next(input logic [15:0] l);
    lfsr_next = {l[14:0], l[15] ^ l[13] ^ l[12] ^ l[10]};
  endfunction

  initial begin
    checks      = 0;
    failures    = 0;
    cycle_count = 0;
    mp          = 3'd0;
    ge_rst      = 1'b0;
    ge_clr      = 1'b1;
    cur_rom     = 1'b0;
    cap_bus     = 4'h0;
    checks_on   = 1'b0;
    rst_cnt     = 4;
    clr_cnt     = 0;
    lfsr        = 16'hACE1;

    g_addr       = 8'h0;
    g_cmrom_seen = 1'b0;
    g_fetch_sel0 = 1'b0;
    g_fetch_sel1 = 1'b0;
    g_opr        = 4'h0;
    g_opa        = 4'h0;
    g_io_sel     = 4'h0;
    g_port0      = 4'h0;
    g_port1      = 4'h0;

    // D1: power-on reset (four forced-reset ticks pin the master period
    // to A1), then a full NOP cycle with CL asserted to define both port
    // latches. Compares come on with the CL cycle already running.
    idle_ticks(4);
    checks_on = 1'b1;
    op_clr();

    // D10: RDR from chip 0 before any SRC (select register reset value 0)
    op_rdr(4'h0);

    // D2: exhaustive ROM read of chip 0 (addresses 0x00 and 0xFF included)
    for (a = 0; a < 256; a = a + 1) begin
      op_fetch(4'h0, a[7:0]);
    end

    // D3: exhaustive ROM read of chip 1
    for (a = 0; a < 256; a = a + 1) begin
      op_fetch(4'h1, a[7:0]);
    end

    // D4: real and absent chips interleaved: only the addressed chip drives
    op_fetch(4'h2, 8'h7F);
    op_fetch(4'h0, 8'h00);
    op_fetch(4'h1, 8'hFF);
    op_fetch(4'h2, 8'h80);

    // D5/D6: WRR latch, RDR read-back, overwrite
    op_wrr(4'h0, 4'h5);
    op_rdr(4'h0);
    op_wrr(4'h0, 4'ha);
    op_rdr(4'h0);

    // D7: per-chip port isolation
    op_wrr(4'h1, 4'h3);
    op_rdr(4'h1);
    op_rdr(4'h0);  // chip 0 latch unchanged (0xA)

    // D8: mixed-direction port on chip 1: output pins 0-1 from the
    // latch, input pins 2-3 from port1_in
    port1_in = 4'hc;
    op_rdr(4'h1);  // expect {C, 3} = 0xF
    port1_in = 4'h0;
    op_rdr(4'h1);  // expect {0, 3} = 0x3
    op_wrr(4'h1, 4'h0);
    port1_in = 4'ha;
    op_rdr(4'h1);  // expect {A, 0} = 0x8
    port1_in = 4'h5;
    op_rdr(4'h1);  // expect {5, 0} = 0x4

    // D9: port ops aimed at an absent chip must not disturb the latches
    op_wrr(4'h2, 4'hf);
    op_rdr(4'h2);
    op_rdr(4'h0);
    op_rdr(4'h1);

    // D11: SRC X3 nibble carrying a different chip number is ignored
    op_src(4'h0, 4'h1);  // X2 selects chip 0, X3 says chip 1
    op_wrr(4'h0, 4'h7);  // must land in chip 0 per the X2 selection
    op_rdr(4'h0);

    // D12: instructions the 4001 ignores, including WPM with active
    // X2/X3 drive and CM-ROM (the CPU's WPM pattern)
    op_idle(8'h00);
    op_idle(8'he3);
    op_wpm_active(4'h9);
    op_idle(8'he0);
    op_idle(8'he1);
    op_idle(8'he9);
    op_idle(8'hff);
    op_idle(8'h23);

    // D13: reset mid-operation (during M2 of a fetch, then during the
    // X2 of a WRR); the port latch must survive and the system resumes
    op_wrr(4'h0, 4'hc);
    reset_mid_cycle(4);
    op_fetch(4'h0, 8'h42);
    reset_mid_cycle(6);
    op_rdr(4'h0);  // latch must still hold 0xC

    // D14: a CL cycle clears the latch mid-run; everything else continues
    op_wrr(4'h0, 4'hd);
    op_clr();
    op_rdr(4'h0);  // expect 0 after the clear
    op_fetch(4'h1, 8'h33);

    // D15: CL asserted through a complete WRR cycle — the clear dominates
    // the same-edge write (the I/O flip-flops stay cleared), on both chips
    clr_cnt = 8;
    do_cycle(1'b1, 4'he, 4'h2, 4'h2, 1'b1, 1'b1, 4'h9, 1'b1, 1'b1, 4'h9);
    op_rdr(4'h0);  // expect 0: WRR lost to CL at the X3 edge
    op_rdr(4'h1);

    // Randomized phase: 1500 LCG-driven operations (fixed seed)
    for (i = 0; i < 1500; i = i + 1) begin
      lfsr  = lfsr_next(lfsr);
      rchip = {2'b0, lfsr[1:0]};  // chips 0-3, of which 2 and 3 absent
      lfsr  = lfsr_next(lfsr);
      raddr = lfsr[7:0];
      lfsr  = lfsr_next(lfsr);
      rdata = lfsr[3:0];
      lfsr  = lfsr_next(lfsr);
      rsel  = {2'b0, lfsr[1:0]};
      port1_in = lfsr[7:4];
      case (lfsr[9:8])
        2'd0: op_fetch(rchip, raddr);
        2'd1: op_wrr(rsel, rdata);
        2'd2: op_rdr(rsel);
        2'd3: begin
          if (lfsr[10]) begin
            op_idle({lfsr[15:12], lfsr[11:8]});
          end else if (lfsr[11]) begin
            op_wpm_active(rdata);
          end else begin
            op_clr();
          end
        end
      endcase
    end

    // Final report
    $display("4001 tb: %0d checks, %0d instruction cycles, %0d failures",
             checks, cycle_count, failures);
    if (failures == 0) begin
      $display("TEST PASSED: %0d checks, %0d cycles", checks, cycle_count);
    end else begin
      $display("TEST FAILED: %0d failures (%0d checks, %0d cycles)",
               failures, checks, cycle_count);
    end
    $finish;
  end

  // Watchdog
  initial begin
    #40_000_000;
    $display("TEST FAILED: watchdog timeout at %0t", $time);
    $finish;
  end

endmodule
