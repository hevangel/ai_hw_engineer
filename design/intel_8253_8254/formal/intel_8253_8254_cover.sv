module intel_8253_8254_cover #(
    parameter bit         IS_8254    = 1'b1,
    parameter logic [6:0] COVER_MASK = 7'h7f
) (
    input logic       clk,
    input logic       rst_n,
    input logic       cs_n,
    input logic       rd_n,
    input logic       wr_n,
    input logic [1:0] addr,
    input logic [7:0] data_i,
    input logic       data_oe,
    input logic [2:0] out_o
);

    logic saw_mode0_program;
    logic saw_mode0_low;
    logic saw_mode1_program;
    logic saw_mode2_program;
    logic saw_mode2_low;
    logic saw_count_write;
    logic saw_readback;
    logic saw_later_reset;

    logic bus_read;
    logic bus_write;

    assign bus_read = !cs_n && !rd_n && wr_n;
    assign bus_write = !cs_n && rd_n && !wr_n;

    always_ff @(posedge clk) begin
        if ($initstate) begin
            assume (!rst_n);
        end

        if (!rst_n) begin
            saw_mode0_program <= 1'b0;
            saw_mode0_low <= 1'b0;
            saw_mode1_program <= 1'b0;
            saw_mode2_program <= 1'b0;
            saw_mode2_low <= 1'b0;
            saw_count_write <= 1'b0;
            saw_readback <= 1'b0;
            if (!$initstate) begin
                saw_later_reset <= 1'b1;
            end else begin
                saw_later_reset <= 1'b0;
            end
        end else begin
            if (bus_write && (addr == 2'b11) &&
                (data_i[7:6] == 2'b00) &&
                (data_i[5:4] != 2'b00) &&
                (data_i[3:1] == 3'd0)) begin
                saw_mode0_program <= 1'b1;
            end
            if (saw_mode0_program && !out_o[0]) begin
                saw_mode0_low <= 1'b1;
            end
            if (bus_write && (addr == 2'b11) &&
                (data_i[7:6] == 2'b01) &&
                (data_i[5:4] != 2'b00) &&
                (data_i[3:1] == 3'd1)) begin
                saw_mode1_program <= 1'b1;
            end
            if (bus_write && (addr == 2'b11) &&
                (data_i[7:6] == 2'b10) &&
                (data_i[5:4] != 2'b00) &&
                ((data_i[3:1] == 3'd2) ||
                 (data_i[3:1] == 3'd6))) begin
                saw_mode2_program <= 1'b1;
            end
            if (saw_mode2_program && !out_o[2]) begin
                saw_mode2_low <= 1'b1;
            end
            if (bus_write && (addr != 2'b11)) begin
                saw_count_write <= 1'b1;
            end
            if (IS_8254 && bus_write && (addr == 2'b11) &&
                (data_i[7:6] == 2'b11)) begin
                saw_readback <= 1'b1;
            end
        end

        if (!$initstate) begin
            if (COVER_MASK[0]) begin
                cover (saw_mode0_program && !out_o[0]);
            end
            if (COVER_MASK[1]) begin
                cover (saw_mode0_low && out_o[0]);
            end
            if (COVER_MASK[2]) begin
                cover (saw_mode1_program && !out_o[1]);
            end
            if (COVER_MASK[3]) begin
                cover (saw_mode2_low);
            end
            if (COVER_MASK[4]) begin
                cover (saw_count_write && bus_read && data_oe);
            end
            if (COVER_MASK[5]) begin
                cover (saw_later_reset && rst_n);
            end
            if (COVER_MASK[6]) begin
                if (IS_8254) begin
                    cover (saw_readback && bus_read && data_oe);
                end else begin
                    cover (bus_write && (addr == 2'b11) &&
                           (data_i[7:6] == 2'b11));
                end
            end
        end
    end

endmodule
