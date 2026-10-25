// MITS Altair 8800 functional system board. Source: spec/spec.md.
// 8080 + 88-SIO console card (ports 0/1) + sense switch port FF + front-panel
// display/control logic. RAM storage is the altair_ram simulation model, an
// explicit external interface like the IBM PC system's motherboard. One
// rising edge is one implementation step; every bus transfer completes in a
// single step (bus_ready tied high). The RAM write request is registered:
// the model executes it on the following edge, keeping cross-module
// scheduling out of the picture.
module altair_8800 #(
    parameter int RAM_KIB = 16
) (
    input logic clk,
    input logic rst_n,
    // Front panel switches (level or single-step pulses driven by the host).
    input logic run_sw,
    input logic step_sw,
    input logic examine_sw,
    input logic examine_next_sw,
    input logic deposit_sw,
    input logic deposit_next_sw,
    input logic reset_sw,
    input logic clr_sw,
    input logic protect_sw,
    input logic unprotect_sw,
    input logic [15:0] address_sw,
    input logic [7:0] data_sw,
    // Host side of the 88-SIO ("teletype"): tape/keyboard in, console out.
    input logic [7:0] tty_in_data,
    input logic tty_in_we,
    output logic tty_in_ready,
    input logic [15:0] tty_tx_delay,
    output logic tty_out_we,
    output logic [7:0] tty_out_data,
    // Read-only host memory window.
    input logic [15:0] host_mem_addr,
    output logic [7:0] host_mem_rdata,
    // Panel lamps and machine state.
    output logic [15:0] lamp_addr,
    output logic [7:0] lamp_data,
    output logic [7:0] lamp_status,
    output logic lamp_inte,
    output logic lamp_hlda,
    output logic lamp_prot,
    output logic lamp_wait,
    output logic lamp_hlta,
    output logic running,
    output logic halted,
    output logic protect_lamp,
    output logic fault,
    output logic [15:0] display_addr,
    output logic [15:0] cpu_pc,
    output logic [15:0] cpu_sp,
    output logic [55:0] cpu_regs,
    output logic [7:0] cpu_flags,
    output logic retired,
    output logic [31:0] cycle_count,
    output logic [31:0] instruction_count,
    output logic [11:0] rx_count
);
    // Core reset: power-on rst_n or the panel RESET switch (3 clocks, as the
    // physical active-high RESET requires at least three clocks).
    logic [1:0] reset_cnt;
    logic core_rst_n;
    assign core_rst_n = rst_n && (reset_cnt == 2'd0);

    // The panel holds the CPU whenever the RUN switch is off and no single
    // step is in progress. During the retirement cycle hold re-asserts so a
    // step stops at the instruction boundary instead of fetching the next
    // opcode. (hold_req is assigned after the core output declarations.)
    logic stepping;
    wire stopped = !run_sw && !stepping;
    logic hold_req;
    wire panel_ready = stopped && hlda;

    logic bus_req, bus_write, bus_io, bus_intack;
    logic [15:0] bus_addr;
    logic [7:0] bus_wdata, bus_rdata, bus_status;
    logic inte, hlda, core_halted, core_retire, core_fault;
    // A completed CPU transfer (bus_ready is always 1).
    wire bus_xfer = core_rst_n && bus_req && !hlda;
    wire io_xfer = bus_xfer && bus_io;
    wire mem_xfer = bus_xfer && !bus_io;
    // Single step re-asserts HOLD one cycle after the retirement pulse
    // (retire_seen is registered). HOLD then completes the next
    // instruction's in-flight M1 fetch, so a step stops after one retired
    // instruction with the following opcode prefetched: the original
    // panel's stop-at-next-M1 behavior, deterministic in every build.
    logic retire_seen;
    assign hold_req = (run_sw || (stepping && !retire_seen)) ? 1'b0 : 1'b1;

    // 8080 core.
    logic [15:0] core_pc, core_sp;
    logic [55:0] core_regs;
    logic [7:0] core_flags;
    logic [7:0] ram_cpu_rdata, ram_panel_rdata;
    intel_8080 cpu (
        .clk, .rst_n(core_rst_n),
        .bus_ready_i(1'b1),
        .bus_rdata_i(bus_rdata),
        .int_i(1'b0),
        .hold_i(hold_req),
        .bus_req_o(bus_req),
        .bus_write_o(bus_write),
        .bus_io_o(bus_io),
        .bus_intack_o(bus_intack),
        .bus_addr_o(bus_addr),
        .bus_wdata_o(bus_wdata),
        .bus_status_o(bus_status),
        .inte_o(inte),
        .hlda_o(hlda),
        .halted_o(core_halted),
        .retire_o(core_retire),
        .fault_o(core_fault),
        .pc_o(core_pc),
        .sp_o(core_sp),
        .regs_o(core_regs),
        .flags_o(core_flags)
    );
    logic unused_intack;
    assign unused_intack = bus_intack;

    // 88-SIO: received-byte FIFO from the host, transmitter to the host.
    logic [7:0] rx_mem [0:4095];
    logic [11:0] rx_wr_ptr, rx_rd_ptr;
    logic [15:0] tx_busy;
    wire rx_full = (rx_wr_ptr + 12'd1) == rx_rd_ptr;
    assign tty_in_ready = !rx_full;
    assign rx_count = rx_wr_ptr - rx_rd_ptr;

    // Memory and I/O read mux for the CPU bus. RAM reads are asynchronous
    // against the stable transfer address, so the core samples them safely.
    always_comb begin
        bus_rdata = 8'hff;
        if (!bus_io) bus_rdata = ram_cpu_rdata;
        else case (bus_addr[7:0])
            8'h00: bus_rdata = {tx_busy != 16'd0, 6'b0, rx_wr_ptr == rx_rd_ptr};
            8'h01: bus_rdata = rx_mem[rx_rd_ptr];
            8'hff: bus_rdata = address_sw[15:8];
            default: bus_rdata = 8'hff;
        endcase
    end

    // Registered RAM write request; altair_ram executes it on the next edge.
    // The panel and the CPU never write in the same cycle (the panel only
    // acts while the CPU is held with HLDA).
    logic ram_we;
    logic [15:0] ram_waddr;
    logic [7:0] ram_wdata;
    // Registered panel display read address and a one-cycle follow-up that
    // latches the read result into the display lamps.
    logic [15:0] panel_addr_r;
    logic panel_pending;
    logic [15:0] panel_pending_addr;

    altair_ram #(.RAM_KIB(RAM_KIB)) ram (
        .clk,
        .cpu_addr(bus_addr), .cpu_rdata(ram_cpu_rdata),
        .waddr(ram_waddr), .wdata(ram_wdata), .we(ram_we),
        .panel_addr(panel_addr_r), .panel_rdata(ram_panel_rdata),
        .host_addr(host_mem_addr), .host_rdata(host_mem_rdata)
    );

    // Panel operations and machine sequencing.
    logic protect_latch;
    always_ff @(posedge clk) begin
        retired <= 1'b0;
        tty_out_we <= 1'b0;
        panel_pending <= 1'b0;
        ram_we <= 1'b0;
        if (!rst_n) begin
            lamp_addr <= 16'd0;
            lamp_data <= 8'd0;
            lamp_status <= 8'd0;
            lamp_inte <= 1'b0;
            lamp_hlda <= 1'b0;
            lamp_prot <= 1'b0;
            lamp_wait <= 1'b0;
            lamp_hlta <= 1'b0;
            running <= 1'b0;
            halted <= 1'b0;
            fault <= 1'b0;
            display_addr <= 16'd0;
            stepping <= 1'b0;
            retire_seen <= 1'b0;
            protect_latch <= 1'b0;
            reset_cnt <= 2'd0;
            tx_busy <= 16'd0;
            rx_wr_ptr <= 12'd0;
            rx_rd_ptr <= 12'd0;
            instruction_count <= 32'd0;
            cycle_count <= 32'd0;
            tty_out_data <= 8'd0;
            panel_addr_r <= 16'd0;
        end else begin
            cycle_count <= cycle_count + 32'd1;
            if (core_retire) begin
                instruction_count <= instruction_count + 32'd1;
                retired <= 1'b1;
            end
            running <= run_sw;
            halted <= core_halted;
            fault <= core_fault;
            lamp_inte <= inte;
            lamp_hlda <= hlda;
            lamp_prot <= protect_latch;
            // No modelled device inserts wait states, so WAIT never lights.
            lamp_wait <= 1'b0;
            lamp_hlta <= core_halted || (bus_xfer && bus_status[3]);

            // RESET: 3-clock core reset, display address to 0. The RUN switch
            // is not changed; with RUN on the machine restarts from 0.
            if (reset_sw && reset_cnt == 2'd0) begin
                reset_cnt <= 2'd3;
                stepping <= 1'b0;
                display_addr <= 16'd0;
                panel_pending <= 1'b1;
                panel_pending_addr <= 16'd0;
                panel_addr_r <= 16'd0;
            end else if (reset_cnt != 2'd0) begin
                reset_cnt <= reset_cnt - 2'd1;
            end

            // CLR resets the 88-SIO status and receiver buffer.
            if (clr_sw) begin
                rx_wr_ptr <= 12'd0;
                rx_rd_ptr <= 12'd0;
                tx_busy <= 16'd0;
            end
            if (protect_sw) protect_latch <= 1'b1;
            if (unprotect_sw) protect_latch <= 1'b0;

            // CPU dequeues SIO bytes; OUT 01 transmits with pacing.
            if (io_xfer && !bus_write && bus_addr[7:0] == 8'h01)
                rx_rd_ptr <= rx_rd_ptr + 12'd1;
            if (io_xfer && bus_write && bus_addr[7:0] == 8'h01) begin
                tty_out_we <= 1'b1;
                tty_out_data <= bus_wdata;
                tx_busy <= tty_tx_delay;
            end

            // Host fills the SIO receiver FIFO.
            if (tty_in_we && !rx_full) begin
                rx_mem[rx_wr_ptr] <= tty_in_data;
                rx_wr_ptr <= rx_wr_ptr + 12'd1;
            end
            if (tx_busy != 16'd0) tx_busy <= tx_busy - 16'd1;

            // Latch panel lamps on each completed transfer, as the original
            // panel latches status at SYNC.
            if (bus_xfer) begin
                lamp_addr <= bus_addr;
                lamp_data <= bus_write ? bus_wdata : bus_rdata;
                lamp_status <= bus_status;
            end
            if (core_retire && core_halted) lamp_status[3] <= 1'b1;

            // Single step: run until the next instruction retires.
            if (step_sw && stopped && !core_halted && !core_fault && reset_cnt == 2'd0)
                stepping <= 1'b1;
            retire_seen <= core_retire;
            if (stepping && retire_seen) stepping <= 1'b0;

            if (panel_ready && reset_cnt == 2'd0) begin
                // EXAMINE/EXAMINE NEXT: register the address, latch the read
                // result and the display advance on the following edge.
                if ((examine_sw || examine_next_sw) && !panel_pending) begin
                    panel_pending <= 1'b1;
                    panel_pending_addr <= examine_next_sw ? display_addr + 16'd1
                                                          : address_sw;
                    panel_addr_r <= examine_next_sw ? display_addr + 16'd1
                                                    : address_sw;
                end
                // DEPOSIT/DEPOSIT NEXT: registered write request, executed by
                // the RAM model on the next edge.
                if (deposit_sw || deposit_next_sw) begin
                    ram_we <= !protect_latch;
                    ram_waddr <= deposit_next_sw ? display_addr + 16'd1
                                                 : display_addr;
                    ram_wdata <= data_sw;
                    lamp_addr <= deposit_next_sw ? display_addr + 16'd1
                                                 : display_addr;
                    lamp_data <= data_sw;
                    if (deposit_next_sw) display_addr <= display_addr + 16'd1;
                end
            end else if (mem_xfer && bus_write) begin
                // CPU store: registered write request with the transfer data.
                ram_we <= !protect_latch;
                ram_waddr <= bus_addr;
                ram_wdata <= bus_wdata;
            end
            if (panel_pending) begin
                display_addr <= panel_pending_addr;
                lamp_addr <= panel_pending_addr;
                lamp_data <= ram_panel_rdata;
            end
        end
    end

    assign cpu_pc = core_pc;
    assign cpu_sp = core_sp;
    assign cpu_regs = core_regs;
    assign cpu_flags = core_flags;
    assign protect_lamp = protect_latch;
endmodule
