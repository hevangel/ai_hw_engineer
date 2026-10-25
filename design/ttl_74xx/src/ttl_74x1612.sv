// ASSUMPTION: shared library UBT abstraction - one state element per direction
// tracks its input while LE is high and holds the last transparent value after
// LE falls; native qualified LE transitions are not separately observable.
// Register contents power up unspecified. The B port is open-drain GTLP: the
// 18-bit b_drive mask indicates which pins are actively sunk low.
module ttl_74x1612 (
    input  logic [17:0] a_in,
    input  logic [17:0] b_in,
    input  logic        oeab_n,
    input  logic        oeba_n,
    input  logic        ceab,
    input  logic        ceba,
    input  logic        leab,
    input  logic        leba,
    input  logic        clkab,
    input  logic        clkba,
    output logic [17:0] a_out,
    output logic [17:0] a_drive,
    output logic [17:0] b_drive
);
    logic ab_enable;
    logic ba_enable;
    logic [17:0] state_ab;
    logic [17:0] state_ba;

    assign ab_enable = !oeab_n;
    assign ba_enable = !oeba_n;

    for (genvar bit_index = 0; bit_index < 18; bit_index++) begin : g_ab
        logic set_bit;
        logic clear_bit;
        logic state;

        assign set_bit = leab && a_in[bit_index];
        assign clear_bit = leab && !a_in[bit_index];

        always_ff @(posedge clkab or posedge set_bit or posedge clear_bit) begin
            if (clear_bit)
                state <= 1'b0;
            else if (set_bit)
                state <= 1'b1;
            else if (!ceab)
                state <= a_in[bit_index];
        end
        assign state_ab[bit_index] = state;
    end

    for (genvar bit_index = 0; bit_index < 18; bit_index++) begin : g_ba
        logic set_bit;
        logic clear_bit;
        logic state;

        assign set_bit = leba && b_in[bit_index];
        assign clear_bit = leba && !b_in[bit_index];

        always_ff @(posedge clkba or posedge set_bit or posedge clear_bit) begin
            if (clear_bit)
                state <= 1'b0;
            else if (set_bit)
                state <= 1'b1;
            else if (!ceba)
                state <= b_in[bit_index];
        end
        assign state_ba[bit_index] = state;
    end

    always_comb begin
        a_drive = '0;
        a_out = '0;
        b_drive = '0;
        if (ba_enable) begin
            a_drive = '1;
            a_out = state_ba;
        end
        if (ab_enable)
            b_drive = ~state_ab;
    end
endmodule
