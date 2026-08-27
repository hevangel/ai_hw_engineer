`timescale 1ns/1ps

// Self-checking testbench for the Intel 8259A reconstruction. A software-style
// reference model is stepped in lockstep with the DUT and the entire output
// interface is compared every sampled cycle. Independent, specification-derived
// black-box checks separately confirm the vector formula, interrupt priority,
// EOI clearing, poll word, and cascade signaling so the design is not accepted
// solely through a structurally similar model.
module tb_intel_8259;

    localparam logic [2:0] StIcw1  = 3'd0;
    localparam logic [2:0] StIcw2  = 3'd1;
    localparam logic [2:0] StIcw3  = 3'd2;
    localparam logic [2:0] StIcw4  = 3'd3;
    localparam logic [2:0] StReady = 3'd4;

    logic       clk;
    logic       rst_n;
    logic       cs_n;
    logic       rd_n;
    logic       wr_n;
    logic       a0;
    logic [7:0] data_i;
    logic [7:0] data_o;
    logic       data_oe;
    logic [7:0] ir;
    logic       int_o;
    logic       inta_n;
    logic [2:0] cas_i;
    logic [2:0] cas_o;
    logic [2:0] cas_oe;
    logic       sp_n_i;
    logic       en_n_o;
    logic       en_n_oe;

    // Reference model state
    logic [2:0] ref_init_state;
    logic [7:0] ref_icw1;
    logic [7:0] ref_icw2;
    logic [7:0] ref_icw3;
    logic [7:0] ref_icw4;
    logic [7:0] ref_imr;
    logic [7:0] ref_irr;
    logic [7:0] ref_isr;
    logic [2:0] ref_lowest;
    logic       ref_smask;
    logic       ref_arot;
    logic       ref_risel;
    logic       ref_poll;
    logic [7:0] ref_prev_ir;
    logic       ref_prev_inta;
    logic [1:0] ref_phase;
    logic [2:0] ref_acklvl;
    logic       ref_ackreq;
    logic       ref_ackslave;

    // Expected outputs
    logic [7:0] ref_data_o;
    logic       ref_data_oe;
    logic       ref_int_o;
    logic [2:0] ref_cas_o;
    logic [2:0] ref_cas_oe;
    logic       ref_en_n_o;
    logic       ref_en_n_oe;

    // Counters
    integer cycle_count;
    integer interface_check_count;
    integer field_check_count;
    integer failure_count;
    integer cpu_read_count;
    integer cpu_write_count;
    integer init_count;
    integer inta_seq_count;
    integer eoi_count;
    integer poll_count;
    integer ocw3_count;
    integer ir_edge_count;

    // Intentionally unused stored command-word bits (ICW1 marker, ICW4 reserved)
    logic _unused_tb;
    assign _unused_tb = &{1'b0, ref_icw1[4], ref_icw4[7:5]};

    intel_8259 dut (
        .clk     (clk),
        .rst_n   (rst_n),
        .cs_n    (cs_n),
        .rd_n    (rd_n),
        .wr_n    (wr_n),
        .a0      (a0),
        .data_i  (data_i),
        .data_o  (data_o),
        .data_oe (data_oe),
        .ir      (ir),
        .int_o   (int_o),
        .inta_n  (inta_n),
        .cas_i   (cas_i),
        .cas_o   (cas_o),
        .cas_oe  (cas_oe),
        .sp_n_i  (sp_n_i),
        .en_n_o  (en_n_o),
        .en_n_oe (en_n_oe)
    );

    always #5 clk = ~clk;

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

    function automatic logic [15:0] next_lfsr(input logic [15:0] cur);
        begin
            next_lfsr = {cur[14:0],
                         cur[15] ^ cur[13] ^ cur[12] ^ cur[10]};
        end
    endfunction

    // Reference next-state computation, mirroring the RTL always_ff exactly.
    task automatic model_step;
        logic       m_initialized;
        logic       m_role_master;
        logic [2:0] m_own_id;
        logic       m_sngl;
        logic       m_ic4;
        logic       m_ltim;
        logic       m_upm;
        logic       m_buf;
        logic       m_ms;
        logic       bus_read_c;
        logic       bus_write_c;
        logic       inta_fall_c;
        logic       inta_rise_c;
        logic [7:0] eligible_c;
        logic [6:0] elig_res_c;
        logic [6:0] isr_res_c;
        logic       _unused_ranks;
        logic       elig_valid_c;
        logic [2:0] elig_level_c;
        logic       isr_valid_c;
        logic [2:0] isr_level_c;
        logic [2:0] sel_level_c;
        logic       ack_engage_c;
        logic [1:0] max_phase_c;
        logic [7:0] irr_sensed_c;
        logic [2:0] after_icw2_c;
        logic [2:0] after_icw3_c;
        begin
            m_sngl        = ref_icw1[1];
            m_ic4         = ref_icw1[0];
            m_ltim        = ref_icw1[3];
            m_upm         = ref_icw4[0];
            m_buf         = ref_icw4[3];
            m_ms          = ref_icw4[2];
            m_own_id      = ref_icw3[2:0];
            m_initialized = (ref_init_state == StReady);
            m_role_master = m_sngl ? 1'b1 : (m_buf ? m_ms : sp_n_i);

            bus_read_c  = !cs_n && !rd_n &&  wr_n;
            bus_write_c = !cs_n &&  rd_n && !wr_n;
            inta_fall_c =  ref_prev_inta && !inta_n;
            inta_rise_c = !ref_prev_inta &&  inta_n;

            eligible_c   = ref_irr & ~ref_imr;
            elig_res_c   = resolve_req(eligible_c, ref_lowest);
            isr_res_c    = resolve_req(ref_isr, ref_lowest);
            elig_valid_c = elig_res_c[6];
            elig_level_c = elig_res_c[2:0];
            isr_valid_c  = isr_res_c[6];
            isr_level_c  = isr_res_c[2:0];
            // The next-state model does not use the priority-rank fields
            _unused_ranks = ^{elig_res_c[5:3], isr_res_c[5:3]};
            sel_level_c  = elig_valid_c ? elig_level_c : ref_lowest;
            ack_engage_c = m_initialized &&
                           (m_role_master || (cas_i == m_own_id));
            max_phase_c  = m_upm ? 2'd2 : 2'd3;
            after_icw3_c = m_ic4 ? StIcw4 : StReady;
            after_icw2_c = m_sngl ? (m_ic4 ? StIcw4 : StReady) : StIcw3;

            for (int i = 0; i < 8; i++) begin
                if (m_ltim) begin
                    irr_sensed_c[i] = ir[i];
                end else begin
                    irr_sensed_c[i] = ref_irr[i] | (ir[i] & ~ref_prev_ir[i]);
                end
            end

            if (!rst_n) begin
                ref_init_state <= StIcw1;
                ref_icw1  <= 8'h00;
                ref_icw2  <= 8'h00;
                ref_icw3  <= 8'h00;
                ref_icw4  <= 8'h00;
                ref_imr   <= 8'hff;
                ref_irr   <= 8'h00;
                ref_isr   <= 8'h00;
                ref_lowest<= 3'd7;
                ref_smask <= 1'b0;
                ref_arot  <= 1'b0;
                ref_risel <= 1'b0;
                ref_poll  <= 1'b0;
                ref_prev_ir   <= ir;
                ref_prev_inta <= inta_n;
                ref_phase   <= 2'd0;
                ref_acklvl  <= 3'd0;
                ref_ackreq  <= 1'b0;
                ref_ackslave<= 1'b0;
            end else if (bus_write_c && !a0 && data_i[4]) begin
                ref_icw1 <= data_i;
                if (!data_i[0]) begin
                    ref_icw4 <= 8'h00;
                end
                ref_init_state <= StIcw2;
                ref_imr   <= 8'h00;
                ref_irr   <= 8'h00;
                ref_isr   <= 8'h00;
                ref_lowest<= 3'd7;
                ref_smask <= 1'b0;
                ref_arot  <= 1'b0;
                ref_risel <= 1'b0;
                ref_poll  <= 1'b0;
                ref_prev_ir   <= ir;
                ref_prev_inta <= inta_n;
                ref_phase   <= 2'd0;
                ref_acklvl  <= 3'd0;
                ref_ackreq  <= 1'b0;
                ref_ackslave<= 1'b0;
            end else begin
                ref_prev_ir   <= ir;
                ref_prev_inta <= inta_n;
                ref_irr       <= irr_sensed_c;

                if (inta_fall_c && (ref_phase == 2'd0) && ack_engage_c) begin
                    ref_phase    <= 2'd1;
                    ref_acklvl   <= sel_level_c;
                    ref_ackreq   <= elig_valid_c;
                    ref_ackslave <= m_role_master && !m_sngl &&
                                    ref_icw3[sel_level_c];
                    if (elig_valid_c) begin
                        ref_isr[sel_level_c] <= 1'b1;
                        if (!m_ltim) begin
                            ref_irr[sel_level_c] <= 1'b0;
                        end
                    end
                end else if (inta_fall_c && (ref_phase != 2'd0) &&
                             (ref_phase < max_phase_c)) begin
                    ref_phase <= ref_phase + 2'd1;
                end else if (inta_rise_c && (ref_phase == max_phase_c)) begin
                    ref_phase <= 2'd0;
                    if (ref_icw4[1] && ref_ackreq) begin
                        ref_isr[ref_acklvl] <= 1'b0;
                        if (ref_arot) begin
                            ref_lowest <= ref_acklvl;
                        end
                    end
                end

                if (bus_write_c && a0) begin
                    case (ref_init_state)
                        StIcw2: begin
                            ref_icw2       <= data_i;
                            ref_init_state <= after_icw2_c;
                        end
                        StIcw3: begin
                            ref_icw3       <= data_i;
                            ref_init_state <= after_icw3_c;
                        end
                        StIcw4: begin
                            ref_icw4       <= data_i;
                            ref_init_state <= StReady;
                        end
                        StReady: begin
                            ref_imr <= data_i;
                        end
                        default: begin
                        end
                    endcase
                end else if (bus_write_c && !a0 && m_initialized) begin
                    if (data_i[4:3] == 2'b00) begin
                        case ({data_i[7], data_i[6], data_i[5]})
                            3'b001: begin
                                if (isr_valid_c) begin
                                    ref_isr[isr_level_c] <= 1'b0;
                                end
                            end
                            3'b011: begin
                                ref_isr[data_i[2:0]] <= 1'b0;
                            end
                            3'b101: begin
                                if (isr_valid_c) begin
                                    ref_isr[isr_level_c] <= 1'b0;
                                    ref_lowest <= isr_level_c;
                                end
                            end
                            3'b111: begin
                                ref_isr[data_i[2:0]] <= 1'b0;
                                ref_lowest <= data_i[2:0];
                            end
                            3'b100: begin
                                ref_arot <= 1'b1;
                            end
                            3'b000: begin
                                ref_arot <= 1'b0;
                            end
                            3'b110: begin
                                ref_lowest <= data_i[2:0];
                            end
                            default: begin
                            end
                        endcase
                    end else if (data_i[4:3] == 2'b01) begin
                        if (data_i[6]) begin
                            ref_smask <= data_i[5];
                        end
                        if (data_i[1]) begin
                            ref_risel <= data_i[0];
                        end
                        if (data_i[2]) begin
                            ref_poll <= 1'b1;
                        end
                    end
                end

                if (bus_read_c && !a0 && ref_poll) begin
                    ref_poll <= 1'b0;
                    if (elig_valid_c) begin
                        ref_isr[elig_level_c] <= 1'b1;
                        if (!m_ltim) begin
                            ref_irr[elig_level_c] <= 1'b0;
                        end
                    end
                end
            end
        end
    endtask

    // Expected combinational outputs, mirroring the RTL always_comb blocks.
    always_comb begin
        logic       e_initialized;
        logic       e_role_master;
        logic       e_sngl;
        logic       e_adi;
        logic       e_upm;
        logic       e_buf;
        logic       e_ms;
        logic       e_sfnm;
        logic [7:0] e_eligible;
        logic [6:0] e_elig_res;
        logic [6:0] e_isr_res;
        logic       e_elig_valid;
        logic [2:0] e_elig_level;
        logic       e_isr_valid;
        logic [2:0] e_elig_rank;
        logic [2:0] e_isr_rank;
        logic       _unused_isr_level;
        logic       bus_read_e;
        logic       drives_opcode_e;
        logic       owns_addr_e;
        logic [7:0] low_addr_e;
        logic [7:0] high_addr_e;
        logic [7:0] vector_e;
        logic [7:0] poll_word_e;

        e_sngl = ref_icw1[1];
        e_adi  = ref_icw1[2];
        e_upm  = ref_icw4[0];
        e_ms   = ref_icw4[2];
        e_buf  = ref_icw4[3];
        e_sfnm = ref_icw4[4];
        e_initialized = (ref_init_state == StReady);
        e_role_master = e_sngl ? 1'b1 : (e_buf ? e_ms : sp_n_i);

        e_eligible   = ref_irr & ~ref_imr;
        e_elig_res   = resolve_req(e_eligible, ref_lowest);
        e_isr_res    = resolve_req(ref_isr, ref_lowest);
        e_elig_valid = e_elig_res[6];
        e_elig_rank  = e_elig_res[5:3];
        e_elig_level = e_elig_res[2:0];
        e_isr_valid  = e_isr_res[6];
        e_isr_rank   = e_isr_res[5:3];
        // The in-service level index is not needed for expected outputs
        _unused_isr_level = ^e_isr_res[2:0];

        if (!e_initialized) begin
            ref_int_o = 1'b0;
        end else if (!e_elig_valid) begin
            ref_int_o = 1'b0;
        end else if (ref_smask) begin
            ref_int_o = 1'b1;
        end else if (!e_isr_valid) begin
            ref_int_o = 1'b1;
        end else if (e_sfnm) begin
            ref_int_o = (e_elig_rank <= e_isr_rank);
        end else begin
            ref_int_o = (e_elig_rank < e_isr_rank);
        end

        drives_opcode_e = e_role_master;
        owns_addr_e     = e_role_master ? !ref_ackslave : 1'b1;
        low_addr_e  = e_adi ? {ref_icw1[7:5], ref_acklvl, 2'b00}
                            : {ref_icw1[7:6], ref_acklvl, 3'b000};
        high_addr_e = ref_icw2;
        vector_e    = {ref_icw2[7:3], ref_acklvl};
        poll_word_e = {e_elig_valid, 4'b0000, e_elig_level};
        bus_read_e  = !cs_n && !rd_n && wr_n;

        ref_data_o  = 8'h00;
        ref_data_oe = 1'b0;
        if ((ref_phase != 2'd0) && !inta_n) begin
            if (e_upm) begin
                if ((ref_phase == 2'd2) && owns_addr_e) begin
                    ref_data_o  = vector_e;
                    ref_data_oe = 1'b1;
                end
            end else begin
                if ((ref_phase == 2'd1) && drives_opcode_e) begin
                    ref_data_o  = 8'hCD;
                    ref_data_oe = 1'b1;
                end else if ((ref_phase == 2'd2) && owns_addr_e) begin
                    ref_data_o  = low_addr_e;
                    ref_data_oe = 1'b1;
                end else if ((ref_phase == 2'd3) && owns_addr_e) begin
                    ref_data_o  = high_addr_e;
                    ref_data_oe = 1'b1;
                end
            end
        end else if (bus_read_e) begin
            if (a0) begin
                ref_data_o  = ref_imr;
                ref_data_oe = 1'b1;
            end else if (ref_poll) begin
                ref_data_o  = poll_word_e;
                ref_data_oe = 1'b1;
            end else begin
                ref_data_o  = ref_risel ? ref_isr : ref_irr;
                ref_data_oe = 1'b1;
            end
        end

        ref_cas_oe = (e_role_master && ref_ackslave && (ref_phase != 2'd0))
                     ? 3'b111 : 3'b000;
        ref_cas_o   = ref_acklvl;
        ref_en_n_oe = e_initialized && e_buf;
        ref_en_n_o  = ~ref_data_oe;
    end

    task automatic record_mismatch(input string      field_name,
                                   input logic [7:0] actual_value,
                                   input logic [7:0] expected_value);
        begin
            field_check_count = field_check_count + 1;
            if (actual_value !== expected_value) begin
                failure_count = failure_count + 1;
                $display("FAIL cycle %0d %s: actual=%02h expected=%02h",
                         cycle_count, field_name, actual_value,
                         expected_value);
            end
        end
    endtask

    task automatic check_outputs;
        begin
            interface_check_count = interface_check_count + 1;
            record_mismatch("data_o", data_o, ref_data_o);
            record_mismatch("data_oe", {7'h00, data_oe}, {7'h00, ref_data_oe});
            record_mismatch("int_o", {7'h00, int_o}, {7'h00, ref_int_o});
            record_mismatch("cas_o", {5'h00, cas_o}, {5'h00, ref_cas_o});
            record_mismatch("cas_oe", {5'h00, cas_oe}, {5'h00, ref_cas_oe});
            record_mismatch("en_n_o", {7'h00, en_n_o}, {7'h00, ref_en_n_o});
            record_mismatch("en_n_oe", {7'h00, en_n_oe}, {7'h00, ref_en_n_oe});
        end
    endtask

    task automatic check_condition(input logic  condition_value,
                                   input string description);
        begin
            field_check_count = field_check_count + 1;
            if (condition_value !== 1'b1) begin
                failure_count = failure_count + 1;
                $display("FAIL cycle %0d: %s", cycle_count, description);
            end
        end
    endtask

    task automatic step_cycle;
        begin
            model_step();
            @(posedge clk);
            #1;
            cycle_count = cycle_count + 1;
            check_outputs();
        end
    endtask

    task automatic set_idle_bus;
        begin
            cs_n = 1'b1;
            rd_n = 1'b1;
            wr_n = 1'b1;
            a0   = 1'b0;
            data_i = 8'h00;
        end
    endtask

    task automatic cpu_write(input logic wa0, input logic [7:0] wdata);
        begin
            @(negedge clk);
            cs_n = 1'b0;
            rd_n = 1'b1;
            wr_n = 1'b0;
            a0   = wa0;
            data_i = wdata;
            cpu_write_count = cpu_write_count + 1;
            step_cycle();
            @(negedge clk);
            set_idle_bus();
            step_cycle();
        end
    endtask

    task automatic cpu_read(input logic ra0, output logic [7:0] rdata);
        begin
            @(negedge clk);
            cs_n = 1'b0;
            rd_n = 1'b0;
            wr_n = 1'b1;
            a0   = ra0;
            data_i = 8'h00;
            cpu_read_count = cpu_read_count + 1;
            // The CPU latches the bus value presented during the active read,
            // before the sampling edge commits any read side effect (such as a
            // poll acknowledge). Capture that combinational value here.
            #1;
            rdata = data_o;
            step_cycle();
            @(negedge clk);
            set_idle_bus();
            step_cycle();
        end
    endtask

    task automatic idle_cycle;
        begin
            @(negedge clk);
            set_idle_bus();
            step_cycle();
        end
    endtask

    task automatic raise_ir(input logic [2:0] level);
        begin
            @(negedge clk);
            ir[level] = 1'b1;
            ir_edge_count = ir_edge_count + 1;
            step_cycle();
        end
    endtask

    task automatic lower_ir(input logic [2:0] level);
        begin
            @(negedge clk);
            ir[level] = 1'b0;
            step_cycle();
        end
    endtask

    task automatic set_ir(input logic [7:0] value);
        begin
            @(negedge clk);
            ir = value;
            step_cycle();
        end
    endtask

    // One INTA pulse: drive inta_n low for two sampled cycles (the DUT presents
    // its bus datum on the second), then release it high. The presented byte is
    // captured for the caller.
    task automatic inta_pulse(output logic [7:0] captured);
        begin
            @(negedge clk);
            inta_n = 1'b0;
            step_cycle();
            @(negedge clk);
            step_cycle();
            captured = data_o;
            @(negedge clk);
            inta_n = 1'b1;
            step_cycle();
        end
    endtask

    task automatic init_8086_single(input logic [7:0] vec_base,
                                     input logic       level_trig);
        logic [7:0] icw1_word;
        begin
            icw1_word = 8'h13;                 // ICW1: single, ICW4, edge
            icw1_word[3] = level_trig;         // LTIM
            cpu_write(1'b0, icw1_word);
            cpu_write(1'b1, vec_base);         // ICW2
            cpu_write(1'b1, 8'h01);            // ICW4: 8086 mode
            init_count = init_count + 1;
        end
    endtask

    initial begin
        integer idx;
        logic [2:0] op;
        logic [2:0] lvl;
        logic [7:0] rdata;
        logic [7:0] b0;
        logic [7:0] b1;
        logic [7:0] b2;
        logic [15:0] lfsr;

        clk = 1'b0;
        rst_n = 1'b0;
        cs_n = 1'b1;
        rd_n = 1'b1;
        wr_n = 1'b1;
        a0 = 1'b0;
        data_i = 8'h00;
        ir = 8'h00;
        inta_n = 1'b1;
        cas_i = 3'd0;
        sp_n_i = 1'b1;

        cycle_count = 0;
        interface_check_count = 0;
        field_check_count = 0;
        failure_count = 0;
        cpu_read_count = 0;
        cpu_write_count = 0;
        init_count = 0;
        inta_seq_count = 0;
        eoi_count = 0;
        poll_count = 0;
        ocw3_count = 0;
        ir_edge_count = 0;

        // Reset
        step_cycle();
        step_cycle();
        check_condition(int_o == 1'b0, "reset must hold INT inactive");
        check_condition(data_oe == 1'b0, "reset must not drive CPU bus");
        check_condition(cas_oe == 3'd0, "reset must release cascade bus");

        @(negedge clk);
        rst_n = 1'b1;
        step_cycle();

        // ---- 8086 single-mode initialization and basic interrupt ----
        $display("--- 8086 single edge-triggered interrupt ---");
        init_8086_single(8'h40, 1'b0);
        check_condition(int_o == 1'b0, "no request means no INT after init");

        raise_ir(3);
        idle_cycle();
        check_condition(int_o == 1'b1, "IR3 rising edge must assert INT");
        inta_seq_count = inta_seq_count + 1;
        inta_pulse(b0);                        // pulse 1: no data in 8086 mode
        inta_pulse(b1);                        // pulse 2: vector
        check_condition(b1 == 8'h43,
                        "8086 vector must be {ICW2[7:3], level}=0x43");
        check_condition(int_o == 1'b0, "INT clears after acknowledge");
        lower_ir(3);

        // ISR bit 3 should be set (read via OCW3)
        cpu_write(1'b0, 8'h0b);                // OCW3 read ISR
        ocw3_count = ocw3_count + 1;
        cpu_read(1'b0, rdata);
        check_condition(rdata == 8'h08, "ISR must show level 3 in service");

        // Non-specific EOI clears the ISR bit
        cpu_write(1'b0, 8'h20);                // OCW2 non-specific EOI
        eoi_count = eoi_count + 1;
        cpu_read(1'b0, rdata);
        check_condition(rdata == 8'h00, "non-specific EOI must clear ISR");

        // ---- Priority nesting ----
        $display("--- fully nested priority ---");
        cpu_write(1'b0, 8'h13);                // re-init
        cpu_write(1'b1, 8'h40);
        cpu_write(1'b1, 8'h01);
        init_count = init_count + 1;
        raise_ir(4);
        idle_cycle();
        inta_seq_count = inta_seq_count + 1;
        inta_pulse(b0);
        inta_pulse(b1);
        check_condition(b1 == 8'h44, "level 4 vector is 0x44");
        // Lower priority IR6 must not interrupt while IR4 in service
        raise_ir(6);
        idle_cycle();
        check_condition(int_o == 1'b0,
                        "lower priority must not preempt in-service level");
        // Higher priority IR1 must interrupt
        raise_ir(1);
        idle_cycle();
        check_condition(int_o == 1'b1,
                        "higher priority must preempt in-service level");
        inta_seq_count = inta_seq_count + 1;
        inta_pulse(b0);
        inta_pulse(b1);
        check_condition(b1 == 8'h41, "preempting level 1 vector is 0x41");
        lower_ir(1);
        lower_ir(4);
        lower_ir(6);
        // Clear ISR with two non-specific EOIs
        cpu_write(1'b0, 8'h20);
        eoi_count = eoi_count + 1;
        cpu_write(1'b0, 8'h20);
        eoi_count = eoi_count + 1;

        // ---- Specific EOI and priority rotation ----
        $display("--- specific EOI and rotation ---");
        cpu_write(1'b0, 8'h13);
        cpu_write(1'b1, 8'h40);
        cpu_write(1'b1, 8'h01);
        init_count = init_count + 1;
        raise_ir(2);
        idle_cycle();
        inta_seq_count = inta_seq_count + 1;
        inta_pulse(b0);
        inta_pulse(b1);
        // Rotate on non-specific EOI: level 2 becomes lowest priority
        cpu_write(1'b0, 8'ha0);                // rotate on non-specific EOI
        eoi_count = eoi_count + 1;
        cpu_read(1'b0, rdata);                 // read IRR default select
        // After rotation, IR3 should be highest. Raise IR3 and IR2.
        lower_ir(2);
        raise_ir(2);
        raise_ir(3);
        idle_cycle();
        check_condition(int_o == 1'b1, "requests after rotation assert INT");
        inta_seq_count = inta_seq_count + 1;
        inta_pulse(b0);
        inta_pulse(b1);
        check_condition(b1 == 8'h43,
                        "after rotate-on-EOI, IR3 outranks IR2");
        lower_ir(2);
        lower_ir(3);
        cpu_write(1'b0, 8'h63);                // specific EOI level 3
        eoi_count = eoi_count + 1;

        // ---- Interrupt masking ----
        $display("--- interrupt masking ---");
        cpu_write(1'b0, 8'h13);
        cpu_write(1'b1, 8'h40);
        cpu_write(1'b1, 8'h01);
        init_count = init_count + 1;
        cpu_write(1'b1, 8'h20);                // OCW1: mask IR5
        raise_ir(5);
        idle_cycle();
        check_condition(int_o == 1'b0, "masked IR5 must not assert INT");
        cpu_write(1'b1, 8'h00);                // unmask all
        idle_cycle();
        check_condition(int_o == 1'b1, "unmasking must reveal pending IR5");
        cpu_read(1'b1, rdata);
        check_condition(rdata == 8'h00, "IMR reads back all-enabled");
        inta_seq_count = inta_seq_count + 1;
        inta_pulse(b0);
        inta_pulse(b1);
        lower_ir(5);
        cpu_write(1'b0, 8'h20);
        eoi_count = eoi_count + 1;

        // ---- Poll mode ----
        $display("--- polled mode ---");
        cpu_write(1'b0, 8'h13);
        cpu_write(1'b1, 8'h40);
        cpu_write(1'b1, 8'h01);
        init_count = init_count + 1;
        raise_ir(6);
        idle_cycle();
        cpu_write(1'b0, 8'h0c);                // OCW3 poll command
        ocw3_count = ocw3_count + 1;
        poll_count = poll_count + 1;
        cpu_read(1'b0, rdata);                 // poll word read
        check_condition(rdata == 8'h86,
                        "poll word must flag pending level 6");
        cpu_write(1'b0, 8'h0b);                // read ISR
        cpu_read(1'b0, rdata);
        check_condition(rdata == 8'h40, "poll read must set ISR level 6");
        lower_ir(6);
        cpu_write(1'b0, 8'h20);
        eoi_count = eoi_count + 1;

        // ---- Level-triggered mode ----
        $display("--- level-triggered mode ---");
        init_8086_single(8'h40, 1'b1);
        set_ir(8'h04);                         // IR2 held high
        idle_cycle();
        check_condition(int_o == 1'b1, "held level asserts INT");
        inta_seq_count = inta_seq_count + 1;
        inta_pulse(b0);
        inta_pulse(b1);
        check_condition(b1 == 8'h42, "level-mode vector level 2 is 0x42");
        cpu_write(1'b0, 8'h20);                // EOI; line still high
        eoi_count = eoi_count + 1;
        idle_cycle();
        check_condition(int_o == 1'b1,
                        "level-mode re-requests while line stays high");
        set_ir(8'h00);
        cpu_write(1'b0, 8'h20);
        eoi_count = eoi_count + 1;

        // ---- Automatic EOI ----
        $display("--- automatic EOI ---");
        cpu_write(1'b0, 8'h13);
        cpu_write(1'b1, 8'h40);
        cpu_write(1'b1, 8'h03);                // ICW4: 8086 + AEOI
        init_count = init_count + 1;
        raise_ir(0);
        idle_cycle();
        inta_seq_count = inta_seq_count + 1;
        inta_pulse(b0);
        inta_pulse(b1);
        idle_cycle();
        cpu_write(1'b0, 8'h0b);                // read ISR
        cpu_read(1'b0, rdata);
        check_condition(rdata == 8'h00,
                        "auto-EOI must self-clear ISR after acknowledge");
        lower_ir(0);

        // ---- Special mask mode ----
        $display("--- special mask mode ---");
        cpu_write(1'b0, 8'h13);
        cpu_write(1'b1, 8'h40);
        cpu_write(1'b1, 8'h01);
        init_count = init_count + 1;
        raise_ir(1);
        idle_cycle();
        inta_seq_count = inta_seq_count + 1;
        inta_pulse(b0);
        inta_pulse(b1);                        // IR1 now in service
        raise_ir(4);
        idle_cycle();
        check_condition(int_o == 1'b0,
                        "nested mode blocks lower priority under service");
        cpu_write(1'b0, 8'h68);                // OCW3 set special mask mode
        ocw3_count = ocw3_count + 1;
        idle_cycle();
        check_condition(int_o == 1'b1,
                        "special mask mode enables lower priority level");
        cpu_write(1'b0, 8'h48);                // OCW3 clear special mask mode
        ocw3_count = ocw3_count + 1;
        idle_cycle();
        check_condition(int_o == 1'b0,
                        "clearing special mask restores nesting");
        lower_ir(1);
        lower_ir(4);
        cpu_write(1'b0, 8'h20);
        eoi_count = eoi_count + 1;

        // ---- 8085 cascade master ----
        $display("--- 8085 cascade master ---");
        sp_n_i = 1'b1;                         // master
        cpu_write(1'b0, 8'h11);                // ICW1 cascade, ICW4, edge, int8
        cpu_write(1'b1, 8'h00);                // ICW2 (A15:A8)
        cpu_write(1'b1, 8'h04);                // ICW3 slave on IR2
        cpu_write(1'b1, 8'h00);                // ICW4 8085 mode
        init_count = init_count + 1;
        // IR5 has no slave: master drives all three bytes itself
        raise_ir(5);
        idle_cycle();
        inta_seq_count = inta_seq_count + 1;
        inta_pulse(b0);                        // CALL opcode
        check_condition(b0 == 8'hcd, "8085 pulse 1 must drive CALL opcode");
        inta_pulse(b1);                        // low address
        check_condition(b1 == {2'b00, 3'd5, 3'b000},
                        "8085 interval-8 low address encodes level 5");
        inta_pulse(b2);                        // high address
        check_condition(b2 == 8'h00, "8085 high address is ICW2");
        check_condition(cas_oe == 3'd0,
                        "no-slave level must not drive cascade bus");
        lower_ir(5);
        cpu_write(1'b0, 8'h20);
        eoi_count = eoi_count + 1;
        // IR2 has a slave: master drives opcode and cascade, releases address
        raise_ir(2);
        idle_cycle();
        inta_seq_count = inta_seq_count + 1;
        @(negedge clk);
        inta_n = 1'b0;
        step_cycle();
        @(negedge clk);
        step_cycle();
        check_condition(cas_oe == 3'b111 && cas_o == 3'd2,
                        "master must drive cascade address for slave line");
        check_condition(data_o == 8'hcd && data_oe == 1'b1,
                        "master still drives CALL opcode on pulse 1");
        @(negedge clk);
        inta_n = 1'b1;
        step_cycle();
        inta_pulse(b1);                        // pulse 2: master releases bus
        check_condition(data_oe == 1'b0,
                        "master releases data bus for slave on pulse 2");
        inta_pulse(b2);                        // pulse 3
        lower_ir(2);
        cpu_write(1'b0, 8'h20);
        eoi_count = eoi_count + 1;

        // ---- Slave mode: engages only when cascade address matches ----
        $display("--- 8086 cascade slave ---");
        sp_n_i = 1'b0;                         // slave
        cpu_write(1'b0, 8'h11);                // ICW1 cascade, ICW4
        cpu_write(1'b1, 8'h70);                // ICW2 vector base
        cpu_write(1'b1, 8'h03);                // ICW3 slave id = 3
        cpu_write(1'b1, 8'h01);                // ICW4 8086 mode
        init_count = init_count + 1;
        raise_ir(4);
        idle_cycle();
        check_condition(int_o == 1'b1, "slave asserts INT to its master");
        // Cascade address not matching this slave: no engagement
        cas_i = 3'd5;
        inta_seq_count = inta_seq_count + 1;
        inta_pulse(b0);
        inta_pulse(b1);
        check_condition(data_oe == 1'b0,
                        "unaddressed slave must not drive the vector");
        cpu_write(1'b0, 8'h0b);                // read ISR
        cpu_read(1'b0, rdata);
        check_condition(rdata == 8'h00,
                        "unaddressed slave must not set ISR");
        // Now the master addresses this slave (id 3)
        cas_i = 3'd3;
        inta_seq_count = inta_seq_count + 1;
        inta_pulse(b0);
        inta_pulse(b1);
        check_condition(b1 == 8'h74,
                        "addressed slave drives its vector 0x74");
        cas_i = 3'd0;
        lower_ir(4);
        cpu_write(1'b0, 8'h20);
        eoi_count = eoi_count + 1;

        // ---- Buffered mode enable pin ----
        $display("--- buffered master mode ---");
        sp_n_i = 1'b1;
        cpu_write(1'b0, 8'h11);
        cpu_write(1'b1, 8'h40);
        cpu_write(1'b1, 8'h01);                // ICW3 (cascade); no slaves set
        cpu_write(1'b1, 8'h0d);                // ICW4: 8086 + buffered + master
        init_count = init_count + 1;
        check_condition(en_n_oe == 1'b1, "buffered mode drives EN_n");
        cpu_read(1'b1, rdata);                 // read IMR: EN_n should assert
        check_condition(en_n_oe == 1'b1, "EN_n stays an output in buffered mode");

        // ---- Reinitialization clears state ----
        $display("--- reinitialization ---");
        raise_ir(7);
        idle_cycle();
        cpu_write(1'b0, 8'h13);                // ICW1 restarts init
        check_condition(int_o == 1'b0,
                        "ICW1 restart holds INT inactive until ready");
        cpu_write(1'b1, 8'h40);
        cpu_write(1'b1, 8'h01);
        init_count = init_count + 1;
        lower_ir(7);
        cpu_read(1'b0, rdata);                 // IRR should be clear
        check_condition(rdata == 8'h00, "reinit clears IRR");

        // ---- Deterministic pseudorandom regression ----
        $display("--- deterministic pseudorandom regression ---");
        $display("Pseudorandom seed: 0x8259, operations: 2048");
        lfsr = 16'h8259;
        // Establish a known initialized configuration
        sp_n_i = 1'b1;
        cpu_write(1'b0, 8'h13);
        cpu_write(1'b1, 8'h40);
        cpu_write(1'b1, 8'h01);
        init_count = init_count + 1;
        for (idx = 0; idx < 2048; idx = idx + 1) begin
            lfsr = next_lfsr(lfsr);
            op = lfsr[2:0];
            lvl = lfsr[10:8];
            case (op)
                3'd0: begin
                    // full re-init with random flavor
                    cpu_write(1'b0, {3'b000, 1'b1, lfsr[3], 1'b0,
                                     lfsr[9], 1'b1});
                    cpu_write(1'b1, lfsr[7:0]);
                    if (!lfsr[9]) begin
                        cpu_write(1'b1, lfsr[15:8]);   // ICW3
                    end
                    cpu_write(1'b1, {3'b000, lfsr[12:11], 1'b0,
                                     lfsr[14], 1'b1});
                    init_count = init_count + 1;
                end
                3'd1: cpu_write(1'b1, lfsr[7:0]);      // OCW1 mask
                3'd2: begin
                    cpu_write(1'b0, {lfsr[7:5], 2'b00, lfsr[2:0]});
                    if (lfsr[6:5] != 2'b00) begin
                        eoi_count = eoi_count + 1;
                    end
                end
                3'd3: begin
                    cpu_write(1'b0, {1'b0, lfsr[6:5], 2'b01,
                                     lfsr[2:0]});       // OCW3
                    ocw3_count = ocw3_count + 1;
                    if (lfsr[2]) begin
                        poll_count = poll_count + 1;
                    end
                end
                3'd4: begin
                    if (lfsr[11]) begin
                        raise_ir(lvl);
                    end else begin
                        lower_ir(lvl);
                    end
                end
                3'd5: cpu_read(lfsr[8], rdata);
                3'd6: begin
                    inta_pulse(b0);
                    if (lfsr[3]) begin
                        inta_pulse(b1);
                    end
                end
                default: idle_cycle();
            endcase
        end

        // ---- Coverage accounting ----
        check_condition(init_count >= 10,
                        "at least 10 initialization sequences required");
        check_condition(inta_seq_count >= 10,
                        "at least 10 acknowledge sequences required");
        check_condition(eoi_count >= 8,
                        "at least 8 EOI commands required");
        check_condition(poll_count >= 1, "at least one poll required");
        check_condition(ocw3_count >= 5, "at least 5 OCW3 writes required");
        check_condition(cpu_read_count >= 20, "at least 20 CPU reads required");
        check_condition(cpu_write_count >= 60,
                        "at least 60 CPU writes required");
        check_condition(ir_edge_count >= 15,
                        "at least 15 IR rising edges required");
        check_condition(interface_check_count >= 500,
                        "at least 500 whole-interface comparisons required");

        $display("8259 simulation result: %0d cycles, %0d interface checks, %0d field checks",
                 cycle_count, interface_check_count, field_check_count);
        $display("CPU reads: %0d, CPU writes: %0d, init sequences: %0d",
                 cpu_read_count, cpu_write_count, init_count);
        $display({"INTA sequences: %0d, EOI commands: %0d, ",
                  "poll reads: %0d, OCW3 writes: %0d"},
                 inta_seq_count, eoi_count, poll_count, ocw3_count);
        $display("IR rising edges: %0d", ir_edge_count);
        $display("Failures: %0d", failure_count);

        if (failure_count == 0) begin
            $display("TEST PASSED");
            $finish;
        end else begin
            $fatal(1, "TEST FAILED with %0d failures", failure_count);
        end
    end

endmodule
