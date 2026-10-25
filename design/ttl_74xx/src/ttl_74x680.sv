// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x680.md.
// =============================================================================
// ttl_74x680 - 12-bit address comparator with transparent latch
//
// Original part number : 74x680 (SN74ALS680)
// Description          : 12-bit address comparator with a transparent output
//                        latch.
// Datasheet reference  : TI SN54ALS679/680, SN74ALS679/680 (D2661)
//
// NOTE on the part list: build/chips.json describes '680 as the "enable"
// variant and '679 as the "latch" variant. The datasheet is the reverse: the
// 'ALS680 has the transparent latch (C) and the 'ALS679 has the enable (G).
// This module follows the datasheet.
//
// Function
// --------
// The 12-bit counterpart of the '678. The four P inputs form an unsigned
// threshold k = {P3,P2,P1,P0}, and for each address input Ai (i = 1..12), Ai
// must be LOW if i <= k and HIGH if i > k. The comparison result (low on
// match) drives a transparent D latch:
//
//   - C high : transparent  -> y = ~match
//   - C low  : latched       -> y holds its previous state
//
//     match = (A1..Ak all 0) & (A(k+1)..A12 all 1)
//
// For k >= 12 (P = 12..15) every Ai must be low (the datasheet marks
// P = 12,13,14 as redundant aliases of P = 15, which the "i <= k" rule
// reproduces automatically).
//
// FPGA notes
// ----------
// y is a level-sensitive (transparent) latch, the chip's actual behavior, so
// always_latch is used deliberately.
//
// Pin mapping (J/N, 20-pin): A1..A9 = pins 1-9, GND = 10, A10..A12 = 11-13,
// P0..P3 = 14-17, Y = 18, C = 19, Vcc = 20. (a is declared [12:1] so a[i]=Ai.)
//
// Unsupported physical behavior
// -----------------------------
// None beyond the usual electrical-only characteristics (drive, delay, latch
// setup/hold timing).
// =============================================================================

module ttl_74x680 (
    input  logic        c,          // latch enable: high=transparent, low=hold
    input  logic [3:0]  p,          // threshold select P3..P0 (p[3]=P3 MSB)
    input  logic [12:1] a,          // address inputs A1..A12
    output logic        y           // active-low match output (latched)
);

    logic match;

    always_comb begin
        match = 1'b1;
        for (int i = 1; i <= 12; i++) begin
            if (i <= int'(p)) match &= (a[i] == 1'b0);  // A1..Ak must be low
            else              match &= (a[i] == 1'b1);  // rest must be high
        end
    end

    always_latch begin
        if (c) y = ~match;          // transparent when C high; hold when C low
    end

endmodule
