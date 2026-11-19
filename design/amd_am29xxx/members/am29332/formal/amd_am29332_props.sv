// Formal properties for the Am29332. Included inside amd_am29332 under
// `ifdef FORMAL. These check the sequential contract of the status and Q
// registers and the combinational read-only status bits, independently of
// the datapath case items. Tri-state/slave-compare pad logic is verified in
// simulation (documented scope, see plans/testplan.md).
logic past_valid = 1'b0;
logic [31:0] past_status = 32'h0;
logic [31:0] past_q = 32'h0;
logic        past_hold = 1'b0;
logic        past_ldstat = 1'b0;
logic        past_ldq = 1'b0;
logic [31:0] past_ldq_src = 32'h0;
logic [31:0] past_ldq_sel = 32'h0;
logic [31:0] past_ldstat_src = 32'h0;
logic [31:0] past_ldstat_sel = 32'h0;
logic        past_logic_class = 1'b0;  // logical/N-bit/bit/field/mask class
logic        past_passstat = 1'b0, past_passq = 1'b0;

// opcode set membership helper (yosys-safe; no `inside` operator)
function automatic logic op_in(input logic [6:0] op,
                               input logic [6:0] a,
                               input logic [6:0] b,
                               input logic [6:0] c,
                               input logic [6:0] d,
                               input logic [6:0] e,
                               input logic [6:0] f,
                               input logic [6:0] g);
  op_in = (op == a) || (op == b) || (op == c) || (op == d)
          || (op == e) || (op == f) || (op == g);
endfunction

wire ldstat_now  = (opcode == 7'h1C) || (opcode == 7'h1D);
wire ldq_now     = (opcode == 7'h06) || (opcode == 7'h07);
wire passstat_now = opcode == 7'h04;
wire passq_now    = opcode == 7'h05;
// classes that never update C/V/L/M/S or the nibble-carry byte.
// Exclusions: SETBIT/RSTBIT-STAT (6C/6D) can write any writable status bit;
// EXTBIT-A/B/STAT (66/67/7E) update L.
wire logic_class  = op_in(opcode, 7'h3E, 7'h3F, 7'h40, 7'h41, 7'h3C, 7'h3D,
                          7'h00)
                 || ((opcode >= 7'h60) && (opcode != 7'h6C)
                     && (opcode != 7'h6D) && (opcode != 7'h66)
                     && (opcode != 7'h67) && (opcode != 7'h7E));
// flags these classes never update: C, V, L, M, S (Z/N only)
wire [31:0] ro_mask = 32'hFF7F1FFF;  // writable status bits (13/14/15/23 ro)

// combinational read-only bits must always match their definitions.
// Bits 14/15/23 are borow-independent; bit 13 tracks the BOROW pin at the
// write edge, so its stored value is asserted through the PASS-STAT
// readout contract below instead (stat_comb presents the live value).
always @* begin
  assert (status_q[23] == 1'b0);
  assert (status_q[14] == (status_q[17] ^ status_q[18]));
  assert (status_q[15] == ((status_q[17] ^ status_q[18]) | status_q[19]));
end

always @(posedge cp_i) begin
  // HOLD freezes both registers
  if (past_valid && past_hold) begin
    assert (status_q == past_status);
    assert (q_q == past_q);
  end
  // LDSTAT writes exactly the selected writable bytes; the read-only
  // relational bits have no cells and end up as the combinational values
  // of the post-write flag byte
  if (past_valid && past_ldstat && !past_hold) begin
    assert (status_q == stat_comb((past_status & ~(past_ldstat_sel & ro_mask))
                                  | (past_ldstat_src & past_ldstat_sel & ro_mask)
                                  | (past_status & ~past_ldstat_sel),
                                  $past(borow_i)));
    // Q never changes on LDSTAT
    assert (q_q == past_q);
  end
  // LOADQ writes exactly the selected Q bytes
  if (past_valid && past_ldq && !past_hold) begin
    assert (q_q == ((past_q & ~past_ldq_sel) | (past_ldq_src & past_ldq_sel)));
  end
  // PASS-STAT / PASS-Q update no state (the borow-dependent read-only
  // bits 15:13 re-derive each edge; the writable mask 0xFF7F_1FFF excludes
  // them and the always-zero bit 23 from the comparison)
  if (past_valid && (past_passstat || past_passq) && !past_hold) begin
    assert ((status_q & 32'hFF7F_1FFF) == (past_status & 32'hFF7F_1FFF));
    assert (q_q == past_q);
  end
  // the logical/N-bit/bit/field/mask classes never touch C, V, L, M, S
  // or the nibble-carry byte, and never write Q
  if (past_valid && past_logic_class && !past_hold) begin
    assert (status_q[16] == past_status[16]);
    assert (status_q[18] == past_status[18]);
    assert (status_q[20] == past_status[20]);
    assert (status_q[21] == past_status[21]);
    assert (status_q[22] == past_status[22]);
    assert (status_q[31:24] == past_status[31:24]);
    assert (q_q == past_q);
  end
  past_valid <= 1'b1;
  past_status <= status_q;
  past_q <= q_q;
  past_hold <= hold_i;
  past_ldstat <= ldstat_now;
  past_ldstat_src <= (opcode == 7'h1C) ? a : b;
  past_ldstat_sel <= sel;
  past_ldq <= ldq_now;
  past_ldq_src <= (opcode == 7'h06) ? a : b;
  past_ldq_sel <= sel;
  past_logic_class <= logic_class;
  past_passstat <= passstat_now;
  past_passq <= passq_now;
end

// Y passthrough contracts for the status/Q movement instructions
always @* begin
  if (opcode == 7'h04)
    assert (y_res == ((stat_comb(status_q, borow_i) & sel) | (b & ~sel)));
  if (opcode == 7'h05)
    assert (y_res == ((q_q & sel) | (b & ~sel)));
  if (opcode == 7'h1C || opcode == 7'h1D)
    assert (y_res == ((stat_comb(status_q, borow_i) & ~sel)
                      | (((opcode == 7'h1C) ? a : b) & sel)));
end

// cover points: reach every class and the key side effects
always @(posedge cp_i) begin
  if (past_valid) begin
    cover (op_in(opcode, 7'h42, 7'h43, 7'h44, 7'h45, 7'h46, 7'h47, 7'h00));
    cover (op_in(opcode, 7'h48, 7'h49, 7'h4A, 7'h4B, 7'h00, 7'h00, 7'h00));
    cover (op_in(opcode, 7'h5B, 7'h5C, 7'h5D, 7'h5E, 7'h5F, 7'h00, 7'h00));
    cover (op_in(opcode, 7'h4E, 7'h4F, 7'h50, 7'h51, 7'h52, 7'h53, 7'h54)
           || op_in(opcode, 7'h55, 7'h56, 7'h57, 7'h58, 7'h59, 7'h5A, 7'h00));
    cover (op_in(opcode, 7'h0C, 7'h0D, 7'h00, 7'h00, 7'h00, 7'h00, 7'h00));
    cover (ldstat_now);
    cover (ldq_now);
    cover (hold_i);
    cover (slave_i);
    cover (opcode >= 7'h60);
    cover (op_in(opcode, 7'h20, 7'h21, 7'h30, 7'h31, 7'h00, 7'h00, 7'h00));
    cover (perr_o);
  end
end
