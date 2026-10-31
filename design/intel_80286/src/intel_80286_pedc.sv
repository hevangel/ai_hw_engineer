// Processor-extension word transfer engine. Integration and native PEACK#
// timing are not complete; see spec/processor_extension_channel.md.
// ASSUMPTION: A26. A new PEREQ is accepted only after a low sample separates
// requests. This avoids duplicating a held request; validate with an 80287.
module intel_80286_pedc (
    input  logic clk, rst_n,
    input  logic arm_i,
    input  logic [23:0] address_i,
    input  logic [15:0] words_i,
    input  logic to_memory_i,
    input  logic busy_i, pereq_i,
    input  logic grant_i, ready_i,
    input  logic [15:0] rdata_i,
    output logic request_o, write_o, io_o,
    output logic [23:0] address_o,
    output logic [1:0] bytes_o,
    output logic [15:0] wdata_o,
    output logic peack_n_o,
    output logic active_o, transfer_o, done_o
);
    typedef enum logic [2:0] {IDLE, WAIT_REQUEST, FIRST, SECOND, THIRD} state_t;
    state_t state;
    logic [23:0] address;
    logic [15:0] remaining, data_word;
    logic to_memory, busy_seen, request_low_seen;

    assign active_o = state != IDLE;
    assign request_o = state == FIRST || state == SECOND || state == THIRD;
    // PEACK is active throughout the first granted transfer, including waits.
    assign peack_n_o = !(state == FIRST && grant_i);

    always_comb begin
        address_o = address;
        bytes_o = address[0] ? 2'd1 : 2'd2;
        io_o = 1'b0;
        write_o = 1'b0;
        wdata_o = 16'd0;
        if (request_o) begin
            if ((state == FIRST && to_memory) ||
                ((state == SECOND || state == THIRD) && !to_memory &&
                 (state == THIRD || !address[0]))) begin
                address_o = 24'h0000fa;
                bytes_o = 2'd2;
                io_o = 1'b1;
                write_o = !to_memory;
                wdata_o = data_word;
            end else if (state == THIRD) begin
                address_o = address + 24'd1;
                bytes_o = 2'd1;
                write_o = to_memory;
                wdata_o = {8'd0,data_word[15:8]};
            end else if (state == SECOND && !to_memory && address[0]) begin
                address_o = address + 24'd1;
                bytes_o = 2'd1;
            end else begin
                write_o = to_memory;
                if (address[0]) wdata_o = {data_word[7:0],8'd0};
                else wdata_o = data_word;
            end
        end
    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            state <= IDLE; address <= 0; remaining <= 0; data_word <= 0;
            to_memory <= 0; busy_seen <= 0; request_low_seen <= 0;
            transfer_o <= 0; done_o <= 0;
        end else begin
            transfer_o <= 0; done_o <= 0;
            if (request_o && !pereq_i) request_low_seen <= 1;
            case (state)
                IDLE: if (arm_i && words_i != 0) begin
                    address <= address_i; remaining <= words_i;
                    to_memory <= to_memory_i; busy_seen <= busy_i;
                    request_low_seen <= !pereq_i; state <= WAIT_REQUEST;
                end
                WAIT_REQUEST: begin
                    if (busy_i) busy_seen <= 1;
                    if (!pereq_i) request_low_seen <= 1;
                    if (busy_seen && !busy_i) begin
                        state <= IDLE; done_o <= 1;
                    end else if (busy_i && pereq_i && request_low_seen) begin
                        request_low_seen <= 0; state <= FIRST;
                    end
                end
                FIRST: if (grant_i && ready_i) begin
                    if (to_memory) data_word <= rdata_i;
                    else if (address[0]) data_word[7:0] <= rdata_i[15:8];
                    else data_word <= rdata_i;
                    state <= SECOND;
                end
                SECOND: if (grant_i && ready_i) begin
                    if (!to_memory && address[0]) begin
                        data_word[15:8] <= rdata_i[7:0]; state <= THIRD;
                    end else if (to_memory && address[0]) state <= THIRD;
                    else begin
                        address <= address + 24'd2; remaining <= remaining - 16'd1;
                        transfer_o <= 1;
                        if (remaining == 1) begin state <= IDLE; done_o <= 1; end
                        else state <= WAIT_REQUEST;
                    end
                end
                THIRD: if (grant_i && ready_i) begin
                    address <= address + 24'd2; remaining <= remaining - 16'd1;
                    transfer_o <= 1;
                    if (remaining == 1) begin state <= IDLE; done_o <= 1; end
                    else state <= WAIT_REQUEST;
                end
                default: state <= IDLE;
            endcase
        end
    end
`ifdef FORMAL
    `include "intel_80286_pedc_props.sv"
`endif
endmodule
