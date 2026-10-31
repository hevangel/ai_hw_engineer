// OAM and DMC DMA sequencer. It halts the 6502 with RDY, waits for the
// CPU to reach a read cycle (the halt cycle), then owns the bus. Get
// (read) cycles occur when apu_phase_i is 0, put (write) cycles when 1.
module ricoh_2a03_dma (
    input  logic clk, rst_n,
    input  logic apu_phase_i,
    input  logic cpu_we_i,          // core is presenting a write cycle
    input  logic oam_start_i,       // CPU wrote $4014 this cycle
    input  logic [7:0] oam_page_i,
    input  logic dmc_req_i,         // DMC sample buffer needs a byte
    input  logic [15:0] dmc_addr_i,
    input  logic [7:0] data_i,      // board data bus
    output logic rdy_o,             // to the 6502 core
    output logic owns_bus_o,        // this cycle is a DMA cycle
    output logic [15:0] addr_o,     // valid when owns_bus_o and !repeat_o
    output logic we_o,
    output logic [7:0] wdata_o,
    output logic repeat_o,          // halt/dummy/alignment: repeat CPU address as a read
    output logic dmc_done_o,
    output logic [7:0] dmc_data_o
);
    typedef enum logic [1:0] { D_IDLE, D_HALT, D_DUMMY, D_GET } dmc_stage_e;
    dmc_stage_e dmc_stage;
    logic halted, oam_active, oam_have;
    logic [7:0] oam_page, oam_index, oam_latch;
    logic dmc_get, oam_get, oam_put, want;
    logic halt_cycle;

    assign want = oam_active || dmc_stage != D_IDLE || (dmc_req_i && dmc_stage == D_IDLE);
    assign rdy_o = !want;
    assign halt_cycle = !halted && want && !cpu_we_i;
    assign dmc_get = halted && !apu_phase_i && dmc_stage == D_GET;
    assign oam_get = halted && !apu_phase_i && !dmc_get && oam_active && !oam_have;
    assign oam_put = halted && apu_phase_i && oam_active && oam_have;
    assign owns_bus_o = halted;
    assign repeat_o = halted && !dmc_get && !oam_get && !oam_put;
    assign we_o = oam_put;
    assign wdata_o = oam_latch;
    assign dmc_done_o = dmc_get;
    assign dmc_data_o = data_i;
    always_comb begin
        if (dmc_get) addr_o = dmc_addr_i;
        else if (oam_get) addr_o = {oam_page, oam_index};
        else addr_o = 16'h2004;
    end

    logic oam_active_n;
    dmc_stage_e dmc_stage_n;
    always_comb begin
        oam_active_n = oam_active;
        if (oam_put && oam_index == 8'hff) oam_active_n = 1'b0;
        if (oam_start_i) oam_active_n = 1'b1;
        dmc_stage_n = dmc_stage;
        case (dmc_stage)
            D_IDLE:  if (dmc_req_i) dmc_stage_n = D_HALT;
            D_HALT:  if (halted || halt_cycle) dmc_stage_n = D_DUMMY;
            D_DUMMY: dmc_stage_n = D_GET;
            default: if (dmc_get) dmc_stage_n = D_IDLE;
        endcase
        // A request that appears while idle counts its halt in this cycle.
        if (dmc_stage == D_IDLE && dmc_req_i && (halted || halt_cycle)) dmc_stage_n = D_DUMMY;
    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            dmc_stage <= D_IDLE; halted <= 1'b0; oam_active <= 1'b0; oam_have <= 1'b0;
            oam_page <= '0; oam_index <= '0; oam_latch <= '0;
        end else begin
            dmc_stage <= dmc_stage_n;
            oam_active <= oam_active_n;
            if (oam_start_i) begin
                oam_page <= oam_page_i; oam_index <= '0; oam_have <= 1'b0;
            end else if (oam_get) begin
                oam_latch <= data_i; oam_have <= 1'b1;
            end else if (oam_put) begin
                oam_have <= 1'b0; oam_index <= oam_index + 8'd1;
            end
            if (halt_cycle) halted <= 1'b1;
            else if (halted && !oam_active_n && dmc_stage_n == D_IDLE) halted <= 1'b0;
        end
    end
`ifdef FORMAL
    logic f_valid = 0;
    always_ff @(posedge clk) begin
        f_valid <= 1;
        if (f_valid && rst_n) begin
            // Only one transfer kind per cycle; writes only for OAM puts.
            assert(!(dmc_get && oam_get) && !(oam_put && (dmc_get || oam_get)));
            if (we_o) assert(oam_active && oam_have && apu_phase_i);
            if (halted) assert(!rdy_o);
        end
        cover(f_valid && rst_n && oam_put && oam_index == 8'h01);  // second OAM transfer
        cover(f_valid && rst_n && halt_cycle && dmc_req_i);       // DMC halt
    end
`endif
endmodule
