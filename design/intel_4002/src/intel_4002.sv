`timescale 1ns/1ps

// Intel 4002: 320-bit RAM and 4-bit output port of the MCS-4 family.
// Synchronous, synthesizable functional reconstruction. See spec/spec.md
// for the complete behavioral contract. The chip tracks the CPU's 8-period
// instruction cycle (A1 A2 A3 M1 M2 X1 X2 X3) from the SYNC pulse, learns
// every command by listening to the instruction word on the shared bus at
// M1/M2 (as the historical 4002s do), loads the SRC select code at X2/X3,
// captures write data at the edge ending X3, and drives read data during
// X2/X3 — the exact protocol of this repository's verified intel_4004 core.
//
// Storage: 4 registers x 16 main-memory characters x 4 bits plus 4 registers
// x 4 status characters x 4 bits, and one 4-bit latched output port (WMP).
// Chip selection: this chip's CM-RAM bank line (cm_ram_i) must be asserted
// and the chip number in the SRC select code must match the number formed by
// the 4002-1/4002-2 metal-option parameter (Variant1) and the P0 strap pin
// (po_i): 4002-1 answers chip numbers {0, po_i}, 4002-2 answers {1, po_i}.
module intel_4002 #(
    parameter Variant1 = 1'b1  // 1: 4002-1 (chip numbers 0,1); 0: 4002-2 (2,3)
) (
    input  logic       clk,
    input  logic       rst_n,

    // Multiplexed 4-bit data bus, split into input/output/output-enable
    input  logic [3:0] data_i,
    output logic [3:0] data_o,
    output logic       data_oe,

    // CPU command lines
    input  logic       sync,      // historical SYNC: high during A1
    input  logic       cm_ram_i,  // this chip's CM-RAM bank command line

    // Historical P0 chip-number strap pin (0 = GND, 1 = Vdd)
    input  logic       po_i,

    // 4-bit latched output port (historical I/O0-I/O3 pins)
    output logic [3:0] io_o
);

  // Phase encoding: one instruction cycle = A1 A2 A3 M1 M2 X1 X2 X3
  localparam logic [2:0] PhA1 = 3'd0;
  localparam logic [2:0] PhA2 = 3'd1;
  localparam logic [2:0] PhA3 = 3'd2;
  localparam logic [2:0] PhM1 = 3'd3;
  localparam logic [2:0] PhM2 = 3'd4;
  localparam logic [2:0] PhX1 = 3'd5;
  localparam logic [2:0] PhX2 = 3'd6;
  localparam logic [2:0] PhX3 = 3'd7;

  // OPR groups and the OPA encodings of the I/O and RAM instruction set
  localparam logic [3:0] OprSrc    = 4'h2;  // 0010 RRR1
  localparam logic [3:0] OprIo    = 4'he;  // 1110 OPA
  localparam logic [3:0] OpaWrm   = 4'h0;
  localparam logic [3:0] OpaWmp   = 4'h1;
  localparam logic [3:0] OpaWrr   = 4'h2;  // ROM-side: ignored by this chip
  localparam logic [3:0] OpaWpm   = 4'h3;  // ROM-side: ignored by this chip
  localparam logic [3:0] OpaWr0   = 4'h4;
  localparam logic [3:0] OpaSbm   = 4'h8;
  localparam logic [3:0] OpaRdm   = 4'h9;
  localparam logic [3:0] OpaRdr   = 4'ha;  // ROM-side: ignored by this chip
  localparam logic [3:0] OpaAdm   = 4'hb;
  localparam logic [3:0] OpaRd0   = 4'hc;

  // Architectural state
  logic [2:0]  phase;                 // instruction-cycle phase counter
  logic [3:0]  cmd_opr;               // OPR latched at M1
  logic [3:0]  cmd_opa;               // OPA latched at M2
  logic [7:0]  addr;                  // SRC select code: [7:6] chip,
                                      // [5:4] register, [3:0] character
  logic [3:0]  out_port;              // WMP output latch
  logic [3:0]  main_mem [0:63];       // 4 registers x 16 characters
  logic [3:0]  stat_mem [0:15];       // 4 registers x 4 status characters

  // Sequential state. All state elements live in ONE clocked block so that
  // every condition samples pre-edge values consistently (multiple clocked
  // blocks reading each other's registered outputs are ordering-sensitive
  // on some event-driven simulators). Each storage element is written by at
  // most one assignment per clock.
  always_ff @(posedge clk) begin
    if (!rst_n) begin
      phase    <= PhA1;
      cmd_opr  <= 4'h0;
      cmd_opa  <= 4'h0;
      addr     <= 8'h0;
      out_port <= 4'h0;
      for (integer i = 0; i < 64; i = i + 1) begin
        main_mem[i] <= 4'h0;
      end
      for (integer j = 0; j < 16; j = j + 1) begin
        stat_mem[j] <= 4'h0;
      end
    end else begin
      // Phase sequencing: restart on SYNC so phase 0 is always A1
      if (sync) begin
        phase <= PhA2;  // edge ending A1: sync seen, next period is A2
      end else begin
        phase <= phase + 3'd1;
      end

      // Command decode (spec 5.2): all chips hear the instruction at M1/M2.
      if (phase == PhM1) begin
        cmd_opr <= data_i;
      end
      if (phase == PhM2) begin
        cmd_opa <= data_i;
      end

      // SRC select code: chip+register nibble at X2, character at X3.
      // Every chip on the active bank line loads its address register;
      // the chip number only gates the response, not the load (spec 9.4).
      if (is_src && cm_ram_i && phase == PhX2) begin
        addr <= {data_i, addr[3:0]};
      end
      if (is_src && cm_ram_i && phase == PhX3) begin
        addr <= {addr[7:4], data_i};
      end

      // Write commands commit at the edge ending X3 (spec 5.3)
      if (phase == PhX3 && selected) begin
        if (is_write && cmd_opa == OpaWrm) begin
          main_mem[main_ix] <= data_i;
        end
        if (is_write && cmd_opa == OpaWmp) begin
          out_port <= data_i;
        end
        if (is_write && cmd_opa >= OpaWr0 && cmd_opa <= 4'h7) begin
          stat_mem[stat_ix] <= data_i;
        end
      end
    end
  end

  // Instruction classification, valid from X1 of the latched cycle onward
  logic is_src;        // SRC 0010 RRR1
  logic is_io;         // OPR = 1110 (I/O and RAM group)
  logic is_4002_op;    // not one of the ROM-side encodings WRR/WPM/RDR
  logic is_write;      // WRM, WMP, WR0-WR3
  logic is_read;       // SBM, RDM, ADM, RD0-RD3
  assign is_src     = (cmd_opr == OprSrc) && cmd_opa[0];
  assign is_io      = (cmd_opr == OprIo);
  assign is_4002_op = (cmd_opa != OpaWrr) && (cmd_opa != OpaWpm) &&
                      (cmd_opa != OpaRdr);
  assign is_write   = is_io && is_4002_op && !cmd_opa[3];
  assign is_read    = is_io && is_4002_op && cmd_opa[3];

  // Chip selection (spec 6): bank line active AND chip number matches the
  // number hardwired by the metal option and the P0 strap.
  logic [1:0] my_chip;
  logic       selected;
  assign my_chip  = {Variant1 ? 1'b0 : 1'b1, po_i};
  assign selected = cm_ram_i && (addr[7:6] == my_chip);

  // Selected storage position
  logic [5:0] main_ix;   // {register, character}
  logic [3:0] stat_ix;   // {register, status character}
  assign main_ix = {addr[5:4], addr[3:0]};
  assign stat_ix = {addr[5:4], cmd_opa[1:0]};

  // Read-data multiplexer (combinational; driven during X2/X3 only)
  always_comb begin
    data_o  = 4'h0;
    data_oe = 1'b0;
    if ((phase == PhX2 || phase == PhX3) && is_read && selected) begin
      data_oe = 1'b1;
      if (cmd_opa == OpaSbm || cmd_opa == OpaRdm || cmd_opa == OpaAdm) begin
        data_o = main_mem[main_ix];
      end else begin  // RD0-RD3
        data_o = stat_mem[stat_ix];
      end
    end
  end

  assign io_o = out_port;

`ifdef FORMAL
  // Formal state initialization: yosys records `initial` assignments as init
  // attributes, so the solver starts from a known state instead of free
  // constants (free base arrays make SMT-array reasoning over the storage
  // pathologically slow). Guarded out of synthesis; the synchronous reset
  // clears the same state one cycle later regardless.
  initial begin
    phase    = PhA1;
    cmd_opr  = 4'h0;
    cmd_opa  = 4'h0;
    addr     = 8'h0;
    out_port = 4'h0;
    for (integer i = 0; i < 64; i = i + 1) begin
      main_mem[i] = 4'h0;
    end
    for (integer j = 0; j < 16; j = j + 1) begin
      stat_mem[j] = 4'h0;
    end
  end

  // Flattened storage views for the formal property modules
  logic [255:0] main_flat;
  logic [63:0]  stat_flat;
  always_comb begin
    for (integer k = 0; k < 64; k = k + 1) begin
      main_flat[k*4 +: 4] = main_mem[k];
    end
    for (integer m = 0; m < 16; m = m + 1) begin
      stat_flat[m*4 +: 4] = stat_mem[m];
    end
  end

  // Structural safety (main properties live in formal/intel_4002_props.sv)
  always @(posedge clk) begin
    if (rst_n && !$initstate) begin
      a_phase_range: assert (phase <= PhX3);
      a_no_drive_outside_x: assert (!data_oe ||
                                    phase == PhX2 || phase == PhX3);
    end
  end

`ifdef FORMAL_COVER
  intel_4002_cover #(
      .ChipMsb (Variant1 ? 1'b0 : 1'b1)
  ) formal_coverage (
      .clk       (clk),
      .rst_n     (rst_n),
      .data_i    (data_i),
      .data_o    (data_o),
      .data_oe   (data_oe),
      .sync      (sync),
      .cm_ram_i  (cm_ram_i),
      .po_i      (po_i),
      .io_o      (io_o),
      .phase     (phase),
      .cmd_opr   (cmd_opr),
      .cmd_opa   (cmd_opa),
      .addr      (addr),
      .out_port  (out_port),
      .selected  (selected),
      .main_flat (main_flat),
      .stat_flat (stat_flat)
  );
`else
  intel_4002_props #(
      .ChipMsb (Variant1 ? 1'b0 : 1'b1)
  ) formal_properties (
      .clk       (clk),
      .rst_n     (rst_n),
      .data_i    (data_i),
      .data_o    (data_o),
      .data_oe   (data_oe),
      .sync      (sync),
      .cm_ram_i  (cm_ram_i),
      .po_i      (po_i),
      .io_o      (io_o),
      .phase     (phase),
      .cmd_opr   (cmd_opr),
      .cmd_opa   (cmd_opa),
      .addr      (addr),
      .out_port  (out_port),
      .selected  (selected),
      .main_flat (main_flat),
      .stat_flat (stat_flat)
  );
`endif
`endif

  // Intentionally unused phase and encodings: X1 carries no dedicated
  // behavior, and WRR/WPM/RDR are decoded only to be excluded.
  logic _unused;
  assign _unused = &{1'b0, PhA2, PhA3, PhX1, OpaWrr, OpaWpm, OpaRdr, OpaRd0};

endmodule
