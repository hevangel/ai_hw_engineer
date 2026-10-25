// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x866.md.
// =============================================================================
// ttl_74x866 - 8-bit magnitude comparator with input/output latches
//
// Original part number : 74x866 (SN74AS866)
// Datasheet reference  : TI SN54AS866/SN74AS866 (D2661, Dec 1982)
//
// Function
// --------
// An 8-bit magnitude comparator (relative of the '885) with transparent input
// latches on both operands, an output latch, a clearable Q register, and three
// decoded outputs (P>Q, P<Q, P=Q) plus cascade inputs.
//
//   - L/A_n selects comparison mode: high = Logical (unsigned),
//     low = Arithmetic (two's-complement / signed).
//   - ple : P input latch enable (transparent when high, else hold).
//   - qle : Q input latch enable (transparent when high, else hold).
//   - clr_q_n : asynchronous clear of the Q latch (active low) — forces the
//     latched Q to 0 for a fast "P vs zero" comparison; dominates qle.
//   - ole : output latch enable (transparent when high, else hold).
//   - Cascade: when this stage compares equal, the P>Qin / P<Qin cascade
//     inputs propagate to the magnitude outputs (expandable to longer words):
//       p_gt_qout = gt | (eq & p_gt_qin)
//       p_lt_qout = lt | (eq & p_lt_qin)
//   - p_eq_qout = eq. On the real device this is an OPEN-COLLECTOR output so
//     that the P=Q outputs of cascaded stages can be wire-ANDed; the physical
//     wired-AND is NOT modeled (the logic level is driven directly).
//   All three outputs pass through the output latch (ole).
//
// FPGA notes
// ----------
// Three transparent latches (the chip's actual behavior) -> always_latch.
//
// Pin mapping (28-pin): QLE=1, L/A=2, P<Qin=3, P>Qin=4, Q7..Q0=5..12,
// P=Qout=13, GND=14, OLE=15, P>Qout=16, P<Qout=17, P0..P7=18..25, PLE=26,
// /CLRQ=27, Vcc=28.
//
// Unsupported physical behavior
// -----------------------------
// Open-collector P=Q output (wired-AND) — driven as a plain logic level.
// =============================================================================

module ttl_74x866 (
    input  logic       l_a_n,      // high = logical/unsigned, low = arithmetic/signed
    input  logic       ple,        // P latch enable (transparent high)
    input  logic       qle,        // Q latch enable (transparent high)
    input  logic       clr_q_n,    // async clear of Q latch (active low)
    input  logic       ole,        // output latch enable (transparent high)
    input  logic       p_gt_qin,   // cascade input
    input  logic       p_lt_qin,   // cascade input
    input  logic [7:0] p,
    input  logic [7:0] q,
    output logic       p_gt_qout,
    output logic       p_lt_qout,
    output logic       p_eq_qout   // open-collector on the real device
);
    logic [7:0] p_lat, q_lat;
    logic       gt, lt, eq, gt_c, lt_c;

    always_latch if (ple) p_lat = p;

    always_latch begin
        if (!clr_q_n) q_lat = 8'd0;     // async clear dominates
        else if (qle) q_lat = q;
    end

    always_comb begin
        eq = (p_lat == q_lat);
        if (l_a_n) begin                // logical / unsigned
            gt = (p_lat > q_lat);
            lt = (p_lat < q_lat);
        end else begin                  // arithmetic / signed
            gt = ($signed(p_lat) > $signed(q_lat));
            lt = ($signed(p_lat) < $signed(q_lat));
        end
        gt_c = gt | (eq & p_gt_qin);
        lt_c = lt | (eq & p_lt_qin);
    end

    always_latch begin
        if (ole) begin
            p_gt_qout = gt_c;
            p_lt_qout = lt_c;
            p_eq_qout = eq;
        end
    end
endmodule
