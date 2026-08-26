module cover_8254 (
    input logic clk
);

    logic [5:0] step = 6'd0;
    logic       rst_n;
    logic       cs_n;
    logic       rd_n;
    logic       wr_n;
    logic [1:0] addr;
    logic [7:0] data_i;
    logic [7:0] data_o;
    logic       data_oe;
    logic [2:0] counter_clk_i;
    logic [2:0] gate_i;
    logic [2:0] out_o;

    always_ff @(posedge clk) begin
        step <= step + 6'd1;
    end

    always_comb begin
        rst_n = (step != 6'd0) && (step != 6'd13);
        cs_n = 1'b1;
        rd_n = 1'b1;
        wr_n = 1'b1;
        addr = 2'b00;
        data_i = 8'h00;
        counter_clk_i = 3'b111;
        gate_i = 3'b111;

        case (step)
            6'd1: begin
                cs_n = 1'b0;
                wr_n = 1'b0;
                addr = 2'b11;
                data_i = 8'h10;
            end
            6'd2: begin
                cs_n = 1'b0;
                wr_n = 1'b0;
                addr = 2'b00;
                data_i = 8'h01;
            end
            6'd3: begin
                cs_n = 1'b0;
                wr_n = 1'b0;
                addr = 2'b11;
                data_i = 8'h52;
                counter_clk_i[0] = 1'b0;
            end
            6'd4: begin
                cs_n = 1'b0;
                wr_n = 1'b0;
                addr = 2'b01;
                data_i = 8'h01;
                gate_i[1] = 1'b0;
            end
            6'd5: begin
                cs_n = 1'b0;
                wr_n = 1'b0;
                addr = 2'b11;
                data_i = 8'h94;
                counter_clk_i[0] = 1'b0;
            end
            6'd6: begin
                cs_n = 1'b0;
                wr_n = 1'b0;
                addr = 2'b10;
                data_i = 8'h02;
            end
            6'd7, 6'd9: begin
                counter_clk_i[1] = 1'b0;
                counter_clk_i[2] = 1'b0;
            end
            6'd10, 6'd12: begin
                cs_n = 1'b0;
                rd_n = 1'b0;
                addr = 2'b00;
            end
            6'd11: begin
                cs_n = 1'b0;
                wr_n = 1'b0;
                addr = 2'b11;
                data_i = 8'hdc;
            end
            default: begin
            end
        endcase
    end

    intel_8253_8254 #(
        .IS_8254 (1'b1)
    ) dut (
        .clk           (clk),
        .rst_n         (rst_n),
        .cs_n          (cs_n),
        .rd_n          (rd_n),
        .wr_n          (wr_n),
        .addr          (addr),
        .data_i        (data_i),
        .data_o        (data_o),
        .data_oe       (data_oe),
        .counter_clk_i (counter_clk_i),
        .gate_i        (gate_i),
        .out_o         (out_o)
    );

    intel_8253_8254_cover #(
        .IS_8254 (1'b1)
    ) coverage (
        .clk     (clk),
        .rst_n   (rst_n),
        .cs_n    (cs_n),
        .rd_n    (rd_n),
        .wr_n    (wr_n),
        .addr    (addr),
        .data_i  (data_i),
        .data_oe (data_oe),
        .out_o   (out_o)
    );

endmodule
