// ASSUMPTION: Registered Z is exposed through drive flags; data is masked to zero.
module ttl_74x162268 (
    input  logic        clk,
    input  logic [11:0] a_in,
    input  logic [11:0] b1_in,
    input  logic [11:0] b2_in,
    input  logic        clkena1_n,
    input  logic        clkena2_n,
    input  logic        clken1b_n,
    input  logic        clken2b_n,
    input  logic        sel,
    input  logic        oea_n,
    input  logic        oeb_n,
    output logic [11:0] a_out,
    output logic [11:0] b1_out,
    output logic [11:0] b2_out,
    output logic        a_drive,
    output logic        b_drive
);
    logic [11:0] a_to_b1_stage1;
    logic [11:0] a_to_b1_stage2;
    logic [11:0] a_to_b2_stage;
    logic [11:0] b1_to_a_stage1;
    logic [11:0] b_to_a_stage2;
    logic        oea_q;
    logic        oeb_q;

    always_ff @(posedge clk) begin
        if (!clkena1_n) a_to_b1_stage1 <= a_in;
        if (!clkena2_n) begin
            a_to_b1_stage2 <= a_to_b1_stage1;
            a_to_b2_stage  <= a_in;
        end
        if (!clken1b_n) b1_to_a_stage1 <= b1_in;
        if (!clken2b_n) b_to_a_stage2 <= sel ? b1_to_a_stage1 : b2_in;
        oea_q <= !oea_n;
        oeb_q <= !oeb_n;
    end

    always_comb begin
        a_drive  = oea_q;
        b_drive  = oeb_q;
        a_out  = a_drive ? b_to_a_stage2 : 12'h000;
        b1_out = b_drive ? a_to_b1_stage2 : 12'h000;
        b2_out = b_drive ? a_to_b2_stage  : 12'h000;
    end
endmodule
