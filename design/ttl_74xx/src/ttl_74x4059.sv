// SPDX-License-Identifier: MIT
// Pure-digital behavioral model based on the TI CD74HC4059 data sheet.
`timescale 1ns/1ps
// =============================================================================
// ttl_74x4059 - programmable divide-by-N counter
//
// The input bus j[15:0] maps j[0] to J1 and j[15] to J16. Mode selection
// partitions J1-J4 between the first and final counting sections; J5-J16 are
// three decimal-weighted stages whose four-bit presets may be 0 through 15.
//
// There is no reset pin. The design must first spend at least three CP rising
// edges in master preset (Kb=Kc=0). Leaving master preset consumes the first
// rising edge to transfer the jam image into the selected section layout; the
// count starts at the next edge, as described by the data sheet.
//
// The first section consumes a nonzero remainder before the quotient stages
// begin. A zero remainder instead starts with a complete first-section period.
// Thereafter each complete first-section period decrements the decimal-weighted
// quotient. This preserves N = M*(1000*L + 100*D100 + 10*D10 + D1) + R.
//
// ASSUMPTION: K=010 is not defined in the data-sheet mode table. This model
// holds its count state and generates no new output pulse for that selection.
// ASSUMPTION: LE is a level-sensitive latch control. Low LE asynchronously
// clears the held Q extension; the datasheet LE-to-Q propagation delay is not
// modeled in this zero-delay digital abstraction.
// =============================================================================

module ttl_74x4059 (
    input  logic        cp,
    input  logic        le,
    input  logic [2:0]  k,   // {Ka, Kb, Kc}
    input  logic [15:0] j,   // j[0]=J1 (LSB), j[15]=J16 (MSB)
    output logic        q
);
    logic master_preset;
    logic mode_valid;
    logic [3:0] modulus;
    logic [3:0] first_preset;
    logic [3:0] last_preset;
    logic [3:0] d1_preset;
    logic [3:0] d10_preset;
    logic [3:0] d100_preset;
    logic [15:0] selected_jam;
    logic [15:0] jam_snapshot;

    logic mp_active;
    logic [3:0] first_left;
    logic first_partial;
    logic [3:0] last_left;
    logic [3:0] d1_left;
    logic [3:0] d10_left;
    logic [3:0] d100_left;

    logic quotient_zero;
    logic quotient_one;
    logic q_pulse;
    logic q_hold;

    assign master_preset = (k[1:0] == 2'b00);

    always_comb begin
        selected_jam = j;
        if (!master_preset && mp_active) begin
            selected_jam = jam_snapshot;
        end

        mode_valid = 1'b1;
        modulus = 4'd0;
        first_preset = 4'd0;
        last_preset = 4'd0;

        unique case (k)
            3'b111: begin // ÷2: J1 first, J2-J4 final
                modulus = 4'd2;
                first_preset = {3'b000, selected_jam[0]};
                last_preset = {1'b0, selected_jam[3:1]};
            end
            3'b011: begin // ÷4: J1-J2 first, J3-J4 final
                modulus = 4'd4;
                first_preset = {2'b00, selected_jam[1:0]};
                last_preset = {2'b00, selected_jam[3:2]};
            end
            3'b101: begin // ÷5: J1-J3 first, J4 final
                modulus = 4'd5;
                first_preset = {1'b0, selected_jam[2:0]};
                last_preset = {3'b000, selected_jam[3]};
            end
            3'b001: begin // ÷8: J1-J3 first, J4 final
                modulus = 4'd8;
                first_preset = {1'b0, selected_jam[2:0]};
                last_preset = {3'b000, selected_jam[3]};
            end
            3'b110: begin // ÷10: J1-J4 are all in the first section
                modulus = 4'd10;
                first_preset = selected_jam[3:0];
                last_preset = 4'd0;
            end
            default: begin
                mode_valid = 1'b0;
            end
        endcase

        d1_preset = selected_jam[7:4];
        d10_preset = selected_jam[11:8];
        d100_preset = selected_jam[15:12];
    end

    assign quotient_zero = (last_left == 4'd0)
                         && (d100_left == 4'd0)
                         && (d10_left == 4'd0)
                         && (d1_left == 4'd0);
    assign quotient_one  = (last_left == 4'd0)
                         && (d100_left == 4'd0)
                         && (d10_left == 4'd0)
                         && (d1_left == 4'd1);

    assign q = q_pulse | q_hold;

    // A high LE captures any active output pulse. Returning LE low releases
    // only that held extension asynchronously; the ordinary one-clock pulse
    // remains registered to CP. TI specifies an LE-to-Q propagation delay.
    always_latch begin
        if (!le) begin
            q_hold = 1'b0;
        end else if (q_pulse) begin
            q_hold = 1'b1;
        end
    end

    always_ff @(posedge cp) begin
        q_pulse <= 1'b0;
        if (master_preset) begin
            // Jam inputs are held here until a divide mode is selected.
            jam_snapshot <= j;
            mp_active <= 1'b1;
        end else if (mode_valid) begin
            if (mp_active) begin
                // First CP after MP loads the mode-specific section layout.
                first_left <= (first_preset == 4'd0) ? modulus : first_preset;
                first_partial <= (first_preset != 4'd0);
                last_left <= last_preset;
                d1_left <= d1_preset;
                d10_left <= d10_preset;
                d100_left <= d100_preset;
                mp_active <= 1'b0;
            end else if (first_left > 4'd1) begin
                first_left <= first_left - 4'd1;
            end else if (first_left == 4'd1) begin
                if (first_partial && quotient_zero) begin
                    // N is entirely represented by the nonzero remainder.
                    q_pulse <= 1'b1;
                    first_left <= (first_preset == 4'd0) ? modulus : first_preset;
                    first_partial <= (first_preset != 4'd0);
                    last_left <= last_preset;
                    d1_left <= d1_preset;
                    d10_left <= d10_preset;
                    d100_left <= d100_preset;
                end else if (first_partial) begin
                    // Consume R first. The quotient starts with full M clocks.
                    first_left <= modulus;
                    first_partial <= 1'b0;
                end else if (quotient_one) begin
                    // This full interval is the final quotient unit.
                    q_pulse <= 1'b1;
                    first_left <= (first_preset == 4'd0) ? modulus : first_preset;
                    first_partial <= (first_preset != 4'd0);
                    last_left <= last_preset;
                    d1_left <= d1_preset;
                    d10_left <= d10_preset;
                    d100_left <= d100_preset;
                end else begin
                    // Ripple the borrow through the decimal-weighted stages.
                    first_left <= modulus;
                    if (d1_left != 4'd0) begin
                        d1_left <= d1_left - 4'd1;
                    end else begin
                        d1_left <= 4'd9;
                        if (d10_left != 4'd0) begin
                            d10_left <= d10_left - 4'd1;
                        end else begin
                            d10_left <= 4'd9;
                            if (d100_left != 4'd0) begin
                                d100_left <= d100_left - 4'd1;
                            end else begin
                                d100_left <= 4'd9;
                                if (last_left != 4'd0) begin
                                    last_left <= last_left - 4'd1;
                                end
                            end
                        end
                    end
                end
            end
        end
        // An undefined mode holds the section state; Q still obeys its LE latch.
    end
endmodule
