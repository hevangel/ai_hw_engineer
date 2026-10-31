// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x679.md.
// =============================================================================
// ttl_74x679 - 12-bit address comparator with enable
//
// Original part number : 74x679 (SN74ALS679)
// Description          : 12-bit address comparator with active-low enable.
// Datasheet reference  : TI SN54ALS679/SN74ALS679 (D2661)
//
// NOTE on the part list: build/chips.json describes '679 as the "latch" variant
// and '680 as the "enable" variant. The datasheet is the reverse: the 'ALS679
// has the enable input (G) and the 'ALS680 has the transparent latch (C). This
// module follows the datasheet.
//
// Function
// --------
// The 12-bit counterpart of the '677. The four P inputs form an unsigned
// threshold k = {P3,P2,P1,P0}. For each address input Ai (i = 1..12):
//
//   - Ai must be LOW  if i <= k
//   - Ai must be HIGH if i >  k
//
// (Equivalently, Ai must be low iff P >= i.) When enabled (g_n = 0), the
// active-low output Y goes low iff every Ai meets its requirement; when
// disabled (g_n = 1) Y is high. For k >= 12 (P = 12..15) every Ai must be low;
// the datasheet marks P = 12,13,14 as redundant aliases of P = 15, which the
// "i <= k" rule reproduces automatically.
//
//     match = (A1..Ak all 0) & (A(k+1)..A12 all 1)
//     y     = g_n ? 1'b1 : ~match
//
// FPGA notes
// ----------
// Pure combinational. No clock, reset, tri-state.
//
// Pin mapping (J/N, 20-pin): A1..A9 = pins 1-9, GND = 10, A10..A12 = 11-13,
// P0..P3 = 14-17, Y = 18, /G = 19, Vcc = 20. (a is declared [12:1] so a[i]=Ai.)
//
// Unsupported physical behavior
// -----------------------------
// None beyond the usual electrical-only characteristics (drive, delay).
// =============================================================================

module ttl_74x679 (
    input  logic        g_n,        // active-low enable (datasheet /G)
    input  logic [3:0]  p,          // threshold select P3..P0 (p[3]=P3 MSB)
    input  logic [12:1] a,          // address inputs A1..A12
    output logic        y           // active-low match output
);

    logic match;

    always_comb begin
        match = 1'b1;
        for (int i = 1; i <= 12; i++) begin
            if (i <= int'(p)) match &= (a[i] == 1'b0);  // A1..Ak must be low
            else              match &= (a[i] == 1'b1);  // rest must be high
        end
    end

    assign y = g_n ? 1'b1 : ~match;

endmodule
