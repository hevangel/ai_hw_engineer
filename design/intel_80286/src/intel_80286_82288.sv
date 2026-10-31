// Cycle-level local-bus profile of Intel's M82288 / M82C288 controller.
// clk_i is the external system CLK at twice the 80286 processor-clock rate.
// This MB=0 profile models functional strobes, not electrical timing limits.
module intel_80286_82288 (
    input  logic       clk_i,
    input  logic       reset_i,          // active high
    input  logic       status_valid_i,   // CPU status is in Ts
    input  logic       m_io_i,
    input  logic       s1_i,
    input  logic       s0_i,
    input  logic       cenl_i,           // active high; sampled at Ts start
    input  logic       cen_i,            // active high; asynchronous output gate
    input  logic       cmdly_i,          // active high delays command activation
    input  logic       ready_n_i,        // active low; sampled at each Tc end

    output logic       ale_o,
    output logic       den_o,
    output logic       dt_r_o,
    output logic       mrdc_n_o,
    output logic       mwtc_n_o,
    output logic       iorc_n_o,
    output logic       iowc_n_o,
    output logic       inta_n_o,
    output logic       mce_o
);
    typedef enum logic [2:0] {
        TI,
        TS_FIRST,
        TS_SECOND,
        TC_FIRST,
        TC_SECOND,
        HALT_TS
    } state_t;

    state_t state;
    logic held_memory;
    logic held_selected;
    logic held_read;
    logic held_write;
    logic held_inta;
    logic held_halt;
    logic command_started;

    logic status_is_mem_read;
    logic status_is_mem_write;
    logic status_is_io_read;
    logic status_is_io_write;
    logic status_is_inta;
    logic status_is_halt;
    logic command_active;

    always_comb begin
        status_is_mem_read  = (m_io_i && !s1_i &&  s0_i);
        status_is_mem_write = (m_io_i &&  s1_i && !s0_i);
        status_is_io_read   = (!m_io_i && !s1_i &&  s0_i);
        status_is_io_write  = (!m_io_i &&  s1_i && !s0_i);
        status_is_inta      = (!m_io_i && !s1_i && !s0_i);
        status_is_halt      = ( m_io_i && !s1_i && !s0_i);

        command_active = (state == TC_FIRST || state == TC_SECOND) &&
                         held_selected && command_started && cen_i &&
                         (held_read || held_write || held_inta);

        ale_o = (state == TS_SECOND) && !held_halt;
        mce_o = held_inta && (state == TS_SECOND || state == TC_FIRST);

        // A write may enable the data transceiver in phase two of Ts. CENL
        // is applied at the Ts boundary; if unselected, DT/R is held high.
        dt_r_o = !((state == TS_FIRST || state == TS_SECOND ||
                    state == TC_FIRST || state == TC_SECOND) &&
                   held_selected && held_read);
        den_o = cen_i && (
            ((state == TS_SECOND) && held_write && !held_halt) ||
            command_active
        );

        mrdc_n_o = !(command_active && held_read && !held_inta);
        mwtc_n_o = !(command_active && held_write && held_memory);
        iorc_n_o = !(command_active && held_read && !held_memory && !held_inta);
        iowc_n_o = !(command_active && held_write && !held_memory);
        inta_n_o = !(command_active && held_inta);
    end

    always_ff @(negedge clk_i) begin
        if (reset_i) begin
            state <= TI;
            held_memory <= 1'b0;
            held_selected <= 1'b0;
            held_read <= 1'b0;
            held_write <= 1'b0;
            held_inta <= 1'b0;
            held_halt <= 1'b0;
            command_started <= 1'b0;
        end else begin
            case (state)
                TI: begin
                    command_started <= 1'b0;
                    if (status_valid_i) begin
                        held_memory <= m_io_i;
                        held_selected <= cenl_i;
                        held_read <= status_is_mem_read || status_is_io_read;
                        held_write <= status_is_mem_write || status_is_io_write;
                        held_inta <= status_is_inta;
                        held_halt <= status_is_halt;
                        if (status_is_halt)
                            state <= HALT_TS;
                        else
                            // Status is sampled at the first falling edge of
                            // Ts; ALE occupies the remaining (second) CLK phase.
                            state <= TS_SECOND;
                    end
                end

                TS_FIRST: begin
                    state <= TS_SECOND;
                end

                TS_SECOND: begin
                    command_started <= !cmdly_i;
                    if (held_halt)
                        state <= TI;
                    else
                        state <= TC_FIRST;
                end

                TC_FIRST: begin
                    if (!cmdly_i)
                        command_started <= 1'b1;
                    state <= TC_SECOND;
                end

                TC_SECOND: begin
                    if (!cmdly_i)
                        command_started <= 1'b1;
                    if (!ready_n_i) begin
                        command_started <= 1'b0;
                        if (status_valid_i) begin
                            held_memory <= m_io_i;
                            held_selected <= cenl_i;
                            held_read <= status_is_mem_read || status_is_io_read;
                            held_write <= status_is_mem_write || status_is_io_write;
                            held_inta <= status_is_inta;
                            held_halt <= status_is_halt;
                            if (status_is_halt)
                                state <= HALT_TS;
                            else
                                state <= TS_FIRST;
                        end else begin
                            state <= TI;
                        end
                    end else begin
                        // READY# high repeats the second Tc clock phase and
                        // therefore keeps the selected command asserted.
                        state <= TC_FIRST;
                    end
                end

                HALT_TS: begin
                    command_started <= 1'b0;
                    if (status_valid_i) begin
                        held_memory <= m_io_i;
                        held_selected <= cenl_i;
                        held_read <= status_is_mem_read || status_is_io_read;
                        held_write <= status_is_mem_write || status_is_io_write;
                        held_inta <= status_is_inta;
                        held_halt <= status_is_halt;
                        state <= status_is_halt ? HALT_TS : TS_FIRST;
                    end else begin
                        state <= TI;
                    end
                end

                default: begin
                    state <= TI;
                    command_started <= 1'b0;
                end
            endcase
        end
    end
endmodule
