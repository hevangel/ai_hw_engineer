// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x673.md.
// =============================================================================
// ttl_74x673 - 16-bit serial-in, serial-out shift register with 16-bit
//              parallel-out storage register
//
// Original part number : 74x673 (SN74LS673)
// Datasheet reference  : TI SN54LS673/674, SN74LS673/674 (SDLS195)
//
// Function
// --------
// A 16-bit shift register plus a 16-bit storage register in one package,
// connected in a parallel data loop. A three-state serial port SER/Q15 enters
// and reads shift-register data; the storage register drives the parallel
// outputs Y0..Y15.
//
//   Shift register (falling edge of sh_clk, while cs_n = 0):
//     R/W = 0                : shift and write  (serial in via si)
//     R/W = 1, MODE = 0      : shift and read   (recirculating)
//     R/W = 1, MODE = 1      : parallel load the shift register from storage
//   Storage register:
//     strclr_n = 0           : asynchronous clear (independent of cs_n)
//     rising edge of mode_strclk, cs_n = 0, R/W = 0 : load storage from the
//                              shift register
//
// The mode_strclk pin is dual-purpose: as a LEVEL it is the shift-register
// MODE (shift vs parallel-load); a RISING EDGE on it clocks the storage
// register (the two uses are separated by R/W, so they never conflict).
//
//   q15 = (!cs_n && rw) ? sr[15] : 0     (SER/Q15 output; high-Z modeled 0)
//   y   = str                            (storage register outputs)
//
// FPGA notes
// ----------
// Two clock domains (sh_clk falling, mode_strclk rising). Storage clear is
// asynchronous. SER/Q15 split into si (in) / q15 (out) per library convention.
//
// Pin mapping (24-pin): CS=1, SH CLK=2, R/W=3, STRCLR=4, MODE/STRCLK=5,
// SER/Q15=6, Y0=7, Y1=8, Y2=9, Y3=10, Y4=11, GND=12, Y5=13, Y6=14, Y7=15,
// Y8=16, Y9=17, Y10=18, Y11=19, Y12=20, Y13=21, Y14=22, Y15=23, Vcc=24.
//
// Unsupported physical behavior
// -----------------------------
// True three-state high-Z on SER/Q15 (modeled as 0); SER/Q15 split into si/q15.
// =============================================================================

module ttl_74x673 (
    input  logic        cs_n,         // chip select, active low
    input  logic        rw,           // 1 = read, 0 = write
    input  logic        sh_clk,       // shift-register clock (falling edge)
    input  logic        strclr_n,     // storage clear, active low (async)
    input  logic        mode_strclk,  // level = shift-reg MODE; rising edge = storage clock
    input  logic        si,           // SER/Q15 as serial input (write mode)
    output logic        q15,          // SER/Q15 as serial output (shift-reg MSB)
    output logic [15:0] y             // storage-register outputs Y0..Y15
);
    logic [15:0] sr;     // shift register
    logic [15:0] str;    // storage register

    always_ff @(negedge sh_clk) begin
        if (!cs_n) begin
            if (!rw)               sr <= {sr[14:0], si};      // shift and write
            else if (!mode_strclk) sr <= {sr[14:0], sr[15]};  // shift and read (recirculate)
            else                   sr <= str;                  // parallel load from storage
        end
    end

    always_ff @(posedge mode_strclk or negedge strclr_n) begin
        if (!strclr_n)         str <= 16'd0;        // asynchronous clear
        else if (!cs_n && !rw) str <= sr;           // load storage from shift register
    end

    assign y   = str;
    assign q15 = (!cs_n && rw) ? sr[15] : 1'b0;
endmodule
