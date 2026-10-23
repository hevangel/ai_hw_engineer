// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x350.md.
// ttl_74x350 - 4-bit shifter (barrel shifter).
// Shifts d right by shift_amt (0..3) with serial input din filling vacated MSBs.
module ttl_74x350 (
    input  logic [3:0] d,
    input  logic [1:0] shift_amt,
    input  logic       din,
    output logic [3:0] y
);
    always_comb begin
        case (shift_amt)
            2'd0: y = d;
            2'd1: y = {din, d[3:1]};
            2'd2: y = {din, din, d[3:2]};
            2'd3: y = {din, din, din, d[3]};
        endcase
    end
endmodule
