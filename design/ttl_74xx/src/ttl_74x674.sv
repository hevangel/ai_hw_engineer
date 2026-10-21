// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x674.md.
// =============================================================================
// ttl_74x674 - 16-bit parallel-in, serial-out shift register
//
// Original part number : 74x674 (SN74LS674)
// Datasheet reference  : TI SN54LS673/674, SN74LS673/674 (SDLS195)
//
// Function
// --------
// A 16-bit shift register with parallel load and a three-state serial I/O port
// SER/Q15. Four modes, all clocked on the FALLING edge of clk (per the
// datasheet function table), and enabled by the active-low chip select cs_n:
//
//   CS R/W MODE CLK | operation
//    H  X   X    X  | do nothing (SER/Q15 = Z)
//    L  L   X    v  | shift and write  (serial load via si)        SER/Q15 = Z(in)
//    L  H   L    v  | shift and read   (recirculating)             SER/Q15 = Q15
//    L  H   H    v  | parallel load from p                         SER/Q15 = P15
//
// The serial port is split per library convention: si is the serial input
// (used in write mode); q15 is the serial output (the register MSB), driven
// only when cs_n=0 and rw=1, otherwise high-Z (modeled as 0).
//
//   write:  sr <= {sr[14:0], si}       (new bit in at LSB, MSB shifts out)
//   read:   sr <= {sr[14:0], sr[15]}   (recirculate; non-destructive)
//   load:   sr <= p
//   q15   = (!cs_n && rw) ? sr[15] : 0
//
// FPGA notes
// ----------
// Falling-edge clocked. Three-state serial output modeled as muxed 0.
//
// Pin mapping (24-pin): CS=1, CLK=2, R/W=3, NC=4, MODE=5, SER/Q15=6, P0=7,
// P1=8, P2=9, P3=10, P4=11, GND=12, P5=13, P6=14, P7=15, P8=16, P9=17, P10=18,
// P11=19, P12=20, P13=21, P14=22, P15=23, Vcc=24.
//
// Unsupported physical behavior
// -----------------------------
// True three-state high-Z on SER/Q15 (modeled as driven 0). The single
// bidirectional SER/Q15 pin is split into si (in) and q15 (out).
// =============================================================================

module ttl_74x674 (
    input  logic        cs_n,      // chip select, active low
    input  logic        rw,        // 1 = read, 0 = write
    input  logic        mode,      // with rw=1: 1 = parallel load, 0 = shift/read
    input  logic        clk,       // falling-edge clock
    input  logic [15:0] p,         // parallel data inputs P0..P15
    input  logic        si,        // SER/Q15 as serial input (write mode)
    output logic        q15        // SER/Q15 as serial output (MSB), 0 when not driven
);
    logic [15:0] sr;

    always_ff @(negedge clk) begin
        if (!cs_n) begin
            if (!rw)         sr <= {sr[14:0], si};      // shift and write
            else if (!mode)  sr <= {sr[14:0], sr[15]};  // shift and read (recirculate)
            else             sr <= p;                    // parallel load
        end
    end

    assign q15 = (!cs_n && rw) ? sr[15] : 1'b0;
endmodule
