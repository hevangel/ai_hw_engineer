// ASSUMPTION: per the 1977 advance-information datasheet the MM74C913 is
// identical to the MM74C912 except that the decimal point path and the digit
// and segment tristate controls are omitted, so the scanner always runs and
// the outputs always drive. The ROM font is taken as the shipping MM74C912
// BCD font; addresses K=6,7 are null writes. External digital osc replaces
// the internal RC oscillator; analog timing is outside the contract.
module ttl_74x913 #(
    parameter int CYCLES_PER_DIGIT = 4  // active scan ticks per digit slot
) (
    input  logic [3:0] d,           // data inputs a-d (Dp omitted on 913)
    input  logic [2:0] k,           // digit address K1,K2,K3
    input  logic       ce_n,        // chip enable, active low
    input  logic       we_n,        // write enable, active low
    input  logic       osc,         // normalized scan clock
    output logic [5:0] digit,       // D1-D6, always driven
    output logic [6:0] seg          // Sa-Sg, ascending a..g, always driven
);
    logic [3:0] regfile [6];

    // CE=0 with WE=0 writes the K-selected register (transparent); the value
    // latches when either CE or WE returns high. K=6,7 write no register.
    always_latch begin
        if (!ce_n && !we_n && k < 3'd6) regfile[k] = d;
    end

    function automatic logic [6:0] font913(input logic [3:0] code);
        case (code)
            4'd0:    font913 = 7'b0111111;  // 0: abcdef
            4'd1:    font913 = 7'b0000110;  // 1: bc
            4'd2:    font913 = 7'b1011011;  // 2: abdeg
            4'd3:    font913 = 7'b1001111;  // 3: abcdg
            4'd4:    font913 = 7'b1100110;  // 4: bcfg
            4'd5:    font913 = 7'b1101101;  // 5: acdfg
            4'd6:    font913 = 7'b1111101;  // 6: acdefg
            4'd7:    font913 = 7'b0000111;  // 7: abc
            4'd8:    font913 = 7'b1111111;  // 8
            4'd9:    font913 = 7'b1101111;  // 9: abcdfg
            4'd10:   font913 = 7'b1011100;  // lower o: cdeg
            4'd11:   font913 = 7'b1100011;  // raised o: abfg
            4'd12:   font913 = 7'b0000001;  // top bar: a
            4'd13:   font913 = 7'b1000000;  // middle bar: g
            4'd14:   font913 = 7'b0001000;  // bottom bar: d
            default: font913 = 7'b0000000;  // blank
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
    always_ff @(posedge osc) begin       // no oscillator-enable pin on the 913
        if (tick >= 32'(CYCLES_PER_DIGIT)) begin
            tick       <= 32'd0;
            scan_digit <= (scan_digit == 3'd5) ? 3'd0 : scan_digit + 3'd1;
        end else begin
            tick <= tick + 32'd1;
        end
    end
    /* verilator lint_on MULTIDRIVEN */

    always_comb begin
        blank = (tick >= 32'(CYCLES_PER_DIGIT));
        digit = blank ? 6'b000000 : (6'b000001 << scan_digit);
        seg   = blank ? 7'b0000000 : font913(regfile[scan_digit]);
    end
endmodule
