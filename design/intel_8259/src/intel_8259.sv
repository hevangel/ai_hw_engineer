`timescale 1ns/1ps

// Intel 8259A Programmable Interrupt Controller: synchronous, synthesizable
// functional reconstruction. See spec/spec.md for the complete behavioral
// contract. The historical part is asynchronous and has no clock or reset pin;
// this core samples all events on `clk` and adds a synchronous `rst_n` that
// forces a defined un-initialized state.
module intel_8259 (
    input  logic       clk,
    input  logic       rst_n,

    // CPU bus
    input  logic       cs_n,
    input  logic       rd_n,
    input  logic       wr_n,
    input  logic       a0,
    input  logic [7:0] data_i,
    output logic [7:0] data_o,
    output logic       data_oe,

    // Interrupt request inputs and CPU handshake
    input  logic [7:0] ir,
    output logic       int_o,
    input  logic       inta_n,

    // Cascade bus (master drives, slave samples)
    input  logic [2:0] cas_i,
    output logic [2:0] cas_o,
    output logic [2:0] cas_oe,

    // Slave-program / buffer-enable shared pin
    input  logic       sp_n_i,
    output logic       en_n_o,
    output logic       en_n_oe
);

    // Initialization state machine
    localparam logic [2:0] StIcw1  = 3'd0;
    localparam logic [2:0] StIcw2  = 3'd1;
    localparam logic [2:0] StIcw3  = 3'd2;
    localparam logic [2:0] StIcw4  = 3'd3;
    localparam logic [2:0] StReady = 3'd4;

    logic [2:0] init_state;
    logic [7:0] icw1;
    logic [7:0] icw2;
    logic [7:0] icw3;
    logic [7:0] icw4;
    logic [7:0] imr;
    logic [7:0] irr;
    logic [7:0] isr;
    logic [2:0] lowest_priority;
    logic       special_mask;
    logic       auto_rotate;
    logic       read_isr_select;
    logic       poll_pending;
    logic [7:0] prev_ir;
    logic       prev_inta_n;
    logic [1:0] ack_phase;
    logic [2:0] ack_level;
    logic       ack_has_req;
    logic       ack_slave;

    // Decoded ICW fields
    logic ic4_needed;
    logic sngl;
    logic adi;
    logic ltim;
    logic upm;
    logic aeoi;
    logic ms_bit;
    logic buf_mode;
    logic sfnm;
    logic initialized;

    assign ic4_needed = icw1[0];
    assign sngl       = icw1[1];
    assign adi        = icw1[2];
    assign ltim       = icw1[3];
    assign upm        = icw4[0];
    assign aeoi       = icw4[1];
    assign ms_bit     = icw4[2];
    assign buf_mode   = icw4[3];
    assign sfnm       = icw4[4];
    assign initialized = (init_state == StReady);

    // Intentionally unused command-word bits: ICW1 identifier bit and ICW4
    // reserved bits are stored with the raw byte but carry no behavior.
    logic _unused_bits;
    assign _unused_bits = &{1'b0, icw1[4], icw4[7:5]};

    // CPU bus decode
    logic bus_read;
    logic bus_write;
    assign bus_read  = !cs_n && !rd_n &&  wr_n;
    assign bus_write = !cs_n &&  rd_n && !wr_n;

    // Acknowledge pulse edges
    logic inta_fall;
    logic inta_rise;
    assign inta_fall =  prev_inta_n && !inta_n;
    assign inta_rise = !prev_inta_n &&  inta_n;

    // Device role
    logic       role_master;
    logic [2:0] own_id;
    assign own_id      = icw3[2:0];
    assign role_master = sngl ? 1'b1 : (buf_mode ? ms_bit : sp_n_i);

    // Priority resolution. The candidate mask is rotated so that the highest
    // priority level (lowest_priority + 1) lands at bit 0, a fixed lowest-index
    // priority encoder picks the winner, and the winning index is the priority
    // rank (0 = highest). The result packs {valid, rank[2:0], level[2:0]}. This
    // rotate/encoder form avoids per-element modular subtraction and is far
    // easier for both AIG and SMT reasoning than a comparison loop.
    function automatic logic [6:0] resolve_req(input logic [7:0] cand,
                                               input logic [2:0] lowp);
        logic [2:0]  shift_amt;
        logic [15:0] doubled;
        logic [7:0]  rotated;
        logic        found;
        logic [2:0]  rank;
        begin
            shift_amt = lowp + 3'd1;
            doubled   = {cand, cand};
            rotated   = doubled[{1'b0, shift_amt} +: 8];
            found = 1'b0;
            rank  = 3'd0;
            for (int j = 0; j < 8; j++) begin
                if (!found && rotated[j]) begin
                    found = 1'b1;
                    rank  = j[2:0];
                end
            end
            resolve_req = {|cand, rank, (rank + shift_amt)};
        end
    endfunction

    // Combinational priority resolution
    logic [7:0] eligible;
    logic [6:0] elig_res;
    logic [6:0] isr_res;
    logic       elig_valid;
    logic [2:0] elig_level;
    logic       isr_valid;
    logic [2:0] isr_level;
    logic [2:0] elig_rank;
    logic [2:0] isr_rank;

    assign eligible   = irr & ~imr;
    assign elig_res   = resolve_req(eligible, lowest_priority);
    assign isr_res    = resolve_req(isr, lowest_priority);
    assign elig_valid = elig_res[6];
    assign elig_rank  = elig_res[5:3];
    assign elig_level = elig_res[2:0];
    assign isr_valid  = isr_res[6];
    assign isr_rank   = isr_res[5:3];
    assign isr_level  = isr_res[2:0];

    // Interrupt request to CPU
    logic int_want;
    always_comb begin
        if (!initialized) begin
            int_want = 1'b0;
        end else if (!elig_valid) begin
            int_want = 1'b0;
        end else if (special_mask) begin
            int_want = 1'b1;
        end else if (!isr_valid) begin
            int_want = 1'b1;
        end else if (sfnm) begin
            int_want = (elig_rank <= isr_rank);
        end else begin
            int_want = (elig_rank < isr_rank);
        end
    end
    assign int_o = int_want;

    // Level selected at acknowledge pulse 1 (spurious -> lowest priority level)
    logic [2:0] sel_level;
    assign sel_level = elig_valid ? elig_level : lowest_priority;

    // Acknowledge engagement: a slave engages only when addressed by cascade
    logic ack_engage;
    assign ack_engage = initialized && (role_master || (cas_i == own_id));

    logic [1:0] max_phase;
    assign max_phase = upm ? 2'd2 : 2'd3;

    // Data-bus ownership during acknowledge
    logic drives_opcode;
    logic owns_addr;
    assign drives_opcode = role_master;
    assign owns_addr     = role_master ? !ack_slave : 1'b1;

    logic [7:0] low_addr;
    logic [7:0] high_addr;
    logic [7:0] vector_byte;
    logic [7:0] poll_word;
    assign low_addr    = adi ? {icw1[7:5], ack_level, 2'b00}
                             : {icw1[7:6], ack_level, 3'b000};
    assign high_addr   = icw2;
    assign vector_byte = {icw2[7:3], ack_level};
    assign poll_word   = {elig_valid, 4'b0000, elig_level};

    // CPU read data and acknowledge vector/opcode output
    always_comb begin
        data_o  = 8'h00;
        data_oe = 1'b0;
        if ((ack_phase != 2'd0) && !inta_n) begin
            if (upm) begin
                if ((ack_phase == 2'd2) && owns_addr) begin
                    data_o  = vector_byte;
                    data_oe = 1'b1;
                end
            end else begin
                if ((ack_phase == 2'd1) && drives_opcode) begin
                    data_o  = 8'hCD;
                    data_oe = 1'b1;
                end else if ((ack_phase == 2'd2) && owns_addr) begin
                    data_o  = low_addr;
                    data_oe = 1'b1;
                end else if ((ack_phase == 2'd3) && owns_addr) begin
                    data_o  = high_addr;
                    data_oe = 1'b1;
                end
            end
        end else if (bus_read) begin
            if (a0) begin
                data_o  = imr;
                data_oe = 1'b1;
            end else if (poll_pending) begin
                data_o  = poll_word;
                data_oe = 1'b1;
            end else begin
                data_o  = read_isr_select ? isr : irr;
                data_oe = 1'b1;
            end
        end
    end

    // Cascade and buffer-enable outputs
    assign cas_oe  = (role_master && ack_slave && (ack_phase != 2'd0))
                     ? 3'b111 : 3'b000;
    assign cas_o   = ack_level;
    assign en_n_oe = initialized && buf_mode;
    assign en_n_o  = ~data_oe;

    // IRR request sensing
    logic [7:0] irr_sensed;
    always_comb begin
        for (int i = 0; i < 8; i++) begin
            if (ltim) begin
                irr_sensed[i] = ir[i];
            end else begin
                irr_sensed[i] = irr[i] | (ir[i] & ~prev_ir[i]);
            end
        end
    end

    // Initialization sequencing helpers
    logic [2:0] after_icw2;
    logic [2:0] after_icw3;
    assign after_icw3 = ic4_needed ? StIcw4 : StReady;
    assign after_icw2 = sngl ? (ic4_needed ? StIcw4 : StReady) : StIcw3;

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            init_state      <= StIcw1;
            icw1            <= 8'h00;
            icw2            <= 8'h00;
            icw3            <= 8'h00;
            icw4            <= 8'h00;
            imr             <= 8'hff;
            irr             <= 8'h00;
            isr             <= 8'h00;
            lowest_priority <= 3'd7;
            special_mask    <= 1'b0;
            auto_rotate     <= 1'b0;
            read_isr_select <= 1'b0;
            poll_pending    <= 1'b0;
            prev_ir         <= ir;
            prev_inta_n     <= inta_n;
            ack_phase       <= 2'd0;
            ack_level       <= 3'd0;
            ack_has_req     <= 1'b0;
            ack_slave       <= 1'b0;
        end else if (bus_write && !a0 && data_i[4]) begin
            // ICW1: (re)start initialization
            icw1            <= data_i;
            if (!data_i[0]) begin
                icw4 <= 8'h00;
            end
            init_state      <= StIcw2;
            imr             <= 8'h00;
            irr             <= 8'h00;
            isr             <= 8'h00;
            lowest_priority <= 3'd7;
            special_mask    <= 1'b0;
            auto_rotate     <= 1'b0;
            read_isr_select <= 1'b0;
            poll_pending    <= 1'b0;
            prev_ir         <= ir;
            prev_inta_n     <= inta_n;
            ack_phase       <= 2'd0;
            ack_level       <= 3'd0;
            ack_has_req     <= 1'b0;
            ack_slave       <= 1'b0;
        end else begin
            prev_ir     <= ir;
            prev_inta_n <= inta_n;
            irr         <= irr_sensed;

            // Acknowledge sequencing
            if (inta_fall && (ack_phase == 2'd0) && ack_engage) begin
                ack_phase   <= 2'd1;
                ack_level   <= sel_level;
                ack_has_req <= elig_valid;
                ack_slave   <= role_master && !sngl && icw3[sel_level];
                if (elig_valid) begin
                    isr[sel_level] <= 1'b1;
                    if (!ltim) begin
                        irr[sel_level] <= 1'b0;
                    end
                end
            end else if (inta_fall && (ack_phase != 2'd0) &&
                         (ack_phase < max_phase)) begin
                ack_phase <= ack_phase + 2'd1;
            end else if (inta_rise && (ack_phase == max_phase)) begin
                ack_phase <= 2'd0;
                if (aeoi && ack_has_req) begin
                    isr[ack_level] <= 1'b0;
                    if (auto_rotate) begin
                        lowest_priority <= ack_level;
                    end
                end
            end

            // CPU command writes
            if (bus_write && a0) begin
                case (init_state)
                    StIcw2: begin
                        icw2       <= data_i;
                        init_state <= after_icw2;
                    end
                    StIcw3: begin
                        icw3       <= data_i;
                        init_state <= after_icw3;
                    end
                    StIcw4: begin
                        icw4       <= data_i;
                        init_state <= StReady;
                    end
                    StReady: begin
                        imr <= data_i;              // OCW1
                    end
                    default: begin
                    end
                endcase
            end else if (bus_write && !a0 && initialized) begin
                if (data_i[4:3] == 2'b00) begin
                    // OCW2: EOI / rotate / set-priority
                    case ({data_i[7], data_i[6], data_i[5]})
                        3'b001: begin
                            if (isr_valid) begin
                                isr[isr_level] <= 1'b0;
                            end
                        end
                        3'b011: begin
                            isr[data_i[2:0]] <= 1'b0;
                        end
                        3'b101: begin
                            if (isr_valid) begin
                                isr[isr_level]  <= 1'b0;
                                lowest_priority <= isr_level;
                            end
                        end
                        3'b111: begin
                            isr[data_i[2:0]] <= 1'b0;
                            lowest_priority  <= data_i[2:0];
                        end
                        3'b100: begin
                            auto_rotate <= 1'b1;
                        end
                        3'b000: begin
                            auto_rotate <= 1'b0;
                        end
                        3'b110: begin
                            lowest_priority <= data_i[2:0];
                        end
                        default: begin
                            // 3'b010: no operation
                        end
                    endcase
                end else if (data_i[4:3] == 2'b01) begin
                    // OCW3: special mask / read select / poll
                    if (data_i[6]) begin
                        special_mask <= data_i[5];
                    end
                    if (data_i[1]) begin
                        read_isr_select <= data_i[0];
                    end
                    if (data_i[2]) begin
                        poll_pending <= 1'b1;
                    end
                end
            end

            // Poll acknowledge on the qualifying CPU read
            if (bus_read && !a0 && poll_pending) begin
                poll_pending <= 1'b0;
                if (elig_valid) begin
                    isr[elig_level] <= 1'b1;
                    if (!ltim) begin
                        irr[elig_level] <= 1'b0;
                    end
                end
            end
        end
    end

`ifdef FORMAL
`ifdef FORMAL_COVER
    intel_8259_cover formal_coverage (
        .clk             (clk),
        .rst_n           (rst_n),
        .cs_n            (cs_n),
        .rd_n            (rd_n),
        .wr_n            (wr_n),
        .a0              (a0),
        .data_i          (data_i),
        .ir              (ir),
        .inta_n          (inta_n),
        .cas_i           (cas_i),
        .sp_n_i          (sp_n_i),
        .initialized     (initialized),
        .isr             (isr),
        .lowest_priority (lowest_priority),
        .special_mask    (special_mask),
        .auto_rotate     (auto_rotate),
        .int_o           (int_o),
        .data_oe         (data_oe),
        .ack_phase       (ack_phase),
        .ack_slave       (ack_slave),
        .role_master     (role_master),
        .upm             (upm),
        .bus_read        (bus_read)
    );
`else
    intel_8259_props formal_properties (
        .clk             (clk),
        .rst_n           (rst_n),
        .cs_n            (cs_n),
        .rd_n            (rd_n),
        .wr_n            (wr_n),
        .a0              (a0),
        .data_i          (data_i),
        .data_o          (data_o),
        .data_oe         (data_oe),
        .ir              (ir),
        .int_o           (int_o),
        .inta_n          (inta_n),
        .cas_i           (cas_i),
        .cas_o           (cas_o),
        .cas_oe          (cas_oe),
        .sp_n_i          (sp_n_i),
        .en_n_o          (en_n_o),
        .en_n_oe         (en_n_oe),
        .init_state      (init_state),
        .icw1            (icw1),
        .icw2            (icw2),
        .icw3            (icw3),
        .icw4            (icw4),
        .imr             (imr),
        .irr             (irr),
        .isr             (isr),
        .lowest_priority (lowest_priority),
        .special_mask    (special_mask),
        .auto_rotate     (auto_rotate),
        .read_isr_select (read_isr_select),
        .poll_pending    (poll_pending),
        .prev_ir         (prev_ir),
        .prev_inta_n     (prev_inta_n),
        .ack_phase       (ack_phase),
        .ack_level       (ack_level),
        .ack_has_req     (ack_has_req),
        .ack_slave       (ack_slave)
    );
`endif
`endif

endmodule
