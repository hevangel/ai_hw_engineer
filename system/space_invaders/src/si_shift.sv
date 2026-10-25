// Space Invaders hardware shift register. The 8080 lacks shift opcodes, so
// the board provides one: OUT 4 pushes a byte, OUT 2 bits 2-0 set the
// offset, IN 3 reads 8 bits starting at the offset (hardware page: write
// 00h then AAh then FFh -> 0000, AA00, FFAA; offset 0 reads xxxxxxxx,
// offset 7 reads xyyyyyyy).
module si_shift (
    input logic clk,
    input logic rst_n,
    input logic data_we,      // OUT 4: previous high byte moves to low
    input logic [7:0] data,   // ...new byte becomes the high byte
    input logic offset_we,    // OUT 2
    input logic [7:0] offset_bus, // bits 2-0 used
    output logic [15:0] shift_reg,
    output logic [2:0] shift_offset,
    output logic [7:0] result  // IN 3
);
    logic [15:0] reg16;
    logic [2:0] off;
    logic unused_off;
    assign unused_off = |offset_bus[7:3];
    assign shift_reg = reg16;
    assign shift_offset = off;
    logic [15:0] shifted;
    logic unused_shifthi;
    assign unused_shifthi = |shifted[15:8];
    assign shifted = reg16 >> (4'd8 - {1'b0, off});
    assign result = shifted[7:0];

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            reg16 <= 16'd0;
            off <= 3'd0;
        end else begin
            if (offset_we) off <= offset_bus[2:0];
            if (data_we) reg16 <= {data, reg16[15:8]};
        end
    end
endmodule
