// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74ls424.md.
// ttl_74ls424 - Two-phase clock generator/driver (Intel 8224 equivalent).
// Generates phi1 and phi2 non-overlapping clocks from an input clock.
module ttl_74ls424 (
    input  logic clk,
    input  logic rst,
    output logic phi1,
    output logic phi2,
    output logic reset_out
);
    logic [1:0] state;
    always_ff @(posedge clk or posedge rst) begin
        if (rst) state <= 2'b00;
        else     state <= state + 2'b01;
    end
    assign phi1      = (state == 2'b00);
    assign phi2      = (state == 2'b10);
    assign reset_out = rst;
endmodule
