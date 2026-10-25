// Taito/Midway Space Invaders (1978) functional arcade board. Source:
// spec/spec.md. Intel 8080 at the original 1.9968 MHz rate model: a 33280-
// cycle 60 Hz frame drives the two RST interrupts (CFh at line 96, D7h at
// line 224). Work RAM, VRAM and ROM live in the si_memory model; the board
// adds the shift register, input ports, sound latches, watchdog and the
// host run/step machinery. One rising edge is one implementation step.
module space_invaders (
    input logic clk,
    input logic rst_n,
    // Operator/host controls (same contract as the Altair board). Freeze
    // stalls the bus (ready=0): the core parks in its wait state with
    // every transaction field and architectural register preserved, which
    // the harness uses for exact instruction-boundary checkpoints.
    input logic run_sw,
    input logic step_sw,
    input logic reset_sw,
    input logic freeze,
    // Raw input-port bytes from the host; the board forces the documented
    // constant bits (port 0 bits 1-3, port 1 bit 3) to read as 1.
    input logic [7:0] in0,
    input logic [7:0] in1,
    input logic [7:0] in2,
    // Host VRAM window (2400h-3FFFh as 0..7167).
    input logic [12:0] host_vram_addr,
    output logic [7:0] host_vram_rdata,
    // Host full-memory debug window (testbench and oracle comparison).
    input logic [15:0] host_mem_addr,
    output logic [7:0] host_mem_rdata,
    // Sound-port event latches to the host.
    output logic snd3_we,
    output logic [7:0] snd3_data,
    output logic snd5_we,
    output logic [7:0] snd5_data,
    // Observables.
    output logic running,
    output logic halted,
    output logic fault,
    output logic [15:0] cpu_pc,
    output logic [15:0] cpu_sp,
    output logic [55:0] cpu_regs,
    output logic [7:0] cpu_flags,
    output logic retired,
    output logic [31:0] cycle_count,
    output logic [31:0] instruction_count,
    output logic [31:0] frame_count,
    output logic [31:0] interrupt_count,
    output logic [31:0] watchdog_reset_count,
    output logic [15:0] shift_reg,
    output logic [2:0] shift_offset
);
    localparam logic [15:0] FRAME_CYCLES = 16'd33280; // 1.9968 MHz / 60 Hz
    localparam logic [15:0] INT_MID  = 16'd12480;     // line 96:  RST 8
    localparam logic [15:0] INT_VBL  = 16'd29120;     // line 224: RST 10
    localparam logic [8:0]  WATCHDOG_FRAMES = 9'd256; // ~4.3 s; the ROM's
    // TwoSecDelay splash routine runs ~120 frames without any port-6 feed,
    // so the window must exceed the longest un-fed stretch (see report).

    // Core reset: power-on, operator RESET, or the watchdog.
    logic [1:0] reset_cnt;
    logic watchdog_fire;
    logic core_rst_n;
    logic irq_pend;
    assign core_rst_n = rst_n && (reset_cnt == 2'd0) && !watchdog_fire;

    // Run/step machinery (proven on the Altair board; stop-at-next-M1).
    logic stepping, retire_seen;
    wire stopped = !run_sw && !stepping;
    logic hold_req;

    logic bus_req, bus_write, bus_io, bus_intack;
    logic [15:0] bus_addr;
    logic [7:0] bus_wdata, bus_rdata, bus_status;
    logic inte, hlda, core_halted, core_retire, core_fault;
    wire bus_xfer = core_rst_n && bus_req && !hlda;
    wire io_xfer = bus_xfer && bus_io;
    wire mem_xfer = bus_xfer && !bus_io;
    assign hold_req = (run_sw || (stepping && !retire_seen)) ? 1'b0 : 1'b1;

    // Video/interrupt time advances only with executed CPU cycles: pausing
    // the machine freezes video/watchdog time, so host pauses never trip
    // the watchdog.
    wire running_step = core_rst_n && !hold_req;

    logic [15:0] core_pc, core_sp;
    logic [55:0] core_regs;
    logic [7:0] core_flags;
    intel_8080 cpu (
        .clk, .rst_n(core_rst_n),
        .bus_ready_i(!freeze),
        .bus_rdata_i(bus_rdata),
        .int_i(irq_pend),
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
    logic unused_status;
    logic unused_inte;
    assign unused_inte = inte;
    assign unused_status = ^bus_status;

    logic [7:0] ram_cpu_rdata, host_mem_read;
    si_memory mem (
        .clk,
        .cpu_addr(bus_addr), .cpu_rdata(ram_cpu_rdata),
        .waddr(mem_waddr), .wdata(mem_wdata), .we(mem_we),
        .win_addr(host_vram_addr), .win_rdata(host_vram_rdata),
        .dbg_addr(host_mem_addr), .dbg_rdata(host_mem_read)
    );
    assign host_mem_rdata = host_mem_read;

    // 16-bit hardware shift register. The write byte is registered with
    // the request so the shifter samples the OUT transfer's own data.
    logic shift_data_we, shift_off_we;
    logic [7:0] shift_result, shift_data_r;
    si_shift shifter (
        .clk, .rst_n,
        .data_we(shift_data_we), .data(shift_data_r),
        .offset_we(shift_off_we), .offset_bus(shift_data_r),
        .shift_reg, .shift_offset, .result(shift_result)
    );

    // Sound latches (current values + one-cycle event pulses).


    // Registered memory write request (one-edge landing, as on the Altair
    // board: the storage model executes it on the following edge).
    logic mem_we;
    logic [15:0] mem_waddr;
    logic [7:0] mem_wdata;

    // Bus read mux. INTA has priority: the pending RST vector byte goes on
    // the data bus during interrupt acknowledge.
    always_comb begin
        if (bus_intack && bus_req) bus_rdata = irq_vec;
        else if (bus_io) begin
            case (bus_addr[7:0])
                8'h00: bus_rdata = in0 | 8'h0e;          // bits 1-3 read as 1
                8'h01: bus_rdata = in1 | 8'h08;          // bit 3 reads as 1
                8'h02: bus_rdata = in2;
                8'h03: bus_rdata = shift_result;
                default: bus_rdata = 8'hff;
            endcase
        end else bus_rdata = ram_cpu_rdata;
    end

    logic [15:0] frame_cycle;
    logic [7:0] irq_vec;
    logic [8:0] wd_frames;

    always_ff @(posedge clk) begin
        retired <= 1'b0;
        snd3_we <= 1'b0;
        snd5_we <= 1'b0;
        mem_we <= 1'b0;
            shift_data_we <= 1'b0;
            shift_off_we <= 1'b0;
            if (!rst_n) begin
            reset_cnt <= 2'd0;
            watchdog_fire <= 1'b0;
            stepping <= 1'b0;
            retire_seen <= 1'b0;
            irq_pend <= 1'b0;
            irq_vec <= 8'hcf;
            frame_cycle <= 16'd0;
            frame_count <= 32'd0;
            interrupt_count <= 32'd0;
            watchdog_reset_count <= 32'd0;
            cycle_count <= 32'd0;
            instruction_count <= 32'd0;
            running <= 1'b0;
            wd_frames <= 9'd0;
            snd3_data <= 8'd0;
            snd5_data <= 8'd0;
            mem_waddr <= 16'd0;
            mem_wdata <= 8'd0;
        end else begin
            cycle_count <= cycle_count + 32'd1;
            if (core_retire) begin
                instruction_count <= instruction_count + 32'd1;
                retired <= 1'b1;
            end
            running <= run_sw;
            halted <= core_halted;
            fault <= core_fault;

            // Reset: 3-clock core reset (operator or watchdog). Firing the
            // watchdog also re-arms it, so a resetting CPU cannot re-trip
            // it while it cannot feed.
            if (watchdog_fire) begin
                watchdog_fire <= 1'b0;
                wd_frames <= 9'd0;
                reset_cnt <= 2'd3;
                watchdog_reset_count <= watchdog_reset_count + 32'd1;
                stepping <= 1'b0;
                irq_pend <= 1'b0;
                frame_cycle <= 16'd0;
            end else if (reset_sw && reset_cnt == 2'd0) begin
                reset_cnt <= 2'd3;
                stepping <= 1'b0;
                irq_pend <= 1'b0;
                frame_cycle <= 16'd0;
            end else if (reset_cnt != 2'd0) begin
                reset_cnt <= reset_cnt - 2'd1;
            end

            // Video/interrupt timing runs only while the CPU runs.
            if (running_step) begin
                if (frame_cycle == FRAME_CYCLES - 16'd1) begin
                    frame_cycle <= 16'd0;
                    frame_count <= frame_count + 32'd1;
                    if (wd_frames != WATCHDOG_FRAMES)
                        wd_frames <= wd_frames + 9'd1;
                end else begin
                    frame_cycle <= frame_cycle + 16'd1;
                end
                // The vector flip-flop re-clocks at each event, exactly as
                // the hardware decode (0xC7|64V<<4|!64V<<3) does.
                if (frame_cycle == INT_MID) begin
                    irq_pend <= 1'b1;
                    irq_vec <= 8'hcf;                    // RST 8, line 96
                end
                if (frame_cycle == INT_VBL) begin
                    irq_pend <= 1'b1;
                    irq_vec <= 8'hd7;                    // RST 10, line 224
                end
            end
            if (wd_frames == WATCHDOG_FRAMES) watchdog_fire <= 1'b1;

            // Acknowledge clears the pending interrupt.
            if (bus_req && bus_intack && !hlda) begin
                irq_pend <= 1'b0;
                interrupt_count <= interrupt_count + 32'd1;
            end

            // Single step.
            if (step_sw && stopped && !core_halted && !core_fault && reset_cnt == 2'd0)
                stepping <= 1'b1;
            retire_seen <= core_retire;
            if (stepping && retire_seen) stepping <= 1'b0;

            // CPU I/O on completed transfers. Write data is captured at
            // the transfer edge for the registered consumers below.
            if (io_xfer) begin
                if (bus_write) begin
                    case (bus_addr[7:0])
                        8'h02: begin shift_off_we <= 1'b1; shift_data_r <= bus_wdata; end
                        8'h03: begin snd3_we <= 1'b1; snd3_data <= bus_wdata; end
                        8'h04: begin shift_data_we <= 1'b1; shift_data_r <= bus_wdata; end
                        8'h05: begin snd5_we <= 1'b1; snd5_data <= bus_wdata; end
                        default: ;
                    endcase
                end
                if (bus_addr[7:0] == 8'h06) wd_frames <= 9'd0; // read or write
            end

            // Registered memory write request.
            if (mem_xfer && bus_write) begin
                mem_we <= 1'b1;
                mem_waddr <= bus_addr;
                mem_wdata <= bus_wdata;
            end
        end
    end

    assign cpu_pc = core_pc;
    assign cpu_sp = core_sp;
    assign cpu_regs = core_regs;
    assign cpu_flags = core_flags;
endmodule
