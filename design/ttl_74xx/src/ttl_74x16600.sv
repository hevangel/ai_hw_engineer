module ttl_74x16600 (
    input  logic [17:0] a_in,
    input  logic [17:0] b_in,
    input  logic        oeab_n,
    input  logic        oeba_n,
    input  logic        leab,
    input  logic        leba,
    input  logic        clkab_n,
    input  logic        clkba_n,
    input  logic        clkenab_n,
    input  logic        clkenba_n,
    output logic [17:0] a_out,
    output logic [17:0] b_out,
    output logic        ab_drive,
    output logic        ba_drive
);
    assign ab_drive = !oeab_n;
    assign ba_drive = !oeba_n;

    for (genvar bit_index = 0; bit_index < 18; bit_index++) begin : g_ab
        logic set_bit;
        logic clear_bit;
        logic state;

        assign set_bit = leab && a_in[bit_index];
        assign clear_bit = leab && !a_in[bit_index];

        always_ff @(negedge clkab_n or posedge set_bit or posedge clear_bit) begin
            if (clear_bit)
                state <= 1'b0;
            else if (set_bit)
                state <= 1'b1;
            else if (!clkenab_n)
                state <= a_in[bit_index];
        end

        always_comb begin
            if (ab_drive)
                b_out[bit_index] = leab ? a_in[bit_index] : state;
            else
                b_out[bit_index] = 1'b0;
        end
    end

    for (genvar bit_index = 0; bit_index < 18; bit_index++) begin : g_ba
        logic set_bit;
        logic clear_bit;
        logic state;

        assign set_bit = leba && b_in[bit_index];
        assign clear_bit = leba && !b_in[bit_index];

        always_ff @(negedge clkba_n or posedge set_bit or posedge clear_bit) begin
            if (clear_bit)
                state <= 1'b0;
            else if (set_bit)
                state <= 1'b1;
            else if (!clkenba_n)
                state <= b_in[bit_index];
        end

        always_comb begin
            if (ba_drive)
                a_out[bit_index] = leba ? b_in[bit_index] : state;
            else
                a_out[bit_index] = 1'b0;
        end
    end
endmodule
