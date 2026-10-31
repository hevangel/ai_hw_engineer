// Formal safety properties for the Intel 4001 reconstruction.
//
// The environment model is a well-formed MCS-4 bus master: SYNC punctuates
// A1 of every cycle, CM-ROM follows the documented 4004 pattern (address
// periods of every cycle plus X2/X3 of the ROM-port instructions WRR, WPM,
// RDR), instruction words are free constants delivered at M1/M2, address
// nibbles are free constants delivered at A1/A2/A3, the SRC select nibble
// and WRR write data are free constants. rst_n and clr_n stay free after
// the initial reset, so reset and clear dominance are checked from any
// period. Assertions guard with (rst_n && !$initstate && $past(rst_n)).
//
// The mask contents (rom_flat) are a free constant in the DUT itself, and
// the checked ROM address is an anyconst nibble pair, so the read-integrity
// proofs hold for every mask pattern and every address, not a sample.
module intel_4001_props (
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
    input logic [2047:0] rom_flat,
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

  // Free constants: address nibbles, fetched word, SRC select, WRR data,
  // and the ROM address under read-integrity check.
  (* anyconst *) logic [3:0] f_a1;
  (* anyconst *) logic [3:0] f_a2;
  (* anyconst *) logic [3:0] f_a3;
  (* anyconst *) logic [3:0] f_opr;
  (* anyconst *) logic [3:0] f_opa;
  (* anyconst *) logic [3:0] f_src;
  (* anyconst *) logic [3:0] f_wrr;

  logic [7:0]  fa_addr;
  logic [7:0]  fa_word;
  assign fa_addr = {f_a2, f_a1};
  assign fa_word = rom_flat[8*fa_addr +: 8];

  // ------------------------------------------------------------------
  // Environment assumptions
  // ------------------------------------------------------------------
  always @(posedge clk) begin
    if ($initstate) begin
      a_reset0: assume (!rst_n);
    end
    if (rst_n) begin
      a_sync: assume (sync == (phase == PhA1));
      a_cm_rom: assume (cm_rom == ((phase <= PhA3) ||
          (((phase == PhX2) || (phase == PhX3)) &&
           (opr_q == 4'he) &&
           ((opa_q == 4'h2) || (opa_q == 4'h3) || (opa_q == 4'ha)))));
      if (phase == PhA1) begin
        a_a1: assume (data_i == f_a1);
      end
      if (phase == PhA2) begin
        a_a2: assume (data_i == f_a2);
      end
      if (phase == PhA3) begin
        a_a3: assume (data_i == f_a3);
      end
      if (phase == PhM1) begin
        a_m1: assume (data_i == f_opr);
      end
      if (phase == PhM2) begin
        a_m2: assume (data_i == f_opa);
      end
      if ((phase == PhX2) && s_src) begin
        a_src: assume (data_i == f_src);
      end
      if ((phase == PhX3) && s_wrr) begin
        a_wrr: assume (data_i == f_wrr);
      end
    end
  end

  // ------------------------------------------------------------------
  // Safety properties. Guard: out of reset now and in the prior period.
  // ------------------------------------------------------------------
  logic g;

  always @(posedge clk) begin
    g = rst_n && !$initstate && $past(rst_n);
    // S1: drive-enable gating
    if (g) begin
      s1_oe_phases: assert (!data_oe || (phase == PhM1) || (phase == PhM2) ||
                            (phase == PhX2) || (phase == PhX3));
      s1_m_drive_sel: assert (!(data_oe && ((phase == PhM1) ||
                            (phase == PhM2))) || fetch_selected);
      s1_rdr_drive_sel: assert (!(data_oe && ((phase == PhX2) ||
                            (phase == PhX3))) ||
                            (s_rdr && io_selected));
    end

    // S2/S3: read-data integrity for the anyconst address/mask
    if (g && (phase == PhM1) && fetch_selected) begin
      s2_m1_hi: assert (data_o == fa_word[7:4]);
      s2_m1_oe: assert (data_oe);
    end
    if (g && (phase == PhM2) && fetch_selected) begin
      s3_m2_lo: assert (data_o == fa_word[3:0]);
      s3_m2_oe: assert (data_oe);
    end

    // S4: address latch assembly under CM-ROM
    if (g && $past(cm_rom && (phase == PhA1))) begin
      s4_lo: assert (addr_q[3:0] == $past(data_i));
    end
    if (g && $past(cm_rom && (phase == PhA2))) begin
      s4_hi: assert (addr_q[7:4] == $past(data_i));
    end

    // S5: A3 chip select and CM-ROM tracking
    if (g && $past(phase == PhA3)) begin
      s5_sel: assert (fetch_sel_q ==
                      ($past(cm_rom) && ($past(data_i) == CHIP_NO)));
      s5_cmrom_seen: assert (cm_rom_seen == $past(cm_rom));
    end

    // S6: SRC select register semantics (X2 capture; everything else —
    // including the X3 nibble of SRC itself — leaves it unchanged)
    if (g && $past((phase == PhX2) && s_src)) begin
      s6_capture: assert (io_sel_q == $past(data_i));
    end
    if (g && !$past((phase == PhX2) && s_src)) begin
      s6_only_x2: assert (io_sel_q == $past(io_sel_q));
    end

    // S7: WRR port-latch semantics (selected WRR at X3 writes — unless CL
    // is low at the same edge, which dominates as the clear of the I/O
    // flip-flops; CL clears; nothing else — including unselected WRR —
    // changes the latch)
    if (g && $past(clr_n && (phase == PhX3) && s_wrr && io_selected)) begin
      s7_capture: assert (port_q == $past(data_i));
    end
    if (g && $past(clr_n && !((phase == PhX3) && s_wrr && io_selected)))
    begin
      s7_only_wrr: assert (port_q == $past(port_q));
    end

    // S8: RDR drives the port read value; unselected RDR stays quiet
    if (g && (phase == PhX2 || phase == PhX3) && s_rdr) begin
      if (io_selected) begin
        s8_value: assert (data_o == ((IO_DIR & port_q) | (~IO_DIR & port_i)));
        s8_oe: assert (data_oe);
      end else begin
        s8_quiet: assert (!data_oe);
      end
    end

    // S9: reset dominance (RESET clears static flip-flops, inhibits data
    // out, and leaves the I/O latch alone)
    if (!$initstate && !$past(rst_n)) begin
      s9_phase: assert (phase == PhA1);
      s9_addr: assert (addr_q == 8'h0);
      s9_cmrom_seen: assert (!cm_rom_seen);
      s9_fetch_sel: assert (!fetch_sel_q);
      s9_opr: assert (opr_q == 4'h0);
      s9_opa: assert (opa_q == 4'h0);
      s9_io_sel: assert (io_sel_q == 4'h0);
      s9_quiet: assert (!data_oe);
      s9_port_kept: assert (port_q == $past(port_q));
    end

    // S10: CL clears only the I/O latch; the rest keeps running
    if (g && !$past(clr_n)) begin
      s10_clear: assert (port_q == 4'h0);
    end
    if (g && !$past(clr_n) && $past(phase == PhX1)) begin
      s10_rest_runs: assert ((phase == PhX2) && (addr_q == $past(addr_q)) &&
                             (io_sel_q == $past(io_sel_q)));
    end

    // S11: period counter follows the {sync, X3} rule
    if (g) begin
      s11_phase: assert (phase == ($past(sync) ? PhA2 :
                       (($past(phase) == PhX3) ? PhA1 :
                        $past(phase) + 3'd1)));
    end

    // S12: no M1/M2 drive without a CM-ROM-qualified chip match
    if (g && (phase == PhM1 || phase == PhM2) && !fetch_selected) begin
      s12_inhibited: assert (!data_oe);
    end
  end

endmodule
