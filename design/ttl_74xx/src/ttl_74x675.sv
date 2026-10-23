// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x675.md.
// =============================================================================
// ttl_74x675 - 16-bit serial-in, serial/parallel-out shift register
//
// Original part number : 74x675 (74F675A)
// Datasheet reference  : National 74F675A (FAST databook, 1988)
//
// Function
// --------
// A 16-bit shift register feeding a 16-bit storage register (parallel data
// loop), with a dedicated serial input SI, serial output SO, and parallel
// outputs Q0..Q15 from the storage register.
//
//   Shift register (FALLING edge of srcp, while cs_n = 0):
//     R/W = 0 : shift right - SI enters at Q0, shifts toward Q15
//     R/W = 1 : parallel load from the storage register (serial shift inhibited)
//   Storage register (RISING edge of stcp, while cs_n = 0 and R/W = 1):
//     parallel load from the shift register
//   Outputs:
//     so = shift-register MSB (Q15);  q = storage register (Q0..Q15)
//
// (Shift Register and Storage Register Operations Tables, National 74F675A.)
// Unlike the TI '673, SI and SO are separate pins (not a bidirectional SI/O)
// and there is no separate storage clear; outputs are always driven.
//
// FPGA notes
// ----------
// Two clock domains (srcp falling, stcp rising).
//
// Pin mapping: SI, CS, SRCP, STCP, R/W are inputs; SO and Q0..Q15 are outputs
// (see datasheet for the exact 28-pin assignment). q[0]=Q0 (LSB).
//
// Unsupported physical behavior
// -----------------------------
// None beyond electrical drive/timing.
// =============================================================================

module ttl_74x675 (
    input  logic        si,       // serial data input
    input  logic        cs_n,     // chip select, active low
    input  logic        srcp,     // shift-register clock (falling edge)
    input  logic        stcp,     // storage-register clock (rising edge)
    input  logic        rw,       // 1 = read (parallel-load shift reg from storage), 0 = write/shift
    output logic        so,       // serial data output (shift-register MSB)
    output logic [15:0] q         // storage-register outputs Q0..Q15
);
    logic [15:0] sr, str;

    always_ff @(negedge srcp) begin
        if (!cs_n) begin
            if (!rw) sr <= {sr[14:0], si};   // shift right (SI in at Q0)
            else     sr <= str;               // parallel load from storage
        end
    end

    always_ff @(posedge stcp) begin
        if (!cs_n && rw) str <= sr;           // storage load from shift register
    end

    assign so = sr[15];
    assign q  = str;
endmodule
