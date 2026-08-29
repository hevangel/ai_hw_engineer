`timescale 1ns/1ps

// Formal cover set for the Intel 4003 reconstruction: 33 covers, one per
// documented behavior, proving non-vacuity of the assertion set. The cover
// task must PASS (every cover reachable within the depth bound). Covers are
// hand-written for the authentic WIDTH = 10 part.
module intel_4003_cover (
    input logic             clk,
    input logic             rst_n,
    input logic             cp_i,
    input logic             data_in_i,
    input logic             en_i,
    input logic [9:0]       q_o,
    input logic             so_o,
    input logic [9:0]       sr,
    input logic             cp_prev
);

  logic pulse;
  assign pulse = cp_i && !cp_prev;

  // Activity tracking
  integer pulses;            // CP pulses since reset release (saturated)
  logic   seen_pulse;        // at least one pulse since reset release
  logic   seen_pulse_d1;     // pulse on the previous cycle
  logic   seen_pulse_d2;     // pulse two cycles ago
  logic   sr_was_nonzero;    // register held non-zero data at some point
  logic   disabled_nonzero;  // outputs masked while register non-zero
  logic [2:0] hold_cnt;      // consecutive cycles with CP sampled high
  logic   din_d1;            // previous-cycle DATA IN
  logic   past_rst_n;        // rst_n delayed by one cycle

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      pulses           <= 32'd0;
      seen_pulse       <= 1'b0;
      seen_pulse_d1    <= 1'b0;
      seen_pulse_d2    <= 1'b0;
      sr_was_nonzero   <= 1'b0;
      disabled_nonzero <= 1'b0;
      hold_cnt         <= 3'd0;
      din_d1           <= 1'b0;
      past_rst_n       <= 1'b0;
    end else begin
      past_rst_n <= rst_n;
      seen_pulse_d1 <= pulse;
      seen_pulse_d2 <= seen_pulse_d1;
      din_d1        <= data_in_i;
      if (pulse) begin
        seen_pulse <= 1'b1;
        if (pulses < 32'd40) pulses <= pulses + 32'd1;
        if (sr != 10'b0) sr_was_nonzero <= 1'b1;
      end
      if (!en_i && sr != 10'b0) disabled_nonzero <= 1'b1;
      hold_cnt <= cp_i ? ((hold_cnt == 3'd7) ? 3'd7 : hold_cnt + 3'd1)
                       : 3'd0;
    end
  end

  // Guard: reset released for at least two full cycles
  logic g;
  always_comb begin
    g = rst_n && !$initstate && past_rst_n;
  end

  always @(posedge clk) begin
    // Start-up
    c_reset_released: cover (g);

    // Single-bit walk: exactly one asserted stage, per stage position
    c_stage_0: cover (g && sr == 10'b0000000001);
    c_stage_1: cover (g && sr == 10'b0000000010);
    c_stage_2: cover (g && sr == 10'b0000000100);
    c_stage_3: cover (g && sr == 10'b0000001000);
    c_stage_4: cover (g && sr == 10'b0000010000);
    c_stage_5: cover (g && sr == 10'b0000100000);
    c_stage_6: cover (g && sr == 10'b0001000000);
    c_stage_7: cover (g && sr == 10'b0010000000);
    c_stage_8: cover (g && sr == 10'b0100000000);
    c_stage_9: cover (g && sr == 10'b1000000000);

    // Fill patterns
    c_all_zeros:    cover (g && seen_pulse && sr == 10'b0000000000);
    c_all_ones:     cover (g && sr == 10'b1111111111);
    c_alt_01:       cover (g && sr == 10'b0101010101);
    c_alt_10:       cover (g && sr == 10'b1010101010);
    c_two_low_ones: cover (g && sr == 10'b0000000011);
    c_bookends:     cover (g && sr == 10'b1000000001);

    // Serial-out and parallel-output states
    c_so_high:           cover (g && so_o);
    c_so_high_disabled:  cover (g && so_o && !en_i);
    c_outputs_on:        cover (g && en_i && q_o != 10'b0);
    c_outputs_masked:    cover (g && !en_i && q_o == 10'b0 && sr != 10'b0);

    // Shift control: pulses in both enable states, held CP, pulse widths
    c_shift_disabled: cover (g && pulse && !en_i);
    c_shift_enabled:  cover (g && pulse && en_i);
    c_enable_rise:    cover (g && en_i && disabled_nonzero);
    c_pulse_w1:       cover (!$initstate && !cp_i && $past(cp_i) &&
                             $past(hold_cnt) == 3'd1);
    c_pulse_w3:       cover (!$initstate && !cp_i && $past(cp_i) &&
                             $past(hold_cnt) == 3'd3);
    c_cp_held_no_shift: cover (g && hold_cnt == 3'd3 && seen_pulse);
    c_back_to_back:   cover (pulse && !seen_pulse_d1 && seen_pulse_d2);

    // Data behavior
    c_din_change:  cover (g && pulse && seen_pulse && data_in_i != din_d1);
    c_pulses_10:   cover (g && pulses == 32'd10);
    c_so_fall:     cover (g && $past(so_o) && !so_o);

    // Reset interactions
    c_reset_mid_pulse:  cover (!rst_n && cp_i && !$initstate &&
                               seen_pulse && past_rst_n);
    c_reset_after_load: cover (!rst_n && !$initstate && sr_was_nonzero);
  end

endmodule
