`timescale 1ns/1ps
// Self-checking testbench for the Am26S10 reconstruction.
//
// 1. Exhaustive check of all 2^5 = 32 input combinations against the
//    truth-table contract per channel (inline z checks; Verilator
//    resolves tristate z across task-argument copies).
// 2. Bus-net checks: the dut's driver and receiver ports tied onto one
//    tristate net with pull-up bias — the released bus idles high and
//    the receiver reads it.
// 3. Party-line check: two transceivers wired to shared bus nets; the
//    disabled unit's receiver reads the level the enabled unit drives
//    (the datasheet's Y/Ȳ rows), and the released bus idles high.
module tb_top;
  logic e_n_i = 1'b0;
  logic i0_i = 1'b0, i1_i = 1'b0, i2_i = 1'b0, i3_i = 1'b0;
  wire b0_io, b1_io, b2_io, b3_io;
  logic z0_n_o, z1_n_o, z2_n_o, z3_n_o;

  am26s10 dut (
      .e_n_i,
      .i0_i, .b0_n_o(b0_io), .b0_i(b0_io), .z0_n_o(z0_n_o),
      .i1_i, .b1_n_o(b1_io), .b1_i(b1_io), .z1_n_o(z1_n_o),
      .i2_i, .b2_n_o(b2_io), .b2_i(b2_io), .z2_n_o(z2_n_o),
      .i3_i, .b3_n_o(b3_io), .b3_i(b3_io), .z3_n_o(z3_n_o));

  pullup (b0_io);
  pullup (b1_io);
  pullup (b2_io);
  pullup (b3_io);

  // --- Party-line fixtures: two extra units on shared bus nets ---
  logic party_e0_n = 1'b1, party_e1_n = 1'b1;
  logic party_i0 = 1'b0, party_i1 = 1'b0;
  wire party_bus0;
  logic party_z0a, party_z0b;
  am26s10 party_u0 (.e_n_i(party_e0_n), .i0_i(party_i0),
                    .b0_n_o(party_bus0), .b0_i(party_bus0),
                    .z0_n_o(party_z0a),
                    .i1_i(1'b0), .b1_n_o(), .b1_i(1'b0), .z1_n_o(),
                    .i2_i(1'b0), .b2_n_o(), .b2_i(1'b0), .z2_n_o(),
                    .i3_i(1'b0), .b3_n_o(), .b3_i(1'b0), .z3_n_o());
  am26s10 party_u1 (.e_n_i(party_e1_n), .i0_i(party_i1),
                    .b0_n_o(party_bus0), .b0_i(party_bus0),
                    .z0_n_o(party_z0b),
                    .i1_i(1'b0), .b1_n_o(), .b1_i(1'b0), .z1_n_o(),
                    .i2_i(1'b0), .b2_n_o(), .b2_i(1'b0), .z2_n_o(),
                    .i3_i(1'b0), .b3_n_o(), .b3_i(1'b0), .z3_n_o());
  pullup (party_bus0);

  integer errors = 0;
  integer checks = 0;
  integer e, a, b, c, d;
  logic e_check;

  initial begin
    // --- 1. Exhaustive single-unit sweep ---
    for (e = 0; e < 2; e++)
      for (a = 0; a < 2; a++)
        for (b = 0; b < 2; b++)
          for (c = 0; c < 2; c++)
            for (d = 0; d < 2; d++) begin
              e_n_i = e[0];
              i0_i = a[0]; i1_i = b[0]; i2_i = c[0]; i3_i = d[0];
              #1;
              e_check = 0;
              if (!e_n_i) begin
                if (b0_io !== !i0_i) e_check = 1;
                if (b1_io !== !i1_i) e_check = 1;
                if (b2_io !== !i2_i) e_check = 1;
                if (b3_io !== !i3_i) e_check = 1;
                if (z0_n_o !== !b0_io) e_check = 1;
                if (z1_n_o !== !b1_io) e_check = 1;
                if (z2_n_o !== !b2_io) e_check = 1;
                if (z3_n_o !== !b3_io) e_check = 1;
              end else begin
                // Released with pull-up bias: bus idles high.
                if (b0_io !== 1'b1) e_check = 1;
                if (b1_io !== 1'b1) e_check = 1;
                if (b2_io !== 1'b1) e_check = 1;
                if (b3_io !== 1'b1) e_check = 1;
                if (z0_n_o !== 1'b0) e_check = 1;
                if (z1_n_o !== 1'b0) e_check = 1;
                if (z2_n_o !== 1'b0) e_check = 1;
                if (z3_n_o !== 1'b0) e_check = 1;
              end
              if (e_check) begin
                $display("FAIL: e=%b i=%b%b%b%b b=%b%b%b%b z=%b%b%b%b",
                         e, a, b, c, d,
                         b0_io, b1_io, b2_io, b3_io,
                         z0_n_o, z1_n_o, z2_n_o, z3_n_o);
                errors++;
              end
              checks++;
            end

    // --- 2. Party line ---
    begin
      // Unit 1 disabled, unit 0 driving the bus low (the driver
      // inverts, so the input is high): unit 1's receiver must read it
      // (Z = !bus = 1).
      party_e0_n = 1'b0; party_e1_n = 1'b1; party_i0 = 1'b1; #1;
      if (party_z0b !== 1'b1) begin
        $display("FAIL party: u0 drives 0, u1 receiver=%b expected 1",
                 party_z0b);
        errors++;
      end
      checks++;
      // Unit 0 releases: bus pulls up; both receivers read 1 -> Z = 0.
      party_e0_n = 1'b1; #1;
      if (party_z0a !== 1'b0 || party_z0b !== 1'b0) begin
        $display("FAIL party: released bus z0a=%b z0b=%b expected 0 0",
                 party_z0a, party_z0b);
        errors++;
      end
      checks++;
      // Unit 1 takes the bus and drives a 0 (input high); unit 0's
      // receiver reads it.
      party_e1_n = 1'b0; party_i1 = 1'b1; #1;
      if (party_z0a !== 1'b1) begin
        $display("FAIL party: u1 drives 0, u0 receiver=%b expected 1",
                 party_z0a);
        errors++;
      end
      checks++;
    end

    if (errors == 0) begin
      $display("am26s10 TEST PASSED (%0d checks)", checks);
    end else begin
      $display("am26s10 TEST FAILED (%0d errors / %0d checks)", errors, checks);
      $fatal(1, "am26s10 testbench failed");
    end
    $finish;
  end
endmodule
