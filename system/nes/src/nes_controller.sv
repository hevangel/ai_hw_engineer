// Standard controller: CD4021 parallel-in/serial-out shift register as seen
// through the console's inverting buffer (1 = pressed). OUT0 high loads the
// buttons continuously; each $4016/$4017 read cycle clocks one bit out and
// shifts a 1 in (official pads read 1 after the eighth button).
// ASSUMPTION: at power-on the 4021 holds "no buttons" (reads 0 until the
// first strobe), as if latched with the pad idle.
module nes_controller (
    input  logic cpu_clk, rst_n,
    input  logic strobe_i,        // OUT0
    input  logic clock_i,         // read cycle of this port completes
    input  logic [7:0] buttons_i, // {Right, Left, Down, Up, Start, Select, B, A}
    output logic data_o
);
    logic [7:0] shift;
    assign data_o = strobe_i ? buttons_i[0] : shift[0];
    always_ff @(posedge cpu_clk) begin
        if (!rst_n) shift <= 8'h00;
        else if (strobe_i) shift <= buttons_i;
        else if (clock_i) shift <= {1'b1, shift[7:1]};
    end
endmodule
