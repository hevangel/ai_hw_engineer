// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x678.md.
// =============================================================================
// ttl_74x678 - 16-bit address comparator with transparent latch
//
// Original part number : 74x678 (SN74ALS678)
// Description          : 16-bit address comparator with a transparent output
//                        latch.
// Datasheet reference  : TI SN54ALS677/678, SN74ALS677/678 (D2661)
//
// Function
// --------
// The address-comparison core is identical to the '677: the four P inputs form
// an unsigned threshold k = {P3,P2,P1,P0}, and for each address input Ai
// (i = 1..16), Ai must be LOW if i <= k and HIGH if i > k. The comparison
// result (low on match) drives a transparent D latch instead of an enable:
//
//   - C high : transparent  -> y = ~match
//   - C low  : latched       -> y holds its previous state
//
//     match = (A1..Ak all 0) & (A(k+1)..A16 all 1)
//
// (Datasheet function table: 'ALS678 column C = H tracks the comparison; C = L
// latches Y.)
//
// FPGA notes
// ----------
// y is a level-sensitive (transparent) latch, which is the chip's actual
// behavior, so always_latch is used deliberately. Synthesizes to a latch plus
// the combinational compare; intended for FPGA fabric that supports latches.
//
// Pin mapping (JT/NT, 24-pin): A1..A11 = pins 1-11, GND = 12, A12..A16 = 13-17,
// P0..P3 = 18-21, Y = 22, C = 23, Vcc = 24. (a is declared [16:1] so a[i]=Ai.)
//
// Unsupported physical behavior
// -----------------------------
// None beyond the usual electrical-only characteristics (drive, delay, setup/
// hold timing of the latch).
// =============================================================================

module ttl_74x678 (
    input  logic        c,          // latch enable: high=transparent, low=hold
    input  logic [3:0]  p,          // threshold select P3..P0 (p[3]=P3 MSB)
    input  logic [16:1] a,          // address inputs A1..A16
    output logic        y           // active-low match output (latched)
);

    logic match;

    always_comb begin
        match = 1'b1;
        for (int i = 1; i <= 16; i++) begin
            if (i <= int'(p)) match &= (a[i] == 1'b0);  // A1..Ak must be low
            else              match &= (a[i] == 1'b1);  // rest must be high
        end
    end

    always_latch begin
        if (c) y = ~match;          // transparent when C high; hold when C low
    end

endmodule
