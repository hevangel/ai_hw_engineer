module intel_8253_8254_props #(
    parameter bit IS_8254 = 1'b1
) (
    input logic       clk,
    input logic       rst_n,
    input logic       cs_n,
    input logic       rd_n,
    input logic       wr_n,
    input logic [1:0] addr,
    input logic [7:0] data_i,
    input logic [7:0] data_o,
    input logic       data_oe,
    input logic [2:0] out_o
);

    logic [1:0] shadow_rw [3];
    logic [2:0] shadow_mode [3];
    logic       shadow_bcd [3];
    logic       status_pending [3];
    logic [6:0] expected_status_without_null [3];
    integer     check_index;

    logic bus_read;
    logic bus_write;

    assign bus_read = !cs_n && !rd_n && wr_n;
    assign bus_write = !cs_n && rd_n && !wr_n;

    always_ff @(posedge clk) begin
        if ($initstate) begin
            assume (!rst_n);
        end

        assert (data_oe ==
                (bus_read && (addr != 2'b11)));
        if (!data_oe) begin
            assert (data_o == 8'h00);
        end

        if (!$initstate && $past(!rst_n)) begin
            assert (out_o == 3'b111);
        end

        if (!$initstate && $past(rst_n && bus_write &&
                                (addr == 2'b11) &&
                                (data_i[7:6] != 2'b11) &&
                                (data_i[5:4] != 2'b00))) begin
            case ($past(data_i[7:6]))
                2'b00: begin
                    if ($past(data_i[3:1]) == 3'd0) begin
                        assert (!out_o[0]);
                    end else begin
                        assert (out_o[0]);
                    end
                end
                2'b01: begin
                    if ($past(data_i[3:1]) == 3'd0) begin
                        assert (!out_o[1]);
                    end else begin
                        assert (out_o[1]);
                    end
                end
                2'b10: begin
                    if ($past(data_i[3:1]) == 3'd0) begin
                        assert (!out_o[2]);
                    end else begin
                        assert (out_o[2]);
                    end
                end
                default: begin
                end
            endcase
        end

        for (check_index = 0; check_index < 3;
             check_index = check_index + 1) begin
            if (!$initstate && status_pending[check_index] && bus_read &&
                (addr == check_index[1:0])) begin
                assert (data_o[7] ==
                        expected_status_without_null[check_index][6]);
                assert (data_o[5:0] ==
                        expected_status_without_null[check_index][5:0]);
            end
        end

        if (!rst_n) begin
            for (check_index = 0; check_index < 3;
                 check_index = check_index + 1) begin
                shadow_rw[check_index] <= 2'b11;
                shadow_mode[check_index] <= 3'b000;
                shadow_bcd[check_index] <= 1'b0;
                status_pending[check_index] <= 1'b0;
                expected_status_without_null[check_index] <= 7'h00;
            end
        end else begin
            for (check_index = 0; check_index < 3;
                 check_index = check_index + 1) begin
                if (bus_write && (addr == 2'b11) &&
                    (data_i[7:6] == check_index[1:0]) &&
                    (data_i[7:6] != 2'b11) &&
                    (data_i[5:4] != 2'b00)) begin
                    shadow_rw[check_index] <= data_i[5:4];
                    shadow_mode[check_index] <= data_i[3:1];
                    shadow_bcd[check_index] <= data_i[0];
                    status_pending[check_index] <= 1'b0;
                end

                if (IS_8254 && bus_write && (addr == 2'b11) &&
                    (data_i[7:6] == 2'b11) && !data_i[4] &&
                    !data_i[check_index + 1] &&
                    !status_pending[check_index]) begin
                    expected_status_without_null[check_index] <= {
                        out_o[check_index],
                        shadow_rw[check_index],
                        shadow_mode[check_index],
                        shadow_bcd[check_index]
                    };
                    status_pending[check_index] <= 1'b1;
                end

                if (bus_read && (addr == check_index[1:0]) &&
                    status_pending[check_index]) begin
                    status_pending[check_index] <= 1'b0;
                end
            end
        end
    end

endmodule
