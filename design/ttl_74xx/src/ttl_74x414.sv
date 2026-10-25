// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x414.md.
// ttl_74x414 - Interrupt priority controller (Intel 8214 equivalent).
// 8 active-low interrupt request inputs; outputs the BCD-encoded priority
// of the highest active request plus an enable strobe.
module ttl_74x414 (
    input  logic [7:0] r_n,             // request inputs (active low)
    input  logic       elr_n,           // enable level register input
    input  logic [2:0] b,                // priority threshold
    output logic [2:0] a,                // active level (priority of highest req)
    output logic       enable_out_n
);
    logic [2:0] highest;
    always_comb begin
        casez (r_n)
            8'b0???????: highest = 3'd7;
            8'b10??????: highest = 3'd6;
            8'b110?????: highest = 3'd5;
            8'b1110????: highest = 3'd4;
            8'b11110???: highest = 3'd3;
            8'b111110??: highest = 3'd2;
            8'b1111110?: highest = 3'd1;
            8'b11111110: highest = 3'd0;
            default:     highest = 3'd0;
        endcase
        a = highest;
        enable_out_n = (r_n == 8'hFF) || !elr_n || (highest <= b);
    end
endmodule
