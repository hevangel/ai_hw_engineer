// AMD Am29334 64x18 four-port dual-access register file, digital model.
//
// Source: AMD 1988 Am29C300/29300 Data Book, "Am29334 Four-Port
// Dual-Access Register File", Amendment 10 (PDF 201-215). The Am29434
// ECL member (preliminary, Issue 08554A, September 1986, PDF 216-229)
// documents the same function and shares this RTL; only its electrical
// layer differs (out of contract).
//
// The part is fully asynchronous: no clock pin. The RAM writes whenever
// the common and byte write enables are low; the on-chip read/write
// address multiplexer selects AWA/AWB during a write window (WEAC/WEBC
// low) and ARA/ARB otherwise, so a read of the location being written
// returns the value being written (datasheet page 3-79). Output latches
// YA/YB are transparent while LEA/LEB is high and hold otherwise, gated
// by OEA/OEB (active low). Writing one location from both sides is
// documented undefined-but-harmful; this model resolves it with the A
// side winning that cell (see spec ledger).
//
// Storage is two independent byte-lane arrays (low bits 8:0, high bits
// 17:9) instead of one word array: the datasheet's byte-merge writes
// would otherwise need a read-modify-write, whose read feeding the write
// latch forms a combinational loop under latch semantics.
module amd_am29334 (
  input  logic [5:0]  ara_i, awa_i, arb_i, awb_i,
  input  logic [17:0] da_i, db_i,
  output logic [17:0] ya_o, yb_o,
  output logic        ya_oe_o, yb_oe_o,
  input  logic        lea_i, leb_i,
  input  logic        oea_n_i, oeb_n_i,
  input  logic        wea_c_n_i, wea_l_n_i, wea_h_n_i,
  input  logic        web_c_n_i, web_l_n_i, web_h_n_i
`ifdef FORMAL
  , input logic fml_clk_i        // formal-only property timebase
`endif
);

  localparam int AW = 18;
  localparam int WORDS = 64;

  logic [8:0]  ram_l [0:WORDS-1];
  logic [8:0]  ram_h [0:WORDS-1];

  // Write enables: common plus per-byte, all active low.
  wire a_we_l = !wea_c_n_i && !wea_l_n_i;
  wire a_we_h = !wea_c_n_i && !wea_h_n_i;
  wire b_we_l = !web_c_n_i && !web_l_n_i;
  wire b_we_h = !web_c_n_i && !web_h_n_i;

  // Asynchronous writes: per-cell decoded latches. Each cell's data input
  // is a pure function of the pins, so the dual-port collision case
  // (both sides writing the same cell in one window, documented
  // undefined-but-harmful) resolves with the A side winning that cell
  // while the B side still writes every other cell (see spec ledger).
  // Structuring per cell avoids read-modify-write feedback between the
  // two sequenced writes of one latch memory.
  genvar g;
  generate
    for (g = 0; g < WORDS; g = g + 1) begin : g_cell
      always_latch begin
        if (a_we_l && awa_i == 6'(g))      ram_l[g] = da_i[8:0];
        else if (b_we_l && awb_i == 6'(g)) ram_l[g] = db_i[8:0];
      end
      always_latch begin
        if (a_we_h && awa_i == 6'(g))      ram_h[g] = da_i[17:9];
        else if (b_we_h && awb_i == 6'(g)) ram_h[g] = db_i[17:9];
      end
    end
  endgenerate

  // Read/write address multiplexer: write address during the write
  // window, read address otherwise (datasheet functional description).
  wire [5:0] rama = wea_c_n_i ? ara_i : awa_i;
  wire [5:0] ramb = web_c_n_i ? arb_i : awb_i;
  wire [AW-1:0] ram_qa = {ram_h[rama], ram_l[rama]};
  wire [AW-1:0] ram_qb = {ram_h[ramb], ram_l[ramb]};

  // Output data latches: transparent while LE high, holding otherwise.
  logic [AW-1:0] ya_q, yb_q;
  always_latch begin
    if (lea_i) ya_q = ram_qa;
    if (leb_i) yb_q = ram_qb;
  end

  assign ya_oe_o = !oea_n_i;
  assign yb_oe_o = !oeb_n_i;
  assign ya_o = ya_q;
  assign yb_o = yb_q;

`ifdef FORMAL
  `include "amd_am29334_props.sv"
`endif
endmodule
