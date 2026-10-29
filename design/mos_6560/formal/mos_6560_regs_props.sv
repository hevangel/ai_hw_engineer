logic past_valid = 1'b0;
always_ff @(posedge clk) begin
    past_valid <= 1'b1;
    if (!past_valid) assume (!rst_n);
    if (past_valid) begin
        assert (data_oe_o == (rst_n && phi2_i && rw_i &&
                             addr_i[13:8] == 6'b010000));
        if (!data_oe_o) assert (data_o == 0);
        if (!$past(rst_n)) assert (config_q == 0);
        assert (config_q[31] == 0);
        assert (config_q[39:32] == 0);
        assert (config_q[79:48] == 0);
        if (data_oe_o) begin
            case (addr_i[3:0])
                3: assert (data_o == {raster_i[0], config_q[30:24]});
                4: assert (data_o == raster_i[8:1]);
                6: assert (data_o == lightpen_x_i);
                7: assert (data_o == lightpen_y_i);
                8: assert (data_o == pot_x_i);
                9: assert (data_o == pot_y_i);
                default: assert (data_o == config_q[8 * addr_i[3:0] +: 8]);
            endcase
        end
        cover (rst_n && data_oe_o && addr_i == 14'h10f3 && raster_i == 9'h1ff);
        cover (rst_n && data_oe_o && addr_i[3:0] == 6 && data_o == 8'ha5);
        cover (rst_n && data_oe_o && addr_i[3:0] == 8 && data_o == 8'h5a);
        cover (rst_n && !data_oe_o && phi2_i && rw_i && addr_i == 14'h1100);
        cover (rst_n && config_q[127:120] == 8'ha5 && config_q[23:16] == 8'h5a);
    end
end

for (genvar r = 0; r < 16; r = r + 1) begin : storage_properties
    if (r != 4 && r != 6 && r != 7 && r != 8 && r != 9) begin : writable
        always_ff @(posedge clk) begin
            if (past_valid && $past(rst_n)) begin
                if ($past(write_en && addr_i[3:0] == r)) begin
                    if (r == 3)
                        assert (config_q[8*r +: 8] == {1'b0, $past(data_i[6:0])});
                    else
                        assert (config_q[8*r +: 8] == $past(data_i));
                end else begin
                    assert (config_q[8*r +: 8] == $past(config_q[8*r +: 8]));
                end
            end
        end
    end
end
