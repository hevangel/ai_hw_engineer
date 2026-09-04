`timescale 1ns/1ps

// Intel 4001: 2048-bit (256 x 8) mask-programmable ROM with a 4-bit I/O
// port, the program-memory and peripheral-I/O chip of the Intel MCS-4
// microcomputer set. See spec/spec.md for the complete behavioral contract.
//
// The historical part shares the 4-bit D0-D3 bus and the CM-ROM command
// line with up to sixteen siblings, each identified by a metal-option chip
// number, and runs from the CPU's SYNC-punctuated eight-period instruction
// cycle (A1 A2 A3 M1 M2 X1 X2 X3). This reconstruction takes one `clk`
// whose every rising edge ends one historical clock period, keeps its own
// phase counter locked to `sync`, and decomposes the bus into data_i /
// data_o / data_oe per repository convention. The historical RESET and CL
// pins become synchronous active-low `rst_n` and `clr_n`; per the MCS-4
// Users Manual they have distinct jobs: RESET clears the static flip-flops
// and inhibits data out, while CL clears only the I/O output flip-flops.
// The mask-programmed ROM contents load from a hex file named by the
// ROM_FILE parameter (one 8-bit word per line, 256 lines, address order);
// the per-pin I/O direction metal option (IO_DIR) is a parameter.
module intel_4001 #(
    // Metal mask options (ordering options 1 and 2 of the manual)
    parameter logic [3:0]    CHIP_NO = 4'h0,   // chip number 0-15
    parameter logic [3:0]    IO_DIR  = 4'b1111, // per-pin 1 = output, 0 = input
    // Mask-programmed contents, loaded from this hex file ($readmemh,
    // one 8-bit word per line in address order). Default: word(a) =
    // (37*a + 61) mod 256, a fixed bijective pattern chosen so every
    // address is distinguishable in verification. The path resolves
    // against the simulator's working directory.
    parameter                ROM_FILE = "src/rom_4001_default.hex"
) (
    input  logic       clk,
    input  logic       rst_n,   // historical RESET pin (synchronous model)
    input  logic       clr_n,   // historical CL pin: clears I/O latch only
    input  logic [3:0] data_i,  // bus nibble driven by the CPU
    output logic [3:0] data_o,  // bus nibble driven by this chip
    output logic       data_oe, // 1 while this chip drives the bus
    input  logic       sync,    // CPU SYNC: 1 during A1 of every cycle
    input  logic       cm_rom,  // ROM command line
    input  logic [3:0] port_i,  // external I/O pin inputs
    output logic [3:0] port_o,  // external I/O pin output values
    output logic [3:0] port_oe  // per-pin output enable = IO_DIR
);

  // Instruction-cycle period encoding, matching the CPU reconstruction
  localparam logic [2:0] PhA1 = 3'd0;
  localparam logic [2:0] PhA2 = 3'd1;
  localparam logic [2:0] PhA3 = 3'd2;
  localparam logic [2:0] PhM1 = 3'd3;
  localparam logic [2:0] PhM2 = 3'd4;
  localparam logic [2:0] PhX1 = 3'd5;
  localparam logic [2:0] PhX2 = 3'd6;
  localparam logic [2:0] PhX3 = 3'd7;

  // ------------------------------------------------------------------
  // State
  // ------------------------------------------------------------------
  logic [2:0] phase;        // instruction-cycle period counter
  logic [7:0] addr_q;       // latched word address (A1 low, A2 high nibble)
  logic       cm_rom_seen;  // CM-ROM sampled at the A3 edge
  logic       fetch_sel_q;  // A3 chip number matched CHIP_NO
  logic [3:0] opr_q;        // snooped fetch: opcode high nibble (M1)
  logic [3:0] opa_q;        // snooped fetch: operand low nibble (M2)
  logic [3:0] io_sel_q;     // SRC X2 select nibble (ROM-port chip number)
  logic [3:0] port_q;       // I/O output latch (cleared by CL, not RESET)

  // ------------------------------------------------------------------
  // Mask contents: a hex file in simulation/synthesis, a free constant
  // under formal so proofs cover every possible mask pattern.
  // ------------------------------------------------------------------
`ifdef FORMAL
  (* anyconst *) logic [2047:0] rom_mask;
  logic [2047:0] rom_flat;
  assign rom_flat = rom_mask;

  logic [7:0] rom_word;
  assign rom_word = rom_flat[8*addr_q +: 8];
`else
  logic [7:0] rom_mem [0:255];
  initial begin
      $readmemh(ROM_FILE, rom_mem);
  end

  logic [7:0] rom_word;
  assign rom_word = rom_mem[addr_q];
`endif

  // ------------------------------------------------------------------
  // Snooped opcode decode: every chip hears every fetch on the shared bus
  // ------------------------------------------------------------------
  logic s_src;  // SRC  0010 RRR1: X2 nibble selects the ROM port chip
  logic s_wrr;  // WRR  1110 0010: write ROM port
  logic s_rdr;  // RDR  1110 1010: read ROM port
  logic s_wpm;  // WPM  1110 0011: program-memory write (4008/4009; ignored)
  assign s_src = (opr_q == 4'h2) && opa_q[0];
  assign s_wrr = (opr_q == 4'he) && (opa_q == 4'h2);
  assign s_rdr = (opr_q == 4'he) && (opa_q == 4'ha);
  assign s_wpm = (opr_q == 4'he) && (opa_q == 4'h3);

  // ------------------------------------------------------------------
  // Selection and port read value
  // ------------------------------------------------------------------
  logic fetch_selected;
  logic io_selected;
  logic [3:0] rdr_value;
  assign fetch_selected = fetch_sel_q && cm_rom_seen;
  assign io_selected    = (io_sel_q == CHIP_NO);
  assign rdr_value      = (IO_DIR & port_q) | (~IO_DIR & port_i);

  // ------------------------------------------------------------------
  // Bus output multiplexing (spec 7.4)
  // ------------------------------------------------------------------
  always_comb begin
    data_o  = 4'h0;
    data_oe = 1'b0;
    if (fetch_selected && (phase == PhM1)) begin
      data_o  = rom_word[7:4];
      data_oe = 1'b1;
    end else if (fetch_selected && (phase == PhM2)) begin
      data_o  = rom_word[3:0];
      data_oe = 1'b1;
    end else if (io_selected && s_rdr &&
                 ((phase == PhX2) || (phase == PhX3))) begin
      data_o  = rdr_value;
      data_oe = 1'b1;
    end
  end

  // I/O pin outputs: the latch behind a per-pin direction gate
  assign port_o  = port_q;
  assign port_oe = IO_DIR;

  // ------------------------------------------------------------------
  // Sequencer and state update. Every register is written at most once
  // per clock edge (single commit paths; no default-then-override).
  // ------------------------------------------------------------------
  always_ff @(posedge clk) begin
    if (!rst_n) begin
      // RESET: clear static flip-flops, inhibit data out (phase back to
      // A1 keeps the counter aligned with the CPU's reset state). The
      // I/O output latch is deliberately not cleared here: on the real
      // part that is the separate CL pin's function.
      phase       <= PhA1;
      addr_q      <= 8'h0;
      cm_rom_seen <= 1'b0;
      fetch_sel_q <= 1'b0;
      opr_q       <= 4'h0;
      opa_q       <= 4'h0;
      io_sel_q    <= 4'h0;
    end else begin
      // Period counter: `sync` marks A1, so the period after a sync
      // period is A2; this re-locks the chip to the CPU every cycle.
      if (sync) begin
        phase <= PhA2;
      end else if (phase == PhX3) begin
        phase <= PhA1;
      end else begin
        phase <= phase + 3'd1;
      end

      // Address / chip-number latch under CM-ROM (spec 4.1)
      if (cm_rom) begin
        if (phase == PhA1) begin
          addr_q[3:0] <= data_i;
        end else if (phase == PhA2) begin
          addr_q[7:4] <= data_i;
        end else if (phase == PhA3) begin
          fetch_sel_q <= (data_i == CHIP_NO);
          cm_rom_seen <= 1'b1;
        end
      end else if (phase == PhA3) begin
        // No CM-ROM at A3: no chip may respond in M1/M2 ("inhibit
        // data out").
        fetch_sel_q <= 1'b0;
        cm_rom_seen <= 1'b0;
      end

      // Opcode snoop of the fetched word (all chips hear all fetches)
      if (phase == PhM1) begin
        opr_q <= data_i;
      end
      if (phase == PhM2) begin
        opa_q <= data_i;
      end

      // SRC: capture the X2 select nibble; X3 data is ignored (spec 5.2)
      if ((phase == PhX2) && s_src) begin
        io_sel_q <= data_i;
      end

      // I/O output latch: CL clears it; WRR writes it at the edge ending
      // X3 (the CPU holds the same value through X2 and X3). RESET does
      // not reach this latch.
      if (!clr_n) begin
        port_q <= 4'h0;
      end else if ((phase == PhX3) && s_wrr && io_selected) begin
        port_q <= data_i;
      end
    end
  end

`ifdef FORMAL
  // Structural safety invariants; the full property set lives in
  // formal/intel_4001_props.sv (instantiated below).
  always @(posedge clk) begin
    if (rst_n) begin
      a_phase_range: assert (phase <= PhX3);
      a_oe_phases: assert (!data_oe || (phase == PhM1) || (phase == PhM2) ||
                           (phase == PhX2) || (phase == PhX3));
      a_port_out: assert ((port_o == port_q) && (port_oe == IO_DIR));
    end
  end

`ifdef FORMAL_COVER
  intel_4001_cover formal_coverage (
      .clk          (clk),
      .rst_n        (rst_n),
      .clr_n        (clr_n),
      .data_i       (data_i),
      .data_o       (data_o),
      .data_oe      (data_oe),
      .sync         (sync),
      .cm_rom       (cm_rom),
      .port_i       (port_i),
      .phase        (phase),
      .addr_q       (addr_q),
      .cm_rom_seen  (cm_rom_seen),
      .fetch_sel_q  (fetch_sel_q),
      .opr_q        (opr_q),
      .opa_q        (opa_q),
      .io_sel_q     (io_sel_q),
      .port_q       (port_q),
      .rom_word     (rom_word),
      .fetch_selected (fetch_selected),
      .io_selected  (io_selected),
      .s_src        (s_src),
      .s_wrr        (s_wrr),
      .s_rdr        (s_rdr),
      .s_wpm        (s_wpm),
      .CHIP_NO      (CHIP_NO),
      .IO_DIR       (IO_DIR)
  );
`else
  intel_4001_props formal_properties (
      .clk          (clk),
      .rst_n        (rst_n),
      .clr_n        (clr_n),
      .data_i       (data_i),
      .data_o       (data_o),
      .data_oe      (data_oe),
      .sync         (sync),
      .cm_rom       (cm_rom),
      .port_i       (port_i),
      .phase        (phase),
      .addr_q       (addr_q),
      .cm_rom_seen  (cm_rom_seen),
      .fetch_sel_q  (fetch_sel_q),
      .opr_q        (opr_q),
      .opa_q        (opa_q),
      .io_sel_q     (io_sel_q),
      .port_q       (port_q),
      .rom_flat     (rom_flat),
      .fetch_selected (fetch_selected),
      .io_selected  (io_selected),
      .s_src        (s_src),
      .s_wrr        (s_wrr),
      .s_rdr        (s_rdr),
      .s_wpm        (s_wpm),
      .CHIP_NO      (CHIP_NO),
      .IO_DIR       (IO_DIR)
  );
`endif
`endif

  // Intentionally unused: the WPM decode is recognized but, as on the real
  // part, produces no 4001 response, and X1 carries no dedicated behavior.
  logic _unused;
  assign _unused = &{1'b0, s_wpm, PhX1};

endmodule
