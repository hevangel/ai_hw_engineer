// ASSUMPTION: external digital osc replaces the internal RC oscillator; analog
// RC timing, drive levels and propagation times are outside the contract.
// Addresses K=6,7 are "Null Digit" writes: no register is affected. Scanner
// starts at digit 1 slot phase 0; registers are unspecified until written.
module ttl_74x912 #(
    parameter int CYCLES_PER_DIGIT = 4  // active scan ticks per digit slot
) (
    input  logic [3:0] d,           // data inputs A-D (pins 6,5,4,3; A=2^0)
    input  logic       dp,          // decimal point input, pin 7
    input  logic [2:0] k,           // digit address K1,K2,K3 (pins 26-28)
    input  logic       ce_n,        // chip enable, pin 1, active low
    input  logic       we_n,        // write enable, pin 2, active low
    input  logic       ose_n,       // oscillator enable, pin 8, active low
    input  logic       soe_n,       // segment output enable, pin 16, active low
    input  logic       osc,         // normalized scan clock
    output logic [5:0] digit,       // D1-D6 (pins 14-9), always driven
    output logic       digit_drive,
    output logic [6:0] seg,         // Sa-Sg (pins 17-19,21-24), ascending a..g
    output logic       seg_dp,      // Sdp, pin 25
    output logic       seg_drive
);
    logic [4:0] regfile [6];

    // CE=0 with WE=0 writes the K-selected register (transparent); the value
    // latches when either CE or WE returns high. K=6,7 write no register.
    always_latch begin
        if (!ce_n && !we_n && k < 3'd6) regfile[k] = {dp, d};
    end

    function automatic logic [6:0] font912(input logic [3:0] code);
        case (code)
            4'd0:    font912 = 7'b0111111;  // 0: abcdef
            4'd1:    font912 = 7'b0000110;  // 1: bc
            4'd2:    font912 = 7'b1011011;  // 2: abdeg
            4'd3:    font912 = 7'b1001111;  // 3: abcdg
            4'd4:    font912 = 7'b1100110;  // 4: bcfg
            4'd5:    font912 = 7'b1101101;  // 5: acdfg
            4'd6:    font912 = 7'b1111101;  // 6: acdefg
            4'd7:    font912 = 7'b0000111;  // 7: abc
            4'd8:    font912 = 7'b1111111;  // 8
            4'd9:    font912 = 7'b1101111;  // 9: abcdfg
            4'd10:   font912 = 7'b1011100;  // lower o: cdeg
            4'd11:   font912 = 7'b1100011;  // raised o: abfg
            4'd12:   font912 = 7'b0000001;  // top bar: a
            4'd13:   font912 = 7'b1000000;  // middle bar: g
            4'd14:   font912 = 7'b0001000;  // bottom bar: d
            default: font912 = 7'b0000000;  // blank
        endcase
    endfunction

    logic [2:0]  scan_digit;         // digit slot currently presented (0-5)
    logic [31:0] tick;                   // tick within the slot; last is blank
    logic        blank;
    initial begin                  // defined model start; no reset pin exists
        scan_digit = 3'd0;
        tick       = 32'd0;
    end

    /* verilator lint_off MULTIDRIVEN */
    always_ff @(posedge osc) begin
        if (!ose_n) begin                // oscillator enable gates the scan
            if (tick >= 32'(CYCLES_PER_DIGIT)) begin
                tick       <= 32'd0;
                scan_digit <= (scan_digit == 3'd5) ? 3'd0 : scan_digit + 3'd1;
            end else begin
                tick <= tick + 32'd1;
            end
        end
    end
    /* verilator lint_on MULTIDRIVEN */

    always_comb begin
        blank       = !ose_n && (tick >= 32'(CYCLES_PER_DIGIT));
        digit_drive = 1'b1;
        digit       = blank ? 6'b000000 : (6'b000001 << scan_digit);
        seg_drive   = !soe_n && !blank;
        seg         = seg_drive ? font912(regfile[scan_digit][3:0]) : 7'b0000000;
        seg_dp      = seg_drive && regfile[scan_digit][4];
    end
endmodule
