`timescale 1ns/1ps
// Original AMD Am9517 functional reconstruction; source differences in spec/spec.md.
module amd_am9517 (
    input  logic        clk,
    input  logic        reset_i,
    input  logic        cs_n,
    input  logic        ior_n,
    input  logic        iow_n,
    input  logic [3:0]  reg_addr,
    input  logic [7:0]  data_i,
    output logic [7:0]  data_o,
    output logic        data_oe,
    input  logic [3:0]  dreq,
    output logic [3:0]  dack,
    output logic        hrq,
    input  logic        hlda,
    input  logic        ready,
    input  logic        eop_n,
    output logic        eop_out_n,
    output logic [15:0] dma_addr,
    output logic        addr_oe,
    output logic        adstb,
    output logic        aen,
    output logic        memr_n,
    output logic        memw_n,
    output logic        dma_ior_n,
    output logic        dma_iow_n,
    output logic        transfer_valid,
    output logic [1:0]  transfer_channel
);
    logic rst_n;
    assign rst_n=!reset_i;
    typedef enum logic [3:0] {
        IDLE, GRANT, S1, S2, S3, SW, S4, RELEASE, CASCADE
    } state_t;
    state_t state_q;
    logic [15:0] address_q [0:3];
    logic [15:0] count_q [0:3];
    logic [15:0] base_address_q [0:3];
    logic [15:0] base_count_q [0:3];
    // Stored mode corresponds to software bits 7:2.
    logic [5:0] mode_q [0:3];
    logic [7:0] command_q, temporary_q;
    logic [3:0] mask_q, software_q, status_q;
    logic byte_high_q;
    logic [1:0] priority_q, channel_q;
    logic memory_q, destination_q, eop_seen_q;
    logic [3:0] hardware_request, eligible, ack_active;
    logic found;
    logic [1:0] selected, bus_channel, candidate;
    logic cpu_select, cpu_read, cpu_write, master_clear;
    logic bus_active, verify_transfer, timing_compressed;
    logic read_phase, write_phase, finish, terminal;
    logic [15:0] next_address;

    assign hardware_request = dreq ^ {4{command_q[6]}};
    assign cpu_select = rst_n && !cs_n && !hlda &&
                        (state_q == IDLE || state_q == GRANT || state_q == RELEASE);
    assign cpu_read = cpu_select && !ior_n && iow_n;
    assign cpu_write = cpu_select && ior_n && !iow_n;
    assign master_clear = cpu_write && reg_addr == 4'hd;
    assign bus_channel = memory_q ? {1'b0, destination_q} : channel_q;
    assign verify_transfer = !memory_q && mode_q[channel_q][1:0] == 2'b00;
    assign timing_compressed = command_q[3] && !memory_q;
    assign next_address = address_q[bus_channel] +
                          (mode_q[bus_channel][3] ? 16'hffff : 16'h0001);
    // ASSUMPTION A5: N-1 programming; zero is the final commit before wrap.
    assign terminal = count_q[bus_channel] == 16'h0000;
    assign finish = terminal || eop_seen_q || !eop_n;
    assign bus_active = rst_n && hlda &&
                        (state_q == S1 || state_q == S2 || state_q == S3 ||
                         state_q == SW || state_q == S4);
    // ASSUMPTION A7: single sampled-edge commit; physical multi-phase timing
    // and READY setup/hold are represented by this explicit functional boundary.
    assign transfer_valid = bus_active && state_q == S4 &&
                            (ready || verify_transfer);
    assign transfer_channel = bus_channel;

    always_comb begin
        eligible = '0;
        for (int i = 0; i < 4; i++) begin
            if (mode_q[i][1:0] != 2'b11 || mode_q[i][5:4] == 2'b11) begin
                eligible[i] = (hardware_request[i] && !mask_q[i]) ||
                              (software_q[i] && mode_q[i][5:4] == 2'b10);
            end
        end
        if (command_q[0]) begin
            eligible[1] = 1'b0;
            // Original AMD: copies are initiated by the channel-0 SOFTWARE request.
            eligible[0] = software_q[0] && mode_q[0][5:4] == 2'b10;
        end
        found = 1'b0;
        selected = '0;
        candidate = '0;
        for (int i = 0; i < 4; i++) begin
            candidate = (command_q[4] ? priority_q : 2'b00) + 2'(i);
            if (!found && eligible[candidate] && !command_q[2]) begin
                found = 1'b1;
                selected = candidate;
            end
        end
    end

    always_comb begin
        hrq = rst_n && !command_q[2] && (state_q != IDLE && state_q != RELEASE) &&
              (state_q != GRANT || found);
        aen = bus_active;
        addr_oe = bus_active;
        dma_addr = address_q[bus_channel];
        adstb = bus_active && state_q == S1;
        ack_active = '0;
        if (rst_n && hlda && !memory_q &&
            (bus_active || state_q == CASCADE)) ack_active[channel_q] = 1'b1;
        dack = command_q[7] ? ack_active : ~ack_active;
        read_phase = bus_active && (state_q == S2 || state_q == S3 ||
                                   state_q == SW || state_q == S4);
        write_phase = bus_active && (state_q == S4 ||
                      ((!timing_compressed && command_q[5] && !memory_q) &&
                       (state_q == S3 || state_q == SW)) ||
                      (timing_compressed && state_q == SW));
        memr_n = 1'b1;
        memw_n = 1'b1;
        dma_ior_n = 1'b1;
        dma_iow_n = 1'b1;
        if (memory_q) begin
            memr_n = !(read_phase && !destination_q);
            memw_n = !(write_phase && destination_q);
        end else begin
            case (mode_q[channel_q][1:0])
                2'b01: begin
                    dma_ior_n = !read_phase;
                    memw_n = !write_phase;
                end
                2'b10: begin
                    memr_n = !read_phase;
                    dma_iow_n = !write_phase;
                end
                default: begin end
            endcase
        end
        // Internal TC, not external EOP, drives the open-drain equivalent.
        eop_out_n = !(transfer_valid && terminal &&
                      (!memory_q || destination_q));
        data_o = '0;
        data_oe = 1'b0;
        if (cpu_read) begin
            if (!reg_addr[3]) begin
                if (reg_addr[0])
                    data_o = byte_high_q ? count_q[reg_addr[2:1]][15:8] :
                                          count_q[reg_addr[2:1]][7:0];
                else
                    data_o = byte_high_q ? address_q[reg_addr[2:1]][15:8] :
                                          address_q[reg_addr[2:1]][7:0];
                data_oe = 1'b1;
            end else if (reg_addr == 4'h8) begin
                data_o = {hardware_request, status_q}; // Original AMD status describes DREQ inputs.
                data_oe = 1'b1;
            end else if (reg_addr == 4'hd) begin
                data_o = temporary_q;
                data_oe = 1'b1;
            end
            // ASSUMPTION A1: undefined reads do not drive the shared bus.
        end else if (adstb) begin
            data_o = dma_addr[15:8];
            data_oe = 1'b1;
        end else if (bus_active && memory_q && destination_q && state_q != S1) begin
            data_o = temporary_q;
            data_oe = 1'b1;
        end
    end

    always_ff @(posedge clk or posedge reset_i) begin
        if (reset_i) begin
            state_q <= IDLE;
            command_q <= '0;
            temporary_q <= '0;
            mask_q <= '1;
            software_q <= '0;
            status_q <= '0;
            byte_high_q <= 1'b0;
            priority_q <= '0;
            channel_q <= '0;
            memory_q <= 1'b0;
            destination_q <= 1'b0;
            eop_seen_q <= 1'b0;
            begin : reset_channels
                // ASSUMPTION A2: deterministic hardware-reset channel values.
                for (int i = 0; i < 4; i++) begin
                    address_q[i] <= '0;
                    count_q[i] <= '0;
                    base_address_q[i] <= '0;
                    base_count_q[i] <= '0;
                    mode_q[i] <= '0;
                end
            end
        end else if (master_clear) begin
            state_q <= IDLE;
            command_q <= '0;
            temporary_q <= '0;
            mask_q <= '1;
            software_q <= '0;
            status_q <= '0;
            byte_high_q <= 1'b0;
            priority_q <= '0;
            channel_q <= '0;
            memory_q <= 1'b0;
            destination_q <= 1'b0;
            eop_seen_q <= 1'b0;
        end else begin
            if (cpu_read) begin
                if (!reg_addr[3]) byte_high_q <= !byte_high_q;
                if (reg_addr == 4'h8) status_q <= '0;
            end
            if (cpu_write) begin
                if (!reg_addr[3]) begin
                    byte_high_q <= !byte_high_q;
                    if (reg_addr[0]) begin
                        if (byte_high_q) begin
                            count_q[reg_addr[2:1]][15:8] <= data_i;
                            base_count_q[reg_addr[2:1]][15:8] <= data_i;
                        end else begin
                            count_q[reg_addr[2:1]][7:0] <= data_i;
                            base_count_q[reg_addr[2:1]][7:0] <= data_i;
                        end
                    end else begin
                        if (byte_high_q) begin
                            address_q[reg_addr[2:1]][15:8] <= data_i;
                            base_address_q[reg_addr[2:1]][15:8] <= data_i;
                        end else begin
                            address_q[reg_addr[2:1]][7:0] <= data_i;
                            base_address_q[reg_addr[2:1]][7:0] <= data_i;
                        end
                    end
                end else begin
                    case (reg_addr)
                        4'h8: command_q <= data_i;
                        4'h9: software_q[data_i[1:0]] <= data_i[2];
                        4'ha: mask_q[data_i[1:0]] <= data_i[2];
                        4'hb: mode_q[data_i[1:0]] <= data_i[7:2];
                        4'hc: byte_high_q <= 1'b0;
                        4'hf: mask_q <= data_i[3:0];
                        default: begin end
                    endcase
                end
            end

            if (bus_active && !eop_n) eop_seen_q <= 1'b1;
            case (state_q)
                IDLE: begin
                    if (!cpu_read && !cpu_write && !hlda && found) begin
                        // Priority is resolved on HACK, not when HREQ first rises.
                        memory_q <= 1'b0;
                        destination_q <= 1'b0;
                        eop_seen_q <= 1'b0;
                        state_q <= GRANT;
                    end
                end
                GRANT: begin
                    // ASSUMPTION A6: cancel a withdrawn/masked/disabled request;
                    // no phantom service when HACK arrives without eligibility.
                    if (!found) state_q <= hlda ? RELEASE : IDLE;
                    else if (hlda) begin
                        channel_q <= selected;
                        memory_q <= command_q[0] && selected == 2'b00;
                        if (!(command_q[0] && selected == 0) && mode_q[selected][5:4] == 2'b11)
                            state_q <= CASCADE;
                        else state_q <= S1;
                    end
                end
                S1: if (hlda) state_q <= S2;
                S2: if (hlda) begin
                    if (timing_compressed) state_q <= (ready || verify_transfer) ? S4 : SW;
                    else state_q <= S3;
                end
                S3: if (hlda) state_q <= (ready || verify_transfer) ? S4 : SW;
                SW: if (hlda && (ready || verify_transfer)) state_q <= S4;
                S4: if (transfer_valid) begin
                    address_q[bus_channel] <= next_address;
                    count_q[bus_channel] <= count_q[bus_channel] - 16'd1;
                    if (memory_q && !destination_q) begin
                        temporary_q <= data_i;
                        if (command_q[1]) address_q[0] <= address_q[0];
                        // ASSUMPTION A3: compatible 82C37A source count/reload rule.
                        if ((terminal || eop_seen_q || !eop_n) && mode_q[0][2]) begin
                            address_q[0] <= base_address_q[0];
                            count_q[0] <= base_count_q[0];
                        end
                        // ASSUMPTION A4: finish the byte before releasing ownership.
                        destination_q <= 1'b1;
                        state_q <= S1;
                    end else if (finish) begin
                        status_q[bus_channel] <= 1'b1;
                        software_q[bus_channel] <= 1'b0;
                        if (memory_q) software_q[0] <= 1'b0;
                        if (mode_q[bus_channel][2]) begin
                            address_q[bus_channel] <= base_address_q[bus_channel];
                            count_q[bus_channel] <= base_count_q[bus_channel];
                        end else mask_q[bus_channel] <= 1'b1;
                        priority_q <= channel_q + 2'd1;
                        state_q <= RELEASE;
                    end else if (memory_q) begin
                        destination_q <= 1'b0;
                        state_q <= S1;
                    end else if (mode_q[channel_q][5:4] == 2'b01 ||
                                 (mode_q[channel_q][5:4] == 2'b00 &&
                                  !hardware_request[channel_q])) begin
                        priority_q <= channel_q + 2'd1;
                        state_q <= RELEASE;
                    end else begin
                        if (next_address[15:8] != address_q[bus_channel][15:8])
                            state_q <= S1;
                        else state_q <= S2;
                    end
                end
                RELEASE: if (!hlda) begin
                    memory_q <= 1'b0;
                    eop_seen_q <= 1'b0;
                    state_q <= IDLE;
                end
                CASCADE: if (hlda && !hardware_request[channel_q]) begin
                    priority_q <= channel_q + 2'd1;
                    state_q <= RELEASE;
                end
                default: state_q <= IDLE;
            endcase
        end
    end

`ifdef FORMAL
    `include "amd_am9517_props.sv"
    `include "amd_am9517_cover_setup.sv"
`endif
endmodule
