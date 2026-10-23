// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x915.md.
// =============================================================================
// ttl_74x915 - 7-segment to BCD converter
//
// Original part number : 74x915 (MM54C915/MM74C915)
// Datasheet reference  : National MM54C915/MM74C915
//
// Function
// --------
// Accepts seven-segment information (segments a..g) and converts it to a 4-bit
// BCD value, with an on-chip output latch, three-state BCD outputs, and Error
// and Minus flags:
//
//   - invert : Invert/Non-invert control. 0 = active-high segment decoding
//     (a segment is "lit" at logic 1); 1 = active-low decoding (lit at 0).
//     Internally the seven segment inputs are complemented when invert = 1.
//   - The "true" 7-segment pattern is matched against the standard digit font
//     (here the library-canonical ttl_pkg::bcd_to_7seg, the same font the
//     '47/'48 decoders drive). A match yields the BCD digit (0-9).
//   - error : 1 when the segment pattern is not a standard 0-9 code.
//   - minus : 1 when the "minus" code (segment g only) is present.
//   - le  : output latch. 0 = flow-through (transparent), 1 = latched (hold).
//   - oe_n: output enable (active low). When high the BCD outputs are
//     three-stated; the BCD outputs are also three-stated whenever error = 1
//     (so the user may program an external error code). High-Z is modeled as 0.
//
// The datasheet specifies decoding of the "standard 7-segment code" without an
// explicit pattern table; this model uses the project-canonical font so that
// ttl_74x915 is the exact inverse of the ttl_74x47/'48 encoders.
//
// Pin mapping (18-pin): d=1,c=2,b=3,a=4, ERROR=5, /OE=6, A(2^0)=7, B(2^1)=8,
// GND=9, C(2^2)=10, D(2^3)=11, LE=12, MINUS=13, INVERT=14, e=15, f=16, g=17,
// Vcc=18.
//
// Unsupported physical behavior
// -----------------------------
// True three-state high-Z (modeled as driven 0); MOS-to-TTL level translation.
// =============================================================================

module ttl_74x915
(
    input  logic       a, b, c, d, e, f, g,  // segment inputs
    input  logic       invert,               // 0 = active-high, 1 = active-low decode
    input  logic       le,                   // latch: 0 = transparent, 1 = hold
    input  logic       oe_n,                 // output enable, active low (3-state)
    output logic [3:0] bcd,                  // BCD: bcd[0]=A(2^0) .. bcd[3]=D(2^3)
    output logic       error,
    output logic       minus
);
    function automatic [6:0] bcd_to_7seg(input [3:0] digit_code);
        case (digit_code)
            4'd0:    bcd_to_7seg = 7'b1111110; // a b c d e f
            4'd1:    bcd_to_7seg = 7'b0110000; //   b c
            4'd2:    bcd_to_7seg = 7'b1101101; // a b   d e   g
            4'd3:    bcd_to_7seg = 7'b1111001; // a b c d     g
            4'd4:    bcd_to_7seg = 7'b0110011; //   b c     f g
            4'd5:    bcd_to_7seg = 7'b1011011; // a   c d   f g
            4'd6:    bcd_to_7seg = 7'b1011111; // a   c d e f g
            4'd7:    bcd_to_7seg = 7'b1110000; // a b c
            4'd8:    bcd_to_7seg = 7'b1111111; // a b c d e f g
            4'd9:    bcd_to_7seg = 7'b1111011; // a b c d   f g
            default: bcd_to_7seg = 7'b0000000; // chips that need 0xA-0xF
                                               // patterns override this case
                                               // in their own RTL.
        endcase
    endfunction


    logic [6:0] segvec, tp;
    logic [3:0] digit;
    logic       valid;
    logic [3:0] bcd_lat;

    assign segvec = {a, b, c, d, e, f, g};       // {a..g}, a = MSB (matches font)
    assign tp     = invert ? ~segvec : segvec;   // "true" pattern

    always_comb begin
        digit = 4'd0;
        valid = 1'b0;
        for (int n = 0; n < 10; n++)
            if (tp == bcd_to_7seg(n[3:0])) begin
                digit = n[3:0];
                valid = 1'b1;
            end
    end

    assign error = ~valid;
    assign minus = (tp == 7'b0000001);           // segment g only

    // Output latch: transparent while le low, holds while le high. Only a valid
    // code updates the stored digit (an invalid code three-states the outputs).
    always_latch
        if (!le && valid) bcd_lat = digit;

    assign bcd = (oe_n || error) ? 4'b0000 : bcd_lat;
endmodule
