// ASSUMPTION: Z is represented by per-section flags; timing is not modeled.
module ttl_74x162646 (
    input  logic [15:0] a_in,
    input  logic [15:0] b_in,
    input  logic [1:0] oe_n,
    input  logic [1:0] dir,
    input  logic [1:0] clkab,
    input  logic [1:0] clkba,
    input  logic [1:0] sab,
    input  logic [1:0] sba,
    output logic [15:0] a_out,
    output logic [15:0] b_out,
    output logic [1:0] a_drive,
    output logic [1:0] b_drive
);
    logic [15:0] a_reg;
    logic [15:0] b_reg;

    for (genvar section = 0; section < 2; section++) begin : g_section
        localparam integer BASE = section * 8;
        always_ff @(posedge clkab[section])
            a_reg[BASE +: 8] <= a_in[BASE +: 8];
        always_ff @(posedge clkba[section])
            b_reg[BASE +: 8] <= b_in[BASE +: 8];
        always_comb begin
            a_drive[section] = !oe_n[section] && !dir[section];
            b_drive[section] = !oe_n[section] &&  dir[section];
            a_out[BASE +: 8] = a_drive[section]
                ? (sba[section] ? b_reg[BASE +: 8] : b_in[BASE +: 8]) : 8'h00;
            b_out[BASE +: 8] = b_drive[section]
                ? (sab[section] ? a_reg[BASE +: 8] : a_in[BASE +: 8]) : 8'h00;
        end
    end
endmodule
