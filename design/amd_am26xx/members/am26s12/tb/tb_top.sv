`timescale 1ns/1ps
// Self-checking testbench for the Am26S12 reconstruction (REVISION 0;
// the Am26S12A member runs the same stimulus against REVISION 1).
//
// 1. Exhaustive check of all 2^6 = 64 input combinations (dual enables,
//    four data inputs) against the truth-table contract with pull-up
//    bias on the bus nets (inline z checks).
// 2. Bus-net checks: the dut's driver and receiver ports tied onto one
//    tristate net with pull-up bias — released bus idles high.
// 3. Party-line check: two transceivers on a shared biased bus net.
module tb_top;
  logic e1_n_i = 1'b0, e2_n_i = 1'b0;
  logic i0_i = 1'b0, i1_i = 1'b0, i2_i = 1'b0, i3_i = 1'b0;
  wire b0_io, b1_io, b2_io, b3_io;
  logic z0_n_o, z1_n_o, z2_n_o, z3_n_o;

  am26s12 #(.REVISION(0)) dut (
      .e1_n_i, .e2_n_i,
      .i0_i, .b0_n_o(b0_io), .b0_i(b0_io), .z0_n_o(z0_n_o),
      .i1_i, .b1_n_o(b1_io), .b1_i(b1_io), .z1_n_o(z1_n_o),
      .i2_i, .b2_n_o(b2_io), .b2_i(b2_io), .z2_n_o(z2_n_o),
      .i3_i, .b3_n_o(b3_io), .b3_i(b3_io), .z3_n_o(z3_n_o));

  pullup (b0_io);
  pullup (b1_io);
  pullup (b2_io);
  pullup (b3_io);

  // --- Party-line fixtures: two extra units on shared bus nets ---
  logic p_e1_n = 1'b1, p_e2_n = 1'b0, p_e1b_n = 1'b1, p_e2b_n = 1'b0;
  logic p_i0 = 1'b0, p_i0b = 1'b0;
  wire p_bus0;
  logic p_z0a, p_z0b;
  am26s12 #(.REVISION(0)) party_u0 (
      .e1_n_i(p_e1_n), .e2_n_i(p_e2_n),
      .i0_i(p_i0), .b0_n_o(p_bus0), .b0_i(p_bus0), .z0_n_o(p_z0a),
      .i1_i(1'b0), .b1_n_o(), .b1_i(1'b0), .z1_n_o(),
      .i2_i(1'b0), .b2_n_o(), .b2_i(1'b0), .z2_n_o(),
      .i3_i(1'b0), .b3_n_o(), .b3_i(1'b0), .z3_n_o());
  am26s12 #(.REVISION(0)) party_u1 (
      .e1_n_i(p_e1b_n), .e2_n_i(p_e2b_n),
      .i0_i(p_i0b), .b0_n_o(p_bus0), .b0_i(p_bus0), .z0_n_o(p_z0b),
      .i1_i(1'b0), .b1_n_o(), .b1_i(1'b0), .z1_n_o(),
      .i2_i(1'b0), .b2_n_o(), .b2_i(1'b0), .z2_n_o(),
      .i3_i(1'b0), .b3_n_o(), .b3_i(1'b0), .z3_n_o());
  pullup (p_bus0);

  integer errors = 0;
  integer checks = 0;
  integer e1, e2, a, b, c, d;
  logic e_check;

  initial begin
    // --- 1. Exhaustive dual-enable sweep ---
    for (e1 = 0; e1 < 2; e1++)
      for (e2 = 0; e2 < 2; e2++)
        for (a = 0; a < 2; a++)
          for (b = 0; b < 2; b++)
            for (c = 0; c < 2; c++)
              for (d = 0; d < 2; d++) begin
                e1_n_i = e1[0]; e2_n_i = e2[0];
                i0_i = a[0]; i1_i = b[0]; i2_i = c[0]; i3_i = d[0];
                #1;
                e_check = 0;
                if (!e1_n_i && !e2_n_i) begin
                  if (b0_io !== !i0_i) e_check = 1;
                  if (b1_io !== !i1_i) e_check = 1;
                  if (b2_io !== !i2_i) e_check = 1;
                  if (b3_io !== !i3_i) e_check = 1;
                end else begin
                  // Either enable high releases; bus idles high.
                  if (b0_io !== 1'b1) e_check = 1;
                  if (b1_io !== 1'b1) e_check = 1;
                  if (b2_io !== 1'b1) e_check = 1;
                  if (b3_io !== 1'b1) e_check = 1;
                end
                if (z0_n_o !== !b0_io) e_check = 1;
                if (z1_n_o !== !b1_io) e_check = 1;
                if (z2_n_o !== !b2_io) e_check = 1;
                if (z3_n_o !== !b3_io) e_check = 1;
                if (e_check) begin
                  $display("FAIL: e=%b%b i=%b%b%b%b b=%b%b%b%b z=%b%b%b%b",
                           e1, e2, a, b, c, d,
                           b0_io, b1_io, b2_io, b3_io,
                           z0_n_o, z1_n_o, z2_n_o, z3_n_o);
                  errors++;
                end
                checks++;
              end

    // --- 2. Party line ---
    begin
      // Unit 1 released (one enable high), unit 0 driving the bus low
      // (inverting driver: input high). Unit 1's receiver reads it.
      p_e1_n = 1'b0; p_e2_n = 1'b0; p_i0 = 1'b1;
      p_e1b_n = 1'b1; p_e2b_n = 1'b0; p_i0b = 1'b0; #1;
      if (p_z0b !== 1'b1) begin
        $display("FAIL party: u0 drives 0, u1 receiver=%b expected 1",
                 p_z0b);
        errors++;
      end
      checks++;
      // Unit 0 releases (one enable high): bus pulls up; both receivers
      // read 1 -> Z = 0.
      p_e1_n = 1'b1; #1;
      if (p_z0a !== 1'b0 || p_z0b !== 1'b0) begin
        $display("FAIL party: released bus z0a=%b z0b=%b expected 0 0",
                 p_z0a, p_z0b);
        errors++;
      end
      checks++;
      // Unit 1 takes the bus and drives a 0 (input high); unit 0's
      // receiver reads it.
      p_e1b_n = 1'b0; p_i0b = 1'b1; #1;
      if (p_z0a !== 1'b1) begin
        $display("FAIL party: u1 drives 0, u0 receiver=%b expected 1",
                 p_z0a);
        errors++;
      end
      checks++;
    end

    if (errors == 0) begin
      $display("am26s12 TEST PASSED (%0d checks)", checks);
      $finish;
    end else begin
      $display("am26s12 TEST FAILED (%0d errors / %0d checks)", errors, checks);
      $fatal(1, "am26s12 testbench failed");
    end
  end
endmodule
