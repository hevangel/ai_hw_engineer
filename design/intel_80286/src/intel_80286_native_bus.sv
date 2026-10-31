// CPU-pin local-bus cycle controller. Inputs are already scheduled 1/2-byte
// physical beats; the core-side beat scheduler must preserve the completion
// boundary and supply both lanes for an even-address word.
module intel_80286_native_bus (
    input  logic        clk_i,          // one 80286 processor clock
    input  logic        reset_i,        // native RESET polarity: active high
    input  logic        req_i,
    input  logic        fetch_i,
    input  logic        write_i,
    input  logic        io_i,
    input  logic [23:0] address_i,
    input  logic [1:0]  beat_bytes_i,   // 1 byte, or 2 bytes at an even address
    input  logic [15:0] write_data_i,   // lane-aligned D15:D0 data
    output logic        core_ready_o,
    output logic [1:0]  completed_bytes_o,
    output logic [15:0] read_data_o,    // sampled/lane-aligned D15:D0

    input  logic        ready_n_i,      // active low terminates Tc
    input  logic        hold_i,
    input  logic        lock_i,
    input  logic        inta_req_i,
    output logic        inta_ready_o,
    output logic [7:0]  inta_vector_o,
    input  logic        halt_i,
    input  logic        shutdown_i,

    input  logic [15:0] data_i,
    output logic [15:0] data_o,
    output logic        data_oe_o,
    output logic [23:0] address_o,
    output logic        address_oe_o,
    output logic        bhe_n_o,
    output logic        cod_inta_o,
    output logic        m_io_o,
    output logic        s1_o,
    output logic        s0_o,
    output logic        status_oe_o,
    output logic        status_valid_o,
    output logic        lock_n_o,
    output logic        lock_oe_o,
    output logic        hlda_o,
    output logic        cycle_active_o,
    output logic        protocol_error_o
);
    typedef enum logic [1:0] {TI, TS, TC, TH} bus_state_t;
    bus_state_t state;

    logic [23:0] held_address;
    logic [1:0] held_bytes;
    logic [15:0] held_write_data;
    logic [3:0] held_status;
    logic held_write;
    logic held_bhe_n;
    logic held_lock;
    logic held_special;
    logic acknowledge_active;
    logic acknowledge_phase;
    logic acknowledge_wait_drop;
    logic special_reported;

    logic beat_is_valid;

    always_comb begin
        beat_is_valid = (beat_bytes_i == 2'd1) ||
                        (beat_bytes_i == 2'd2 && !address_i[0]);
        protocol_error_o = req_i && !beat_is_valid;

        core_ready_o = (state == TC) && !ready_n_i && !acknowledge_active;
        completed_bytes_o = core_ready_o ? held_bytes : 2'd0;
        read_data_o = 16'd0;
        if (core_ready_o && !held_write) begin
            if (held_bytes == 2'd2)
                read_data_o = data_i;
            else if (held_address[0])
                read_data_o = {data_i[15:8], 8'h00};
            else
                read_data_o = {8'h00, data_i[7:0]};
        end

        address_o = held_address;
        address_oe_o = (state == TS) || (state == TC);
        bhe_n_o = held_bhe_n;
        status_oe_o = state == TS;
        status_valid_o = status_oe_o;
        {cod_inta_o, m_io_o, s1_o, s0_o} = status_oe_o ? held_status : 4'b0000;
        data_o = held_write_data;
        data_oe_o = (state == TC) && held_write;
        lock_oe_o = state != TH;
        lock_n_o = !(lock_i || held_lock || acknowledge_active);
        hlda_o = state == TH;
        cycle_active_o = (state == TS) || (state == TC);
    end

    always_ff @(posedge clk_i) begin
        if (reset_i) begin
            state <= TI;
            held_address <= 24'd0;
            held_bytes <= 2'd0;
            held_write_data <= 16'd0;
            held_status <= 4'd0;
            held_write <= 1'b0;
            held_bhe_n <= 1'b1;
            held_lock <= 1'b0;
            held_special <= 1'b0;
            acknowledge_active <= 1'b0;
            acknowledge_phase <= 1'b0;
            acknowledge_wait_drop <= 1'b0;
            special_reported <= 1'b0;
            inta_ready_o <= 1'b0;
            inta_vector_o <= 8'd0;
        end else begin
            inta_ready_o <= 1'b0;
            if (!inta_req_i)
                acknowledge_wait_drop <= 1'b0;
            if (!halt_i && !shutdown_i)
                special_reported <= 1'b0;

            case (state)
                TI: begin
                    held_special <= 1'b0;
                    if (hold_i && !lock_i) begin
                        state <= TH;
                    end else if (acknowledge_wait_drop) begin
                        state <= TI;
                    end else if (inta_req_i) begin
                        acknowledge_active <= 1'b1;
                        acknowledge_phase <= 1'b0;
                        held_address <= 24'd0;
                        held_bytes <= 2'd1;
                        held_write_data <= 16'd0;
                        held_write <= 1'b0;
                        held_bhe_n <= 1'b1;
                        held_status <= 4'b0000;
                        held_lock <= 1'b1;
                        state <= TS;
                    end else if (req_i && beat_is_valid) begin
                        held_address <= address_i;
                        held_bytes <= beat_bytes_i;
                        held_write_data <= write_data_i;
                        held_write <= write_i;
                        held_bhe_n <= (beat_bytes_i == 2'd2) ? 1'b0 : !address_i[0];
                        held_lock <= lock_i;
                        if (fetch_i)
                            held_status <= 4'b1101; // memory instruction read
                        else if (io_i)
                            held_status <= write_i ? 4'b1010 : 4'b1001;
                        else
                            held_status <= write_i ? 4'b0110 : 4'b0101;
                        state <= TS;
                    end else if ((halt_i || shutdown_i) && !special_reported) begin
                        held_address <= (halt_i && !shutdown_i) ? 24'h000002 : 24'h000000;
                        held_bytes <= 2'd0;
                        held_write_data <= 16'd0;
                        held_write <= 1'b0;
                        held_bhe_n <= 1'b1;
                        held_status <= 4'b0100; // HALT or shutdown; A1 distinguishes
                        held_lock <= 1'b0;
                        held_special <= 1'b1;
                        special_reported <= 1'b1;
                        state <= TS;
                    end
                end

                TS: begin
                    if (held_special)
                        state <= TI;
                    else
                        state <= TC;
                end

                TC: begin
                    if (!ready_n_i) begin
                        if (acknowledge_active && !acknowledge_phase) begin
                            // Keep LOCK# asserted across the two INTA cycles.
                            acknowledge_phase <= 1'b1;
                            state <= TS;
                        end else if (acknowledge_active) begin
                            acknowledge_active <= 1'b0;
                            acknowledge_wait_drop <= 1'b1;
                            inta_vector_o <= data_i[7:0];
                            inta_ready_o <= 1'b1;
                            held_lock <= 1'b0;
                            state <= TI;
                        end else begin
                            held_lock <= 1'b0;
                            state <= TI;
                        end
                    end
                end

                TH: begin
                    if (!hold_i)
                        state <= TI;
                end

                default: state <= TI;
            endcase
        end
    end
endmodule
