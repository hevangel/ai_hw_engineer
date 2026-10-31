// ASSUMPTION: High-impedance outputs use explicit drive flags and masked data.
module ttl_74x162260 (
    input  logic [11:0] a_in,
    input  logic [11:0] b1_in,
    input  logic [11:0] b2_in,
    input  logic        sel,
    input  logic        le1b,
    input  logic        le2b,
    input  logic        lea1b,
    input  logic        lea2b,
    input  logic        oea_n,
    input  logic        oe1b_n,
    input  logic        oe2b_n,
    output logic [11:0] a_out,
    output logic [11:0] b1_out,
    output logic [11:0] b2_out,
    output logic        a_drive,
    output logic        b1_drive,
    output logic        b2_drive
);
    logic [11:0] a_to_b1_latch;
    logic [11:0] a_to_b2_latch;
    logic [11:0] b1_to_a_latch;
    logic [11:0] b2_to_a_latch;

    // The datasheet specifies level-transparent latches, high-transparent.
    always_latch begin
        if (lea1b) a_to_b1_latch = a_in;
        if (lea2b) a_to_b2_latch = a_in;
        if (le1b) b1_to_a_latch = b1_in;
        if (le2b) b2_to_a_latch = b2_in;
    end

    always_comb begin
        a_drive  = !oea_n;
        b1_drive = !oe1b_n;
        b2_drive = !oe2b_n;
        a_out  = a_drive  ? (sel ? b1_to_a_latch : b2_to_a_latch) : 12'h000;
        b1_out = b1_drive ? a_to_b1_latch : 12'h000;
        b2_out = b2_drive ? a_to_b2_latch : 12'h000;
    end
endmodule
