// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x676.md.
// =============================================================================
// ttl_74x676 - 16-bit serial/parallel-in, serial-out shift register
//
// Original part number : 74x676 (74F676)
// Datasheet reference  : National 74F676 (FAST databook, 1988)
//
// Function
// --------
// A 16-bit shift register with parallel load and serial in/out (no parallel
// outputs). Three modes (Shift Register Operations Table), clocked on the
// FALLING edge of cp while cs_n = 0:
//
//   CS M CP | mode
//    H X X  | Hold
//    L L v  | Shift / serial load : SI enters at Q0, shifts toward Q15
//    L H v  | Parallel load from P0..P15
//
//   so = shift-register MSB (Q15)
//
// Unlike the TI '674, SI and SO are separate pins (not bidirectional) and the
// parallel inputs P0..P15 are dedicated; the output is always driven.
//
// FPGA notes
// ----------
// Falling-edge clocked, single 16-bit register.
//
// Pin mapping: P0..P15, CS, CP, M, SI inputs; SO output (see datasheet for the
// exact 24-pin assignment). p[0]=P0 (LSB).
//
// Unsupported physical behavior
// -----------------------------
// None beyond electrical drive/timing.
// =============================================================================

module ttl_74x676 (
    input  logic [15:0] p,        // parallel data inputs P0..P15
    input  logic        cs_n,     // chip select, active low
    input  logic        cp,       // clock pulse (falling-edge active)
    input  logic        m,        // mode: 0 = shift/serial load, 1 = parallel load
    input  logic        si,       // serial data input
    output logic        so        // serial output (shift-register MSB)
);
    logic [15:0] sr;

    always_ff @(negedge cp) begin
        if (!cs_n) begin
            if (!m) sr <= {sr[14:0], si};   // shift / serial load
            else    sr <= p;                 // parallel load
        end
    end

    assign so = sr[15];
endmodule
