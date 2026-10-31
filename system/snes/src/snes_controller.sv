// Standard SNES controller (SHVC-005): a 16-bit parallel-in shift register.
// Order out: B, Y, Select, Start, Up, Down, Left, Right, A, X, L, R, then
// four 0 ID bits, then 1s. Data is reported as 1 = pressed (the console
// inverts the open-collector line).
module snes_controller (
    input  logic clk,
    input  logic rst_n,
    input  logic latch_i,
    input  logic clock_i,                // one-clock shift pulse
    input  logic [11:0] buttons_i,       // {R, L, X, A, Right, Left, Down, Up, Start, Select, Y, B}
    output logic data_o
);
    logic [15:0] sr;
    always_ff @(posedge clk) begin
        if (!rst_n) sr <= 16'h0000;
        else if (latch_i) sr <= {4'h0, buttons_i};
        else if (clock_i) sr <= {1'b1, sr[15:1]};
    end
    assign data_o = latch_i ? buttons_i[0] : sr[0];
endmodule
