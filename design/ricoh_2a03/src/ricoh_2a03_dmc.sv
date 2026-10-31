// APU delta-modulation channel with its sample memory reader.
module ricoh_2a03_dmc #(
    parameter bit PAL = 1'b0
) (
    input  logic clk, rst_n,
    input  logic apu_tick_i,
    input  logic wr_i,            // $4010-$4013 write
    input  logic [1:0] reg_i,
    input  logic [7:0] data_i,
    input  logic status_wr_i,     // $4015 write
    input  logic enable_i,        // $4015 bit 4 (valid with status_wr_i)
    output logic dma_req_o,       // sample buffer empty, bytes remain
    output logic [15:0] dma_addr_o,
    input  logic dma_done_i,      // get cycle completes this edge
    input  logic [7:0] dma_data_i,
    output logic active_o,        // bytes remaining
    output logic irq_o,
    output logic [6:0] out_o
);
    // DMC output-unit period in CPU cycles.
    function automatic logic [8:0] dmc_period(input logic pal, input logic [3:0] index);
        if (!pal) begin
            case (index)
                4'd0: dmc_period = 9'd428;  4'd1: dmc_period = 9'd380;
                4'd2: dmc_period = 9'd340;  4'd3: dmc_period = 9'd320;
                4'd4: dmc_period = 9'd286;  4'd5: dmc_period = 9'd254;
                4'd6: dmc_period = 9'd226;  4'd7: dmc_period = 9'd214;
                4'd8: dmc_period = 9'd190;  4'd9: dmc_period = 9'd160;
                4'd10: dmc_period = 9'd142; 4'd11: dmc_period = 9'd128;
                4'd12: dmc_period = 9'd106; 4'd13: dmc_period = 9'd84;
                4'd14: dmc_period = 9'd72;  default: dmc_period = 9'd54;
            endcase
        end else begin
            case (index)
                4'd0: dmc_period = 9'd398;  4'd1: dmc_period = 9'd354;
                4'd2: dmc_period = 9'd316;  4'd3: dmc_period = 9'd298;
                4'd4: dmc_period = 9'd276;  4'd5: dmc_period = 9'd236;
                4'd6: dmc_period = 9'd210;  4'd7: dmc_period = 9'd198;
                4'd8: dmc_period = 9'd176;  4'd9: dmc_period = 9'd148;
                4'd10: dmc_period = 9'd132; 4'd11: dmc_period = 9'd118;
                4'd12: dmc_period = 9'd98;  4'd13: dmc_period = 9'd78;
                4'd14: dmc_period = 9'd66;  default: dmc_period = 9'd50;
            endcase
        end
    endfunction
    logic irq_en, loop;
    logic [3:0] rate;
    logic [7:0] start_reg, length_reg;
    logic [15:0] addr;
    logic [11:0] bytes;
    logic [7:0] buffer, shifter;
    logic buffer_full, silence;
    logic [3:0] bits;
    logic [7:0] timer;
    logic [6:0] level;
    /* verilator lint_off UNUSEDSIGNAL */
    logic [8:0] reload_cycles;    // every table entry is even
    /* verilator lint_on UNUSEDSIGNAL */

    assign reload_cycles = dmc_period(PAL, rate);
    assign dma_req_o = !buffer_full && bytes != 0;
    assign dma_addr_o = addr;
    assign active_o = bytes != 0;
    assign out_o = level;

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            irq_en <= 1'b0; loop <= 1'b0; rate <= '0; start_reg <= '0; length_reg <= '0;
            addr <= 16'hc000; bytes <= '0; buffer <= '0; shifter <= '0; buffer_full <= 1'b0;
            silence <= 1'b1; bits <= 4'd8; timer <= '0; level <= '0; irq_o <= 1'b0;
        end else begin
            // Output unit, clocked by the rate timer.
            if (apu_tick_i) begin
                if (timer == 0) begin
                    timer <= reload_cycles[8:1] - 8'd1;
                    if (!silence) begin
                        if (shifter[0]) begin
                            if (level <= 7'd125) level <= level + 7'd2;
                        end else if (level >= 7'd2) level <= level - 7'd2;
                    end
                    shifter <= shifter >> 1;
                    if (bits == 4'd1) begin
                        bits <= 4'd8;
                        if (buffer_full) begin
                            silence <= 1'b0; shifter <= buffer; buffer_full <= 1'b0;
                        end else silence <= 1'b1;
                    end else bits <= bits - 4'd1;
                end else timer <= timer - 8'd1;
            end
            // Memory reader.
            if (dma_done_i) begin
                buffer <= dma_data_i; buffer_full <= 1'b1;
                addr <= addr == 16'hffff ? 16'h8000 : addr + 16'd1;
                if (bytes == 12'd1) begin
                    if (loop) begin
                        addr <= {2'b11, start_reg, 6'b0}; bytes <= {length_reg, 4'b0001};
                    end else begin
                        bytes <= '0;
                        if (irq_en) irq_o <= 1'b1;
                    end
                end else bytes <= bytes - 12'd1;
            end
            if (wr_i) begin
                case (reg_i)
                    2'd0: begin irq_en <= data_i[7]; loop <= data_i[6]; rate <= data_i[3:0];
                                if (!data_i[7]) irq_o <= 1'b0; end
                    2'd1: level <= data_i[6:0];
                    2'd2: start_reg <= data_i;
                    default: length_reg <= data_i;
                endcase
            end
            if (status_wr_i) begin
                irq_o <= 1'b0;
                if (!enable_i) bytes <= '0;
                else if (bytes == 0) begin
                    addr <= {2'b11, start_reg, 6'b0}; bytes <= {length_reg, 4'b0001};
                end
            end
        end
    end
endmodule
