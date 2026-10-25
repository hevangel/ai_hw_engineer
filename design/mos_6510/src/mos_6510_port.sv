module mos_6510_port #(
    parameter int unsigned PORT_FALLOFF_CYCLES = 350000
) (
    input logic clk, rst_n, write_i, address_i,
    input logic [7:0] data_i,
    input logic [5:0] port_i,
    output logic [7:0] data_o, ddr_o, latch_o,
    output logic [5:0] port_o, port_oe
);
    localparam int CW = PORT_FALLOFF_CYCLES < 1 ? 1 : $clog2(PORT_FALLOFF_CYCLES+1);
    logic [7:0] ddr_q, data_q;
    logic [1:0] charge_q;
    logic [CW-1:0] remaining_q [0:1];
    logic [7:0] pin_values;
    assign ddr_o = ddr_q;
    assign latch_o = data_q;
    assign port_o = data_q[5:0];
    assign port_oe = ddr_q[5:0];
    assign pin_values = {charge_q[1] && remaining_q[1] != 0,
                         charge_q[0] && remaining_q[0] != 0, port_i};
    assign data_o = address_i ? ((data_q & ddr_q) | (pin_values & ~ddr_q)) : ddr_q;
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            // ASSUMPTION: VICE C64 reset profile; MAME differs. See spec.
            ddr_q <= 0; data_q <= 0; charge_q <= 0;
            remaining_q[0] <= 0; remaining_q[1] <= 0;
        end else begin
            for (int bit_number = 0; bit_number < 2; bit_number++) begin
                // ASSUMPTION: deterministic sampled charge/falloff, not an
                // electrical model or a universal NMOS die decay constant.
                if (ddr_q[bit_number+6]) begin
                    charge_q[bit_number] <= data_q[bit_number+6];
                    remaining_q[bit_number] <= CW'(PORT_FALLOFF_CYCLES);
                    if (write_i && address_i) charge_q[bit_number] <= data_i[bit_number+6];
                end else if (remaining_q[bit_number] != 0)
                    remaining_q[bit_number] <= remaining_q[bit_number]-1'b1;
                else charge_q[bit_number] <= 0;
            end
            if (write_i) begin
                if (address_i) data_q <= data_i;
                else ddr_q <= data_i;
            end
        end
    end
`ifdef FORMAL
    `include "mos_6510_port_props.sv"
`endif
endmodule
