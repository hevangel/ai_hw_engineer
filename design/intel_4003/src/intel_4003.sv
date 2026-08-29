`timescale 1ns/1ps

// Intel 4003 I/O expander: synchronous, synthesizable functional
// reconstruction. See spec/spec.md for the complete behavioral contract.
//
// The historical part is a 10-bit static serial-in / parallel-out /
// serial-out shift register with enable-gated parallel outputs, cascading
// in multiples of ten via its serial output. It has no bus pins: a program
// stretches a 4001/4002 I/O port by wiring port lines to DATA IN, CP and
// ENABLE. CP is an independent pulse input (the part uses neither the
// MCS-4 two-phase clocks nor SYNC); this core samples CP on `clk` and
// commits exactly one shift per CP rising edge, which reproduces the
// datasheet contract that DATA IN may change simultaneously with CP (the
// real part delays CP internally; the synchronous model samples at the
// edge ending the first CP-high clock period).
//
// `rst_n` (synchronous, active-low) and `clk` are reconstruction additions
// standing in for the historical internal power-on-clear and its free
// running nature; reset clears the register and CP history.
module intel_4003 #(
    parameter int WIDTH = 10  // authentic part is 10 (spec section 9)
) (
    input  logic             clk,
    input  logic             rst_n,

    // Historical CP pin: shift clock pulse (one shift per rising edge)
    input  logic             cp_i,
    // Historical DATA IN pin: serial input, enters stage 0
    input  logic             data_in_i,
    // Historical ENABLE pin (MCS-4 logic convention: asserted = outputs on)
    input  logic             en_i,

    // Historical Q0-Q9 pins: q_o[i] mirrors register stage i
    output logic [WIDTH-1:0] q_o,
    // Historical SERIAL OUT pin: last stage, unaffected by the enable
    output logic             so_o
);

  // Shift register state: sr[0] is nearest DATA IN, sr[WIDTH-1] feeds
  // SERIAL OUT. cp_prev is the registered previous CP sample used for
  // synchronous rising-edge detection (spec section 6.2).
  logic [WIDTH-1:0] sr;
  logic             cp_prev;

  // Exactly one shift request per CP pulse; a CP line held high by a port
  // latch never re-triggers (spec section 6.2).
  logic shift_pulse;
  assign shift_pulse = cp_i && !cp_prev;

  // Next-value computed as a single assignment: each state element is
  // written exactly once per clock (xezim first-write-wins NBA semantics).
  logic [WIDTH-1:0] sr_next;
  always_comb begin
    if (shift_pulse) begin
      sr_next = {sr[WIDTH-2:0], data_in_i};
    end else begin
      sr_next = sr;
    end
  end

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      // Synchronous reset standing in for the historical power-on-clear
      // (spec section 8).
      sr      <= '0;
      cp_prev <= 1'b0;
    end else begin
      sr      <= sr_next;
      cp_prev <= cp_i;
    end
  end

  // Parallel outputs are gated by the enable only; the register keeps
  // shifting while disabled (spec section 6.4).
  always_comb begin
    if (en_i) begin
      q_o = sr;
    end else begin
      q_o = '0;
    end
  end

  // Serial output tracks the last stage regardless of the enable
  // (spec section 6.4).
  assign so_o = sr[WIDTH-1];

`ifdef FORMAL
  // Structural safety (main properties live in formal/intel_4003_props.sv).
  // The initstate assumption gives every formal task (including cover) a
  // defined starting point: reset is active in cycle 0, so all state is
  // cleared from the first edge onward.
  always @(posedge clk) begin
    if ($initstate) begin
      a_start_in_reset: assume (!rst_n);
    end
    if (rst_n && !$initstate) begin
      a_shift_gated:   assert (!shift_pulse || !cp_prev);
      a_so_tracks:     assert (so_o == sr[WIDTH-1]);
      a_q_gated:       assert (en_i || q_o == '0);
    end
  end

`ifdef FORMAL_COVER
  intel_4003_cover formal_coverage (
      .clk       (clk),
      .rst_n     (rst_n),
      .cp_i      (cp_i),
      .data_in_i (data_in_i),
      .en_i      (en_i),
      .q_o       (q_o),
      .so_o      (so_o),
      .sr        (sr),
      .cp_prev   (cp_prev)
  );
`else
  intel_4003_props formal_properties (
      .clk       (clk),
      .rst_n     (rst_n),
      .cp_i      (cp_i),
      .data_in_i (data_in_i),
      .en_i      (en_i),
      .q_o       (q_o),
      .so_o      (so_o),
      .sr        (sr),
      .cp_prev   (cp_prev),
      .shift_pulse (shift_pulse)
  );
`endif
`endif

endmodule
