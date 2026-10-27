// Ricoh RP2A03 (NTSC) / RP2A07 (PAL): decimal-disabled NMOS 6502 core,
// APU, OAM/DMC DMA and controller-port strobes. See spec/spec.md.
module ricoh_2a03 #(
    parameter bit REGION = 1'b0     // 0 = RP2A03 NTSC, 1 = RP2A07 PAL
) (
    input  logic clk, rst_n,
    input  logic irq_n, nmi_n,
    output logic [15:0] addr_o,
    input  logic [7:0] data_i,
    output logic [7:0] data_o,
    output logic we_o,
    output logic ext_rd_o,
    output logic [2:0] out_o,
    output logic oe1_n_o, oe2_n_o,
    output logic [3:0] pulse1_o, pulse2_o, triangle_o, noise_o,
    output logic [6:0] dmc_o,
    output logic dma_o,
    output logic fetch_o, jammed_o, fault_o,
    output logic [15:0] pc_o,
    output logic [7:0] a_o, x_o, y_o, s_o, p_o
);
    logic [15:0] core_addr;
    logic [7:0] core_dout, core_din;
    logic core_we, core_rdy;
    logic apu_phase;
    logic apu_irq;
    logic dma_owns, dma_we, dma_repeat, dmc_done, dmc_req;
    logic [15:0] dma_addr, dmc_addr;
    logic [7:0] dma_wdata, dmc_data, apu_status;
    logic open_bus5;   // CPU data-bus latch bit 5: undriven $4015 bit
    logic cpu_cycle, cpu_wr, cpu_rd, status_rd, bus_rd;

    // A CPU cycle proceeds when RDY is high, or when the core writes
    // (NMOS RDY does not stall writes). A DMA cycle owns the bus otherwise.
    assign cpu_cycle = !dma_owns;
    assign cpu_wr = cpu_cycle && core_we;
    assign cpu_rd = cpu_cycle && !core_we;
    assign status_rd = cpu_rd && core_rdy && core_addr == 16'h4015;

    assign addr_o = (dma_owns && !dma_repeat) ? dma_addr : core_addr;
    assign we_o = dma_owns ? dma_we : core_we;
    assign data_o = dma_owns ? dma_wdata : core_dout;
    assign bus_rd = !we_o;
    assign ext_rd_o = bus_rd && !(cpu_cycle && core_addr == 16'h4015);
    assign oe1_n_o = !(bus_rd && addr_o == 16'h4016);
    assign oe2_n_o = !(bus_rd && addr_o == 16'h4017);
    assign dma_o = dma_owns;
    assign core_din = (core_addr == 16'h4015) ? (apu_status | {2'b00, open_bus5, 5'b0}) : data_i;

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            apu_phase <= 1'b0; out_o <= '0; open_bus5 <= 1'b0;
        end else begin
            apu_phase <= !apu_phase;
            if (cpu_wr && core_addr == 16'h4016) out_o <= core_dout[2:0];
            if (we_o) open_bus5 <= data_o[5];
            else if (ext_rd_o) open_bus5 <= data_i[5];
        end
    end

    mos_6502_native #(.DECIMAL_ENABLE(1'b0)) core (
        .clk, .rst_n, .rdy_i(core_rdy), .irq_n(irq_n && !apu_irq), .nmi_n, .so_n(1'b1),
        .bus_addr(core_addr), .bus_data_i(core_din), .bus_data_o(core_dout), .bus_we(core_we),
        .fetch_o, .fault_o, .jammed_o, .pc_o, .status_o(p_o), .a_o, .x_o, .y_o, .s_o
    );

    ricoh_2a03_dma dma (
        .clk, .rst_n, .apu_phase_i(apu_phase), .cpu_we_i(core_we),
        .oam_start_i(cpu_wr && core_addr == 16'h4014), .oam_page_i(core_dout),
        .dmc_req_i(dmc_req), .dmc_addr_i(dmc_addr), .data_i,
        .rdy_o(core_rdy), .owns_bus_o(dma_owns), .addr_o(dma_addr), .we_o(dma_we),
        .wdata_o(dma_wdata), .repeat_o(dma_repeat), .dmc_done_o(dmc_done), .dmc_data_o(dmc_data)
    );

    ricoh_2a03_apu #(.PAL(REGION)) apu (
        .clk, .rst_n, .apu_phase_i(apu_phase),
        .wr_i(cpu_wr && core_addr[15:5] == 11'h200), .reg_i(core_addr[4:0]), .data_i(core_dout),
        .status_rd_i(status_rd), .status_o(apu_status),
        .dmc_dma_req_o(dmc_req), .dmc_dma_addr_o(dmc_addr), .dmc_dma_done_i(dmc_done),
        .dmc_dma_data_i(dmc_data), .irq_o(apu_irq),
        .pulse1_o, .pulse2_o, .triangle_o, .noise_o, .dmc_o
    );

`ifdef FORMAL
    `include "ricoh_2a03_props.sv"
`endif
endmodule
