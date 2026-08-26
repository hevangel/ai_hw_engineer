module cover_8253 #(
    parameter integer SCENARIO = 0
) (
    input logic clk
);

    localparam logic [6:0] CoverMask =
        (SCENARIO == 0) ? 7'b0000011 :
        (SCENARIO == 1) ? 7'b0000100 :
        (SCENARIO == 2) ? 7'b0001000 :
                          7'b1110000;

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
        rst_n = (step != 6'd0);
        cs_n = 1'b1;
        rd_n = 1'b1;
        wr_n = 1'b1;
        addr = 2'b00;
        data_i = 8'h00;
        counter_clk_i = 3'b111;
        gate_i = 3'b111;

        case (SCENARIO)
            0: begin
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
                    6'd3, 6'd5: begin
                        counter_clk_i[0] = 1'b0;
                    end
                    default: begin
                    end
                endcase
            end
            1: begin
                if (step < 6'd3) begin
                    gate_i[1] = 1'b0;
                end
                case (step)
                    6'd1: begin
                        cs_n = 1'b0;
                        wr_n = 1'b0;
                        addr = 2'b11;
                        data_i = 8'h52;
                    end
                    6'd2: begin
                        cs_n = 1'b0;
                        wr_n = 1'b0;
                        addr = 2'b01;
                        data_i = 8'h01;
                    end
                    6'd4: begin
                        counter_clk_i[1] = 1'b0;
                    end
                    default: begin
                    end
                endcase
            end
            2: begin
                case (step)
                    6'd1: begin
                        cs_n = 1'b0;
                        wr_n = 1'b0;
                        addr = 2'b11;
                        data_i = 8'h94;
                    end
                    6'd2: begin
                        cs_n = 1'b0;
                        wr_n = 1'b0;
                        addr = 2'b10;
                        data_i = 8'h02;
                    end
                    6'd3, 6'd5: begin
                        counter_clk_i[2] = 1'b0;
                    end
                    default: begin
                    end
                endcase
            end
            default: begin
                case (step)
                    6'd1: begin
                        cs_n = 1'b0;
                        wr_n = 1'b0;
                        addr = 2'b00;
                        data_i = 8'h01;
                    end
                    6'd2: begin
                        cs_n = 1'b0;
                        rd_n = 1'b0;
                        addr = 2'b00;
                    end
                    6'd3: begin
                        cs_n = 1'b0;
                        wr_n = 1'b0;
                        addr = 2'b11;
                        data_i = 8'hdc;
                    end
                    6'd4: begin
                        rst_n = 1'b0;
                    end
                    default: begin
                    end
                endcase
            end
        endcase
    end

    intel_8253_8254 #(
        .IS_8254 (1'b0)
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
        .IS_8254    (1'b0),
        .COVER_MASK (CoverMask)
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
