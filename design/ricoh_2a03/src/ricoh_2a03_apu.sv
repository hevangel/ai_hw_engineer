// APU register file, channel instances, frame counter and $4015 status.
module ricoh_2a03_apu #(
    parameter bit PAL = 1'b0
) (
    input  logic clk, rst_n,
    input  logic apu_phase_i,      // 1 on APU ("put") cycles
    input  logic wr_i,             // CPU write to $4000-$401F this cycle
    input  logic [4:0] reg_i,
    input  logic [7:0] data_i,
    input  logic status_rd_i,      // CPU read of $4015 this cycle
    output logic [7:0] status_o,   // $4015 value with bit 5 = 0
    output logic dmc_dma_req_o,
    output logic [15:0] dmc_dma_addr_o,
    input  logic dmc_dma_done_i,
    input  logic [7:0] dmc_dma_data_i,
    output logic irq_o,
    output logic [3:0] pulse1_o, pulse2_o, triangle_o, noise_o,
    output logic [6:0] dmc_o
);
    logic quarter, half, frame_irq, dmc_irq;
    logic [3:0] enable;   // DMC enable acts directly on its reader
    logic p1_act, p2_act, tri_act, noise_act, dmc_act;
    logic status_wr;
    assign status_wr = wr_i && reg_i == 5'h15;

    always_ff @(posedge clk) begin
        if (!rst_n) enable <= '0;
        else if (status_wr) enable <= data_i[3:0];
    end

    ricoh_2a03_frame #(.PAL(PAL)) frame_unit (
        .clk, .rst_n, .apu_phase_i, .wr_i(wr_i && reg_i == 5'h17), .mode_i(data_i[7:6]),
        .irq_clear_i(status_rd_i), .quarter_o(quarter), .half_o(half), .irq_o(frame_irq)
    );
    ricoh_2a03_pulse #(.NEGATE_ONES(1'b1)) pulse1 (
        .clk, .rst_n, .apu_tick_i(apu_phase_i), .quarter_i(quarter), .half_i(half),
        .enable_i(enable[0]), .wr_i(wr_i && reg_i[4:2] == 3'd0), .reg_i(reg_i[1:0]),
        .data_i, .active_o(p1_act), .out_o(pulse1_o)
    );
    ricoh_2a03_pulse #(.NEGATE_ONES(1'b0)) pulse2 (
        .clk, .rst_n, .apu_tick_i(apu_phase_i), .quarter_i(quarter), .half_i(half),
        .enable_i(enable[1]), .wr_i(wr_i && reg_i[4:2] == 3'd1), .reg_i(reg_i[1:0]),
        .data_i, .active_o(p2_act), .out_o(pulse2_o)
    );
    ricoh_2a03_triangle triangle (
        .clk, .rst_n, .quarter_i(quarter), .half_i(half),
        .enable_i(enable[2]), .wr_i(wr_i && reg_i[4:2] == 3'd2), .reg_i(reg_i[1:0]),
        .data_i, .active_o(tri_act), .out_o(triangle_o)
    );
    ricoh_2a03_noise #(.PAL(PAL)) noise (
        .clk, .rst_n, .apu_tick_i(apu_phase_i), .quarter_i(quarter), .half_i(half),
        .enable_i(enable[3]), .wr_i(wr_i && reg_i[4:2] == 3'd3), .reg_i(reg_i[1:0]),
        .data_i, .active_o(noise_act), .out_o(noise_o)
    );
    ricoh_2a03_dmc #(.PAL(PAL)) dmc (
        .clk, .rst_n, .apu_tick_i(apu_phase_i), .wr_i(wr_i && reg_i[4:2] == 3'd4),
        .reg_i(reg_i[1:0]), .data_i, .status_wr_i(status_wr), .enable_i(data_i[4]),
        .dma_req_o(dmc_dma_req_o), .dma_addr_o(dmc_dma_addr_o), .dma_done_i(dmc_dma_done_i),
        .dma_data_i(dmc_dma_data_i), .active_o(dmc_act), .irq_o(dmc_irq), .out_o(dmc_o)
    );

    assign status_o = {dmc_irq, frame_irq, 1'b0, dmc_act, noise_act, tri_act, p2_act, p1_act};
    assign irq_o = frame_irq || dmc_irq;
endmodule
