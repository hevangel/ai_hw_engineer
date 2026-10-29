// ASSUMPTION: external digital osc replaces the internal RC oscillator; analog
// RC timing, drive levels and propagation/hold times are outside the contract.
// digit_in must be driven by the board while digit_drive is 0. Scanner and
// register power-up state: scanner starts at digit 1 slot phase 0; registers
// are unspecified until written.
module ttl_74x911 #(
    parameter int CYCLES_PER_DIGIT = 4  // active scan ticks per digit slot
) (
    input  logic [7:0] d_in,       // data inputs a,b,c,d,e,f,g,dp (pins 2-9)
    input  logic [1:0] k,          // digit address K1,K2 (pins 26,27)
    input  logic       ce_n,       // chip enable, pin 28, active low
    input  logic       we_n,       // write enable, pin 1, active low
    input  logic       soe_n,      // segment output enable, pin 16, active low
    input  logic       dio_n,      // digit I/O control, pin 10, active low
    input  logic       osc,        // normalized scan clock
    input  logic [3:0] digit_in,   // observes D1-D4 while digit_drive is 0
    output logic [3:0] digit,      // D1-D4 (pins 15,14,13,12)
    output logic       digit_drive,
    output logic [7:0] seg,        // Sa..Sg,SDP (ascending bit order)
    output logic       seg_drive
);
    logic [7:0] regfile [4];

    // Input control truth table: CE=0 with WE=0 writes the K-selected register
    // (transparent); the value latches when either CE or WE returns high.
    always_latch begin
        if (!ce_n && !we_n) regfile[k] = d_in;
    end

    logic [1:0]  scan_digit;             // digit slot currently presented
    logic [31:0] tick;                   // tick within the slot; last is blank
    initial begin                  // defined model start; no reset pin exists
        scan_digit = 2'd0;
        tick       = 32'd0;
    end

    /* verilator lint_off MULTIDRIVEN */
    always_ff @(posedge osc) begin
        if (!dio_n) begin                // scanner runs only in refresh mode
            if (tick >= 32'(CYCLES_PER_DIGIT)) begin
                tick       <= 32'd0;
                scan_digit <= scan_digit + 2'd1;
            end else begin
                tick <= tick + 32'd1;
            end
        end
    end
    /* verilator lint_on MULTIDRIVEN */

    logic        blank, sel_valid, active;
    logic [1:0]  sel;
    always_comb begin
        blank       = (tick >= 32'(CYCLES_PER_DIGIT));
        digit_drive = !dio_n;
        sel_valid   = 1'b0;
        sel         = 2'd0;
        if (!dio_n) begin
            active = !blank;
            sel    = scan_digit;
            digit  = active ? (4'b0001 << scan_digit) : 4'b0000;
        end else begin
            digit     = 4'b0000;
            sel_valid = (digit_in != 4'b0000) && ((digit_in & (digit_in - 4'b0001)) == 4'b0000);
            sel       = digit_in[0] ? 2'd0 :
                        digit_in[1] ? 2'd1 :
                        digit_in[2] ? 2'd2 : 2'd3;
            active    = sel_valid;
        end
        seg_drive = active && !soe_n;
        seg       = seg_drive ? regfile[sel] : 8'b0000_0000;
    end
endmodule
