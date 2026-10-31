// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x677.md.
// =============================================================================
// ttl_74x677 - 16-bit address comparator with enable
//
// Original part number : 74x677 (SN74ALS677A)
// Description          : 16-bit address comparator with active-low enable.
// Datasheet reference  : TI SN74ALS677A (SDAS012C)
//
// Function
// --------
// The four P inputs (P3..P0, normally hardwired to a preprogrammed address)
// form an unsigned threshold k = {P3,P2,P1,P0}, 0..15. An internal decoder
// determines, for each of the sixteen address inputs A1..A16, whether it must
// be low or high to assert the (active-low) match output Y:
//
//   - A1 .. Ak      must be LOW
//   - A(k+1) .. A16 must be HIGH
//
// When enabled (g_n = 0), Y goes low iff that pattern is satisfied. When
// disabled (g_n = 1) Y is high regardless of A and P. (Datasheet example:
// P = 0111b = 7 requires A1..A7 low and A8..A16 high to drive Y low.)
//
//     match = (A1..Ak all 0) & (A(k+1)..A16 all 1)
//     y     = g_n ? 1'b1 : ~match
//
// Y is active-low (low = address match); the datasheet labels the pin "Y"
// (no overbar), so the port keeps that name.
//
// FPGA notes
// ----------
// Pure combinational. No clock, reset, tri-state. The per-bit "low or high"
// requirement is selected by comparing each bit index against the decoded
// threshold k.
//
// Pin mapping (DW/NT, 24-pin): A1..A11 = pins 1-11, GND = 12, A12..A16 = 13-17,
// P0..P3 = 18-21, Y = 22, /G = 23, Vcc = 24. (a is declared [16:1] so a[i]=Ai.)
//
// Unsupported physical behavior
// -----------------------------
// None beyond the usual electrical-only characteristics (drive, delay). This
// is a purely combinational logic function.
// =============================================================================

module ttl_74x677 (
    input  logic        g_n,        // active-low enable (datasheet /G)
    input  logic [3:0]  p,          // threshold select P3..P0 (p[3]=P3 MSB)
    input  logic [16:1] a,          // address inputs A1..A16
    output logic        y           // active-low match output
);

    logic match;

    always_comb begin
        match = 1'b1;
        for (int i = 1; i <= 16; i++) begin
            if (i <= int'(p)) match &= (a[i] == 1'b0);  // A1..Ak must be low
            else              match &= (a[i] == 1'b1);  // rest must be high
        end
    end

    assign y = g_n ? 1'b1 : ~match;

endmodule
