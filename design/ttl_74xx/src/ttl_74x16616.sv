// ASSUMPTION: shared library UBT abstraction identical to the '16601 function
// (native qualified LE transitions are not separately observable); register
// contents power up unspecified. CLKIN observes the resolved external GTL
// clock bus (board models must connect it to the resolved CLKOUT net, not an
// independent clock); the internal CLKIN-to-LVTTL destination beyond that
// observation is not separately pinned in the SCBS481H function table.
// CLKOUT is an open-drain copy of CLKAB enabled by OEAB: clkout_sink indicates
// an active low sink on the GTL clock bus.
module ttl_74x16616 (
    input  logic [16:0] a_in,
    input  logic [16:0] b_in,
    input  logic        oeab_n,
    input  logic        oeba_n,
    input  logic        ceab_n,
    input  logic        ceba_n,
    input  logic        leab,
    input  logic        leba,
    input  logic        clkab,
    input  logic        clkba,
    // CLKIN is a deliberate observation input only (see ASSUMPTION above).
    /* verilator lint_off UNUSEDSIGNAL */
    input  logic        clkin,
    /* verilator lint_on UNUSEDSIGNAL */
    output logic [16:0] a_out,
    output logic [16:0] a_drive,
    output logic [16:0] b_drive,
    output logic        clkout_sink
);
    logic ab_enable;
    logic ba_enable;
    logic [16:0] state_ab;
    logic [16:0] state_ba;

    assign ab_enable = !oeab_n;
    assign ba_enable = !oeba_n;

    for (genvar bit_index = 0; bit_index < 17; bit_index++) begin : g_ab
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
            else if (!ceab_n)
                state <= a_in[bit_index];
        end
        assign state_ab[bit_index] = state;
    end

    for (genvar bit_index = 0; bit_index < 17; bit_index++) begin : g_ba
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
            else if (!ceba_n)
                state <= b_in[bit_index];
        end
        assign state_ba[bit_index] = state;
    end

    always_comb begin
        a_drive = '0;
        a_out = '0;
        b_drive = '0;
        clkout_sink = 1'b0;
        if (ba_enable) begin
            a_drive = '1;
            a_out = state_ba;
        end
        if (ab_enable)
            b_drive = ~state_ab;
        clkout_sink = ab_enable && clkab;
    end
endmodule
