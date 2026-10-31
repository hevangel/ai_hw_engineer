`timescale 1ns/1ps
/* verilator lint_off BLKSEQ */

// Self-checking testbench for the Intel 4003 reconstruction (no UVM).
//
// The bench is a miniature MCS-4 system: a behavioral CPU-side bus master
// drives genuine 8-phase instruction cycles (SYNC during A1, cm_rom during
// A1-A3, port data and command strobes during X2/X3, address nibbles on the
// bus during A1-A3), exactly per the intel_4004 spec section 6. A port
// model - standing in for a 4001 ROM I/O port / 4002 RAM output port -
// derives its internal phase from SYNC like the real chips do, and latches
// the WRR/WMP nibble at the edge ending X3. Its four output lines wire to
// two chained 4003s (bit 0 -> CP of both, bit 1 -> DATA IN of DUT1, bit 2
// -> ENABLE of both, DUT1 SERIAL OUT -> DUT2 DATA IN), the canonical MCS-4
// expander wiring (spec section 3.3).
//
// An independently formulated 20-bit golden shift chain is compared against
// both devices at every settled clock edge, and directed scenarios exercise
// full/partial loads in both bit orders, CP pulse shaping (held-high lines,
// simultaneous DATA IN + CP), cascade transit, enable gating, and reset
// mid-load, followed by a LFSR-driven random phase.

module tb_intel_4003;

  // ------------------------------------------------------------------
  // Clock and reset
  // ------------------------------------------------------------------
  logic clk;
  logic rst_n = 1'b0;

  initial begin
    clk = 1'b0;
  end
  always #5 clk = ~clk;

  // ------------------------------------------------------------------
  // Counters and result tracking
  // ------------------------------------------------------------------
  integer cycle_count;
  integer check_count;
  integer failure_count;

  task automatic dir_check(input logic ok, input string label);
    begin
      check_count = check_count + 1;
      if (ok !== 1'b1) begin
        failure_count = failure_count + 1;
        $display("FAIL @%0t: %s", $time, label);
      end
    end
  endtask

  // ------------------------------------------------------------------
  // CPU-side bus master: drives one 8-phase instruction cycle per
  // cpu_cycle() call (A1 A2 A3 M1 M2 X1 X2 X3). Address nibbles go on
  // the bus during A1-A3 with cm_rom; port writes drive the nibble and
  // the command line during X2 and X3.
  // ------------------------------------------------------------------
  logic [11:0] cpu_pc;

  // Bus driven by the master (set at negedges, stable across the posedge)
  logic       bus_sync;
  logic       bus_cm_rom;
  logic [3:0] bus_cm_ram;
  logic [3:0] bus_data;
  logic       bus_oe;

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      cpu_pc <= 12'h0;
    end else if (bus_sync) begin
      cpu_pc <= cpu_pc + 12'd1;   // increment at the end of every A1
    end
  end

  task automatic cpu_cycle(input logic [3:0] nibble, input logic rom_port,
                           input logic valid);
    integer ph;
    begin
      for (ph = 0; ph < 8; ph++) begin
        @(negedge clk);
        bus_sync   = (ph == 0);
        bus_cm_rom = (ph <= 2) || (valid && rom_port && (ph >= 6));
        bus_cm_ram = (valid && !rom_port && (ph >= 6)) ? 4'b0001 : 4'b0000;
        bus_oe     = (ph <= 2) || (valid && (ph >= 6));
        bus_data   = (ph == 0) ? cpu_pc[3:0]  :
                     (ph == 1) ? cpu_pc[7:4]  :
                     (ph == 2) ? cpu_pc[11:8] : nibble;
      end
      @(posedge clk);   // X3 ends here: the port latch fires
      bus_oe     = 1'b0;
      bus_cm_rom = 1'b0;
      bus_cm_ram = 4'b0000;
      bus_sync   = 1'b0;
      bus_data   = 4'h0;
    end
  endtask

  task automatic idle_cycle;
    begin
      cpu_cycle(4'h0, 1'b0, 1'b0);
    end
  endtask

  // ------------------------------------------------------------------
  // Port model (4001 ROM I/O port / 4002 RAM output port). Internal
  // phase comes from SYNC, as on the real chips: port_phase counts 0-7
  // with value 6 during X3, so the nibble is latched at the edge ending
  // X3 of a strobed cycle (intel_4004 spec section 6.3).
  // ------------------------------------------------------------------
  logic [2:0] port_phase;

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      port_phase <= 3'd0;
    end else begin
      port_phase <= bus_sync ? 3'd0 : port_phase + 3'd1;
    end
  end

  /* verilator lint_off UNUSEDSIGNAL */
  logic [3:0] port0_q;  // ROM port 0: bit0 CP, bit1 DATA IN, bit2 ENABLE
  logic [3:0] port1_q;  // RAM output port: written but unwired on this
                        // board; kept for port-model completeness
  /* verilator lint_on UNUSEDSIGNAL */

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      port0_q <= 4'h0;
      port1_q <= 4'h0;
    end else if ((port_phase == 3'd6) && bus_oe && bus_cm_rom) begin
      port0_q <= bus_data;              // WRR -> ROM I/O port
    end else if ((port_phase == 3'd6) && bus_oe &&
                 (bus_cm_ram != 4'b0000)) begin
      port1_q <= bus_data;              // WMP -> RAM output port
    end
  end

  // ------------------------------------------------------------------
  // Device under test: two chained 4003s on ROM port 0
  // ------------------------------------------------------------------
  logic cp_bit;
  logic din_bit;
  logic en_bit;

  assign cp_bit  = port0_q[0];
  assign din_bit = port0_q[1];
  assign en_bit  = port0_q[2];

  logic [9:0] q1;
  logic [9:0] q2;
  logic       so1;
  logic       so2;

  intel_4003 dut1 (
      .clk      (clk),
      .rst_n    (rst_n),
      .cp_i     (cp_bit),
      .data_in_i(din_bit),
      .en_i     (en_bit),
      .q_o      (q1),
      .so_o     (so1)
  );

  intel_4003 dut2 (
      .clk      (clk),
      .rst_n    (rst_n),
      .cp_i     (cp_bit),
      .data_in_i(so1),      // cascade: SERIAL OUT -> DATA IN
      .en_i     (en_bit),
      .q_o      (q2),
      .so_o     (so2)
  );

  // ------------------------------------------------------------------
  // Golden model: one 20-bit chain covering both devices, formulated
  // differently from the RTL (vector shift-by-one instead of stage
  // concatenation).
  // ------------------------------------------------------------------
  logic [19:0] golden;
  logic        golden_cp_prev;

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      golden         <= 20'b00000000000000000000;
      golden_cp_prev <= 1'b0;
    end else begin
      golden_cp_prev <= cp_bit;
      if (cp_bit && !golden_cp_prev) begin
        golden <= {golden[18:0], din_bit};
      end
    end
  end

  // ------------------------------------------------------------------
  // Continuous scoreboard: settled-edge comparison of every output
  // ------------------------------------------------------------------
  always @(negedge clk) begin
    if (rst_n) begin
      check_count = check_count + 4;
      if (q1 !== (en_bit ? golden[9:0] : 10'b0000000000)) begin
        failure_count = failure_count + 1;
        $display("FAIL @%0t: DUT1 q=%h expected %h (en=%b golden=%h)",
                 $time, q1, en_bit ? golden[9:0] : 10'b0, en_bit, golden);
      end
      if (so1 !== golden[9]) begin
        failure_count = failure_count + 1;
        $display("FAIL @%0t: DUT1 so=%b expected %b (golden=%h)",
                 $time, so1, golden[9], golden);
      end
      if (q2 !== (en_bit ? golden[19:10] : 10'b0000000000)) begin
        failure_count = failure_count + 1;
        $display("FAIL @%0t: DUT2 q=%h expected %h (en=%b golden=%h)",
                 $time, q2, en_bit ? golden[19:10] : 10'b0, en_bit, golden);
      end
      if (so2 !== golden[19]) begin
        failure_count = failure_count + 1;
        $display("FAIL @%0t: DUT2 so=%b expected %b (golden=%h)",
                 $time, so2, golden[19], golden);
      end
    end
  end

  // ------------------------------------------------------------------
  // Bit/word stimulus helpers
  // ------------------------------------------------------------------
  // Send one serial bit: data write (CP low), then clock write (CP high).
  task automatic send_bit(input logic b, input logic en);
    begin
      cpu_cycle({1'b0, en, b, 1'b0}, 1'b1, 1'b1);  // DIN=b, CP=0
      cpu_cycle({1'b0, en, b, 1'b1}, 1'b1, 1'b1);  // DIN=b, CP=1 (pulse)
    end
  endtask

  // Send a 10-bit word; msb_first=1 sends bit9 first (straight load),
  // msb_first=0 sends bit0 first (mirrored load).
  task automatic load_word10(input logic [9:0] w, input logic en,
                             input logic msb_first);
    integer k;
    begin
      for (k = 0; k < 10; k++) begin
        send_bit(msb_first ? w[9-k] : w[k], en);
      end
    end
  endtask

  // ------------------------------------------------------------------
  // Main sequence
  // ------------------------------------------------------------------
  logic [9:0]  word_a;
  logic [19:0] word20;
  logic [9:0]  exp_q1;
  logic [15:0] lfsr;
  integer      op;

  initial begin
    cycle_count  = 0;
    check_count  = 0;
    failure_count = 0;
    bus_sync     = 1'b0;
    bus_cm_rom   = 1'b0;
    bus_cm_ram   = 4'b0000;
    bus_data     = 4'h0;
    bus_oe       = 1'b0;

    // ---- Reset ----
    repeat (4) @(posedge clk);
    rst_n = 1'b1;

    // D1: post-reset state, enable on, no CP pulse yet
    cpu_cycle(4'b0100, 1'b1, 1'b1);   // EN=1, CP=0, DIN=0
    idle_cycle();
    idle_cycle();
    dir_check(q1 === 10'b0, "D1 post-reset DUT1 q");
    dir_check(so1 === 1'b0, "D1 post-reset DUT1 so");
    dir_check(q2 === 10'b0, "D1 post-reset DUT2 q");
    dir_check(so2 === 1'b0, "D1 post-reset DUT2 so");

    // D2: full 10-pulse loads, MSB first (straight words)
    load_word10(10'b0000000000, 1'b1, 1'b1);
    idle_cycle();
    dir_check(q1 === 10'b0000000000, "D2 load 000h");
    load_word10(10'b1111111111, 1'b1, 1'b1);
    idle_cycle();
    dir_check(q1 === 10'b1111111111, "D2 load 3FFh");
    load_word10(10'b0101010101, 1'b1, 1'b1);
    idle_cycle();
    dir_check(q1 === 10'b0101010101, "D2 load 155h");
    load_word10(10'b1010101010, 1'b1, 1'b1);
    idle_cycle();
    dir_check(q1 === 10'b1010101010, "D2 load 2AAh");
    load_word10(10'b1100101010, 1'b1, 1'b1);
    idle_cycle();
    dir_check(q1 === 10'b1100101010, "D2 load 32Ah");
    load_word10(10'b1001110001, 1'b1, 1'b1);
    idle_cycle();
    dir_check(q1 === 10'b1001110001, "D2 load 271h");
    load_word10(10'b0110100101, 1'b1, 1'b1);
    idle_cycle();
    dir_check(q1 === 10'b0110100101, "D2 load 1A5h");
    load_word10(10'b1110001110, 1'b1, 1'b1);
    idle_cycle();
    dir_check(q1 === 10'b1110001110, "D2 load 38Eh");

    // D3: partial load (4 pulses only); stages 0-3 hold the new bits,
    // upper stages keep older content (scoreboard covers the mix).
    send_bit(1'b1, 1'b1);
    send_bit(1'b0, 1'b1);
    send_bit(1'b1, 1'b1);
    send_bit(1'b1, 1'b1);
    idle_cycle();
    dir_check(q1[3:0] === 4'b1011, "D3 partial low stages");

    // D4: CP held high across idle cycles must not re-shift. The pulse
    // lands one clock after the CP=1 write cycle ends; consume it first,
    // then verify the held-high line produces no further shifts.
    cpu_cycle({1'b0, 1'b1, 1'b0, 1'b1}, 1'b1, 1'b1);  // CP=1 write
    idle_cycle();                     // pulse consumed here, CP still high
    exp_q1 = q1;
    idle_cycle();
    idle_cycle();
    idle_cycle();
    dir_check(q1 === exp_q1, "D4 CP held high, one shift only");

    // D5: DATA IN and CP changing in the same port write (simultaneous)
    for (op = 0; op < 10; op++) begin
      cpu_cycle({1'b0, 1'b1, op[0], 1'b1}, 1'b1, 1'b1);  // CP=1 + data
      cpu_cycle({1'b0, 1'b1, op[0], 1'b0}, 1'b1, 1'b1);  // CP=0 + next data
    end
    idle_cycle();

    // D6: cascade transit, 20-bit word through DUT1 into DUT2
    word20 = 20'b10110011100011110010;
    for (op = 19; op >= 0; op--) begin
      send_bit(word20[op], 1'b1);
    end
    idle_cycle();
    dir_check(q2 === word20[19:10], "D6 cascade upper word");
    dir_check(q1 === word20[9:0],  "D6 cascade lower word");

    // D7: reset mid-load, then reload
    send_bit(1'b1, 1'b1);
    send_bit(1'b0, 1'b1);
    send_bit(1'b1, 1'b1);
    send_bit(1'b1, 1'b1);
    send_bit(1'b0, 1'b1);
    rst_n = 1'b0;
    repeat (3) @(posedge clk);
    rst_n = 1'b1;
    cpu_cycle(4'b0100, 1'b1, 1'b1);   // EN back on
    idle_cycle();
    dir_check(q1 === 10'b0, "D7 reset clears DUT1");
    dir_check(q2 === 10'b0, "D7 reset clears DUT2");
    dir_check(so1 === 1'b0, "D7 reset clears DUT1 so");
    load_word10(10'b1100110011, 1'b1, 1'b1);
    idle_cycle();
    dir_check(q1 === 10'b1100110011, "D7 reload after reset");

    // D8: enable gating - shift while disabled, then re-enable
    cpu_cycle(4'b0000, 1'b1, 1'b1);   // EN off
    load_word10(10'b0011011101, 1'b0, 1'b1);  // shifting while disabled
    dir_check(q1 === 10'b0, "D8 outputs masked while disabled");
    dir_check(so2 === golden[19], "D8 serial out live while disabled");
    cpu_cycle(4'b0100, 1'b1, 1'b1);   // EN on
    idle_cycle();
    dir_check(q1 === golden[9:0], "D8 outputs appear on enable");
    load_word10(10'b0100101011, 1'b1, 1'b1);
    idle_cycle();
    dir_check(q1 === 10'b0100101011, "D8 load after re-enable");

    // D9: LSB-first load produces the mirrored word
    word_a = 10'b0111000010;
    load_word10(word_a, 1'b1, 1'b0);
    idle_cycle();
    dir_check(q1 === {word_a[0], word_a[1], word_a[2], word_a[3],
                      word_a[4], word_a[5], word_a[6], word_a[7],
                      word_a[8], word_a[9]},
              "D9 LSB-first mirrored load");

    // R1: randomized phase - LFSR-driven port traffic, continuous
    // scoreboard checking every edge. Nibbles: bit0 CP, bit1 DATA IN,
    // bit2 ENABLE; occasional RAM-port (WMP) writes and idle cycles.
    lfsr = 16'hACE1;
    for (op = 0; op < 600; op++) begin
      lfsr = {lfsr[14:0], lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10]};
      case (lfsr[1:0])
        2'b00: cpu_cycle({1'b0, lfsr[5], lfsr[4], 1'b0}, 1'b1, 1'b1);
        2'b01: cpu_cycle({1'b0, lfsr[5], lfsr[4], 1'b1}, 1'b1, 1'b1);
        2'b10: cpu_cycle({1'b0, lfsr[5], lfsr[4], lfsr[6]}, 1'b1, 1'b1);
        2'b11: begin
          if (lfsr[6]) begin
            cpu_cycle({1'b0, lfsr[5], lfsr[4], 1'b0}, 1'b0, 1'b1);
          end else begin
            idle_cycle();
            if (lfsr[4]) idle_cycle();
          end
        end
      endcase
    end
    idle_cycle();

    // ---- Report ----
    $display("4003 simulation result: %0d cycles, %0d checks, %0d failures",
             cycle_count, check_count, failure_count);
    if (failure_count == 0) begin
      $display("TEST PASSED: %0d checks, %0d cycles",
               check_count, cycle_count);
    end else begin
      $display("TEST FAILED: %0d failures in %0d checks, %0d cycles",
               failure_count, check_count, cycle_count);
    end
    $finish;
  end

  always @(posedge clk) begin
    cycle_count = cycle_count + 1;
  end

  // Watchdog
  initial begin
    #10_000_000;
    $display("TEST FAILED: watchdog timeout at %0t", $time);
    $finish;
  end

  /* verilator lint_on BLKSEQ */

endmodule
