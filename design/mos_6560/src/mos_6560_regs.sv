module mos_6560_regs (
    input  logic         clk,
    input  logic         rst_n,
    input  logic         phi2_i,
    input  logic         rw_i,
    input  logic [13:0]  addr_i,
    input  logic [7:0]   data_i,
    input  logic [8:0]   raster_i,
    input  logic [7:0]   lightpen_x_i,
    input  logic [7:0]   lightpen_y_i,
    input  logic [7:0]   pot_x_i,
    input  logic [7:0]   pot_y_i,
    output logic [7:0]   data_o,
    output logic         data_oe_o,
    output logic [127:0] config_o
);
    logic selected;
    logic write_en;
    logic [127:0] config_q;
    // A7..A4 are physically unconnected to register selection (16 mirrors).
    logic unused_mirror;
    assign unused_mirror = ^addr_i[7:4];

    assign selected = addr_i[13:8] == 6'b010000;
    assign write_en = selected && phi2_i && !rw_i;
    assign config_o = config_q;
    assign data_oe_o = rst_n && selected && phi2_i && rw_i;

    always_ff @(posedge clk) begin
        // ASSUMPTION: platform initialization, not a physical CPU-reset pin.
        // ASSUMPTION: clk samples completion of a clean PHI2 bus access.
        if (!rst_n) begin
            config_q <= '0;
        end else if (write_en) begin
            case (addr_i[3:0])
                4'h0: config_q[0 +: 8] <= data_i;
                4'h1: config_q[8 +: 8] <= data_i;
                4'h2: config_q[16 +: 8] <= data_i;
                4'h3: config_q[24 +: 8] <= {1'b0, data_i[6:0]};
                4'h5: config_q[40 +: 8] <= data_i;
                4'ha: config_q[80 +: 8] <= data_i;
                4'hb: config_q[88 +: 8] <= data_i;
                4'hc: config_q[96 +: 8] <= data_i;
                4'hd: config_q[104 +: 8] <= data_i;
                4'he: config_q[112 +: 8] <= data_i;
                4'hf: config_q[120 +: 8] <= data_i;
                default: begin end
            endcase
        end
    end

    always_comb begin
        data_o = 8'h00;
        if (data_oe_o) begin
            case (addr_i[3:0])
                4'h3: data_o = {raster_i[0], config_q[30:24]};
                4'h4: data_o = raster_i[8:1];
                4'h6: data_o = lightpen_x_i;
                4'h7: data_o = lightpen_y_i;
                4'h8: data_o = pot_x_i;
                4'h9: data_o = pot_y_i;
                default: data_o = config_q[8 * addr_i[3:0] +: 8];
            endcase
        end
    end

`ifdef FORMAL
    `include "mos_6560_regs_props.sv"
`endif
endmodule
